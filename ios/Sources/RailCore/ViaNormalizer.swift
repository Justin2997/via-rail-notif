import Foundation

struct LiveEvent: Codable, Equatable, Sendable {
    var scheduled: String?
    var estimated: String?
}

struct LiveStop: Codable, Equatable, Sendable {
    var code: String
    var tz: String?
    var arrival: LiveEvent?
    var departure: LiveEvent?
}

struct LiveTrain: Codable, Sendable {
    var instance: String
    var times: [LiveStop]
    var poll: String?
    var lat: Double?
    var lng: Double?
    var issues: [String] = []

    // Quality flags are computed on device, never accepted from the upstream JSON.
    enum CodingKeys: String, CodingKey { case instance, times, poll, lat, lng }
}

extension GTFSSchedule {
    func journeys(day: String, live: [String: LiveTrain], receivedAt: Date?, now: Date) throws -> [Journey] {
        _ = try ViaTime.day(day)
        let compact = day.replacingOccurrences(of: "-", with: "")
        guard start <= compact && compact <= end else { throw ViaDataError.outsideHorizon }
        let activeTrips = try trips.values.filter { try active($0.required("service_id"), day: day) }
        let numberCounts = Dictionary(grouping: activeTrips, by: { $0["trip_short_name"] ?? "" }).mapValues(\.count)
        var result: [Journey] = []
        for trip in activeTrips {
            // Optional in GTFS: VIA includes an unnumbered Dorval transfer.
            guard let number = trip["trip_short_name"],
                  let numeric = Int(number), (20...99).contains(numeric),
                  let rows = times[try trip.required("trip_id")], rows.count > 1 else { continue }
            guard let route = routes[try trip.required("route_id")],
                  let agency = agencies[try route.required("agency_id")] else {
                throw ViaDataError.invalid("agence ou route GTFS")
            }
            let zone = try agency.required("agency_timezone")
            let stations = rows.map { self.stations[$0["stop_id"]!]! }
            let codes = try stations.map { try $0.required("stop_code") }
            var issues: [String] = []
            if numberCounts[number] != 1 { issues.append("AMBIGUOUS_TRIP") }
            if Set(codes).count != codes.count || codes.contains(where: { codeCounts[$0] != 1 }) {
                issues.append("STOP_CODE_AMBIGUOUS")
            }
            let candidates = live.filter { key, train in
                key.range(of: #"^\d+(?: \(\d{2}-\d{2}\))?$"#, options: .regularExpression) != nil &&
                key.split(separator: " ").first.map(String.init) == number && train.instance == day
            }
            if candidates.count > 1 { issues.append("AMBIGUOUS_LIVE_TRIP") }
            let pair = candidates.count == 1 ? candidates.first : nil
            if let key = pair?.key, key.contains("("), !key.hasSuffix("(\(day.suffix(5)))") {
                issues.append("IDENTITY_UNRESOLVED")
            }
            let train = pair?.value
            issues += train?.issues ?? []
            let liveStops = train?.times ?? []
            if train != nil && liveStops.map(\.code) != codes { issues.append("SERVICE_CONFLICT") }
            let observation = ViaTime.instant(train?.poll)
            let usable = observation.map { (-30...300).contains(now.timeIntervalSince($0)) } == true &&
                receivedAt.map { (-30...120).contains(now.timeIntervalSince($0)) } == true
            var stops: [StationStop] = []
            for (index, row) in rows.enumerated() {
                let station = stations[index]
                let planned = try ViaTime.gtfs(day: day, clock: row.required("arrival_time"), zone: zone)
                let departure = try ViaTime.gtfs(day: day, clock: row.required("departure_time"), zone: zone)
                let current = liveStops.count == rows.count ? liveStops[index] : nil
                let stationZone = station["stop_timezone"].flatMap { $0.isEmpty ? nil : $0 } ?? zone
                let liveZone = current?.tz ?? stationZone
                let estimate = ViaTime.instant(current?.arrival?.estimated, zone: liveZone)
                let departureEstimate = ViaTime.instant(current?.departure?.estimated, zone: liveZone)
                if let current {
                    for (raw, expected) in [(current.arrival?.scheduled, planned), (current.departure?.scheduled, departure)] {
                        if let raw, ViaTime.instant(raw, zone: liveZone) != expected { issues.append("SCHEDULE_CONFLICT") }
                    }
                    if index == 0 && ViaTime.instant(current.departure?.scheduled, zone: liveZone) != departure {
                        issues.append("IDENTITY_UNRESOLVED")
                    }
                    if let estimate, let departureEstimate, departureEstimate < estimate {
                        issues.append("TEMPORAL_CONFLICT")
                    }
                }
                let source = estimate != nil && usable ? "estimated" : "planned"
                stops.append(StationStop(id: try row.required("stop_sequence"), code: codes[index],
                                         name: try station.required("stop_name"), timeZone: stationZone,
                                         plannedArrival: planned, estimatedArrival: estimate,
                                         arrival: source == "estimated" ? estimate! : planned,
                                         source: source, canArm: index > 0, issues: []))
            }
            issues = Set(issues).sorted()
            for index in stops.indices {
                stops[index].issues = issues
                stops[index].canArm = stops[index].canArm && issues.isEmpty
            }
            var position: Position?
            if let lat = train?.lat, let lng = train?.lng, lat.isFinite, lng.isFinite,
               (-90...90).contains(lat), (-180...180).contains(lng) {
                position = Position(latitude: lat, longitude: lng)
            }
            let departure = try ViaTime.gtfs(day: day, clock: rows[0].required("departure_time"), zone: zone)
            let id = ["via", number, day, codes[0], codes[codes.count - 1], ViaTime.iso(departure)].joined(separator: ":")
            result.append(Journey(id: id, number: number, serviceDate: day,
                                  origin: try stations[0].required("stop_name"),
                                  destination: try stations[stations.count - 1].required("stop_name"),
                                  departure: departure, stops: stops, position: position,
                                  positionObservedAt: position == nil ? nil : observation,
                                  observedAt: observation, receivedAt: receivedAt,
                                  issues: issues, liveAvailable: train != nil))
        }
        return result.sorted { (Int($0.number)!, $0.departure, $0.id) < (Int($1.number)!, $1.departure, $1.id) }
    }
}

struct LiveOrdering: Codable, Sendable {
    private var accepted: [String: LiveTrain] = [:]

    mutating func validate(_ incoming: [String: LiveTrain]) -> [String: LiveTrain] {
        var result = incoming
        for (key, var train) in incoming {
            let identity = key + ":" + train.instance
            if let previous = accepted[identity], let old = ViaTime.instant(previous.poll),
               let new = ViaTime.instant(train.poll) {
                if new < old { train.issues.append("OBSERVATION_REGRESSION") }
                else if new == old && train.times != previous.times { train.issues.append("UNORDERED_FORECAST") }
            }
            if train.issues.isEmpty && (ViaTime.instant(train.poll) != nil || accepted[identity] == nil) {
                accepted[identity] = train
            }
            result[key] = train
        }
        let keys = Set(incoming.map { $0.key + ":" + $0.value.instance })
        accepted = accepted.filter { keys.contains($0.key) }
        return result
    }
}
