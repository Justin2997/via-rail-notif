import Foundation
import Testing
import ZIPFoundation
@testable import RailCore

private enum Fixture {
    static let now = ViaTime.instant("2026-09-22T13:00:00Z")!
    static let day = "2026-09-22"
    static let csv: [String: String] = [
        "feed_info": "feed_start_date,feed_end_date\n20260101,20261231\n",
        "agency": "agency_id,agency_timezone\n1,America/Toronto\n",
        "routes": "route_id,agency_id\nr,1\n",
        "trips": "trip_id,trip_short_name,service_id,route_id\nt,20,s,r\n",
        "stops": "stop_id,stop_code,stop_name\na,MTRL,Montréal\nb,QBEC,Québec\n",
        "stop_times": "trip_id,stop_id,stop_sequence,arrival_time,departure_time\nt,a,1,08:00:00,08:00:00\nt,b,2,11:00:00,11:00:00\n",
        "calendar": "service_id,start_date,end_date,monday,tuesday,wednesday,thursday,friday,saturday,sunday\ns,20260101,20261231,1,1,1,1,1,1,1\n",
        "calendar_dates": "service_id,date,exception_type\n"
    ]
    static var tables: [String: [GTFSSchedule.Row]] { get throws {
        try csv.mapValues { try CSV.rows(Data($0.utf8)) }
    } }
    static let json = Data(#"{"20":{"instance":"2026-09-22","poll":"2026-09-22T13:00:00Z","times":[{"code":"MTRL","tz":"America/Toronto","departure":{"scheduled":"2026-09-22T08:00:00-04:00"}},{"code":"QBEC","tz":"America/Toronto","arrival":{"scheduled":"2026-09-22T11:00:00-04:00","estimated":"2026-09-22T11:15:00-04:00"}}]}}"#.utf8)
    static var live: [String: LiveTrain] { get throws { try JSONDecoder().decode([String: LiveTrain].self, from: json) } }
    static func zip() throws -> Data {
        let archive = try Archive(accessMode: .create)
        for (name, text) in csv {
            let bytes = Data(text.utf8)
            try archive.addEntry(with: name + ".txt", type: .file, uncompressedSize: Int64(bytes.count), compressionMethod: .deflate) { position, size in
                bytes.subdata(in: Int(position)..<(Int(position) + size))
            }
        }
        return try #require(archive.data)
    }
    static func journey(tables: [String: [GTFSSchedule.Row]]? = nil,
                        live: [String: LiveTrain]? = nil, now: Date = now) throws -> Journey {
        let schedule = try GTFSSchedule(tables: tables ?? Self.tables)
        return try #require(schedule.journeys(day: day, live: live ?? Self.live,
                                             receivedAt: Self.now, now: now).first)
    }
}

private actor FakeVIA: ViaTransport {
    var calls: [ViaSource] = []
    var offline = false
    let zip: Data
    var live = Fixture.json
    init() throws { zip = try Fixture.zip() }
    func download(_ source: ViaSource) async throws -> Data {
        calls.append(source)
        if offline { throw URLError(.notConnectedToInternet) }
        return source == .schedule ? zip : live
    }
    func disconnect() { offline = true }
    func corruptLive() { live = Data("invalid json".utf8) }
}

@Suite struct ViaTests {
    @Test func csvHandlesQuotedFieldsBOMAndNewlines() throws {
        let data = Data("\u{FEFF}code,name,comment\r\nA,\"Québec, gare\",\"dit \"\"bonjour\"\"\nencore\"\r\n".utf8)
        let rows = try CSV.rows(data)
        #expect(rows == [["code": "A", "name": "Québec, gare", "comment": "dit \"bonjour\"\nencore"]])
    }

    @Test(arguments: ["a,a\n1,2", "a,b\n1", "a\n\"unterminated", "a\n\"closed\"oops"])
    func rejectsMalformedCSV(_ raw: String) {
        #expect(throws: (any Error).self) { try CSV.rows(Data(raw.utf8)) }
    }

    @Test func compressedZIPIsParsedEntirelyInSwift() throws {
        let schedule = try GTFSSchedule(zip: Fixture.zip())
        let trip = try #require(schedule.journeys(day: Fixture.day, live: Fixture.live,
                                                 receivedAt: Fixture.now, now: Fixture.now).first)
        #expect(trip.stops.last?.arrival == ViaTime.instant("2026-09-22T15:15:00Z"))
        #expect(trip.stops.last?.plannedArrival == ViaTime.instant("2026-09-22T15:00:00Z"))
        #expect(trip.stops.last?.canArm == true)
        #expect(trip.stops.first?.canArm == false)
    }

    @Test func malformedZIPFails() {
        #expect(throws: (any Error).self) { try GTFSSchedule(zip: Data("invalid zip".utf8)) }
    }

    @Test func gtfsNoonAnchorHandlesDSTAndOvernight() throws {
        #expect(try ViaTime.iso(ViaTime.gtfs(day: "2026-11-01", clock: "01:15:00", zone: "America/Toronto")) == "2026-11-01T06:15:00Z")
        #expect(try ViaTime.iso(ViaTime.gtfs(day: "2026-03-08", clock: "25:10:00", zone: "America/Toronto")) == "2026-03-09T05:10:00Z")
    }

    @Test(arguments: ["&mdash;", "2026-11-01T01:15:00", "bad", "2026-09-22T11:00:00-05:00"])
    func neverGuessesTimestamp(_ value: String) {
        #expect(ViaTime.instant(value, zone: "America/Toronto") == nil)
    }

    @Test func blocksServiceScheduleAndIdentityConflicts() throws {
        var live = try Fixture.live
        live["20"]!.times.append(LiveStop(code: "COTO"))
        let conflicting = try Fixture.journey(live: live)
        #expect(conflicting.issues.contains("SERVICE_CONFLICT"))
        #expect(conflicting.stops.allSatisfy { !$0.canArm })
        live = try Fixture.live
        live["20"]!.times[1].arrival?.scheduled = "2026-09-22T11:01:00-04:00"
        #expect(try Fixture.journey(live: live).issues.contains("SCHEDULE_CONFLICT"))
        live = try Fixture.live
        live["20"]!.instance = "2026-09-21"
        #expect(try !Fixture.journey(live: live).liveAvailable)
    }

    @Test func duplicateIDsAndAmbiguousTripsAreNotArbitrated() throws {
        var tables = try Fixture.tables
        tables["stops"]!.append(tables["stops"]![0])
        #expect(throws: (any Error).self) { try GTFSSchedule(tables: tables) }
        tables = try Fixture.tables
        var other = tables["trips"]![0]; other["trip_id"] = "other"
        tables["trips"]!.append(other)
        #expect(try Fixture.journey(tables: tables).issues.contains("AMBIGUOUS_TRIP"))
    }

    @Test func calendarsExceptionsAndFeedHorizon() throws {
        var tables = try Fixture.tables
        tables["calendar_dates"] = [["service_id": "s", "date": "20260922", "exception_type": "2"]]
        let schedule = try GTFSSchedule(tables: tables)
        #expect(try schedule.journeys(day: Fixture.day, live: [:], receivedAt: nil, now: Fixture.now).isEmpty)
        #expect(throws: (any Error).self) {
            try schedule.journeys(day: "2027-01-01", live: [:], receivedAt: nil, now: Fixture.now)
        }
    }

    @Test func unnumberedTransfersDoNotPreventLoadingNumberedTrains() throws {
        var tables = try Fixture.tables
        tables["trips"]!.append(["trip_id": "transfer", "service_id": "s",
                                  "route_id": "r", "trip_short_name": ""])
        #expect(try Fixture.journey(tables: tables).number == "20")
    }

    @Test func missingAndStaleObservationUseLabelledSchedule() throws {
        var live = try Fixture.live; live["20"]!.poll = nil
        #expect(try Fixture.journey(live: live).stops.last?.source == "planned")
        #expect(try Fixture.journey(now: Fixture.now.addingTimeInterval(301)).stops.last?.source == "planned")
    }

    @Test func observationsCannotRegressOrChangeETAAtSamePoll() throws {
        var order = LiveOrdering(), live = try Fixture.live
        _ = order.validate(live)
        for shift in [-60.0, -30.0] {
            live["20"]!.poll = ViaTime.iso(Fixture.now.addingTimeInterval(shift))
            #expect(order.validate(live)["20"]!.issues.contains("OBSERVATION_REGRESSION"))
        }
        live = try Fixture.live
        live["20"]!.times[1].arrival?.estimated = "2026-09-22T11:20:00-04:00"
        for _ in 0..<2 { #expect(order.validate(live)["20"]!.issues.contains("UNORDERED_FORECAST")) }
        live["20"]!.poll = ViaTime.iso(Fixture.now.addingTimeInterval(1))
        #expect(order.validate(live)["20"]!.issues.isEmpty)
    }

    @Test func directClientSharesTransfersAndThrottlesRepeatedLoads() async throws {
        let transport = try FakeVIA()
        let client = ViaClient(transport: transport, clock: { Fixture.now })
        async let first = client.load(serviceDate: Fixture.day)
        async let second = client.load(serviceDate: Fixture.day)
        let feeds = try await [first, second]
        #expect(feeds.allSatisfy { $0.journeys.count == 1 })
        _ = try await client.load(serviceDate: Fixture.day)
        #expect(await transport.calls == [.schedule, .live])
    }

    @Test func persistentCacheWorksOfflineAfterRestartAndKeepsOriginalReceipt() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appending(path: "cache.json")
        let transport = try FakeVIA()
        let online = ViaClient(transport: transport, cacheURL: path, clock: { Fixture.now })
        let first = try await online.load(serviceDate: Fixture.day)
        await transport.disconnect()
        let offline = ViaClient(transport: transport, cacheURL: path,
                                clock: { Fixture.now.addingTimeInterval(21700) })
        let second = try await offline.load(serviceDate: Fixture.day)
        #expect(second.journeys.first?.id == first.journeys.first?.id)
        #expect(second.receivedAt == first.receivedAt)
        #expect(second.journeys.first?.stops.last?.source == "planned")
        #expect(second.error?.contains("sauvegardés") == true)
        await #expect(throws: (any Error).self) { try await offline.load(serviceDate: "2027-01-01") }
    }

    @Test func malformedLiveStillAllowsGTFSAndColdOfflineReportsFailure() async throws {
        let transport = try FakeVIA()
        await transport.corruptLive()
        let client = ViaClient(transport: transport, clock: { Fixture.now })
        let feed = try await client.load(serviceDate: Fixture.day)
        #expect(feed.receivedAt == nil)
        #expect(feed.journeys.first?.stops.last?.source == "planned")
        #expect(feed.error != nil)
        await transport.disconnect()
        let cold = ViaClient(transport: transport)
        await #expect(throws: (any Error).self) { try await cold.load(serviceDate: Fixture.day) }
    }

    @Test func dashboardNeverLabelsTimetablesOrStaleEstimatesAsLive() throws {
        var trip = try Fixture.journey()
        let stop = try #require(trip.stops.last)
        #expect(JourneyDisplay.hasLiveEstimate(trip, now: Fixture.now))
        #expect(JourneyDisplay.arrival(stop, in: trip, now: Fixture.now) == stop.estimatedArrival)
        let stale = Fixture.now.addingTimeInterval(121)
        #expect(!JourneyDisplay.isEstimated(stop, in: trip, now: stale))
        #expect(JourneyDisplay.arrival(stop, in: trip, now: stale) == stop.plannedArrival)
        #expect(JourneyDisplay.status(trip, now: stale) == "Suivi à actualiser")
        trip.issues = ["SERVICE_CONFLICT"]
        #expect(!JourneyDisplay.hasLiveEstimate(trip, now: Fixture.now))
        #expect(JourneyDisplay.arrival(stop, in: trip, now: Fixture.now) == stop.plannedArrival)
        #expect(JourneyDisplay.status(trip, now: Fixture.now) == "Desserte à vérifier")
        trip.issues = []; trip.liveAvailable = false
        #expect(JourneyDisplay.status(trip, now: Fixture.now) == "Horaire prévu")
    }

    @Test func browsingAnotherDateKeepsActiveJourneyAvailableWithoutExtraTransfers() async throws {
        let transport = try FakeVIA()
        let client = ViaClient(transport: transport, clock: { Fixture.now })
        let active = try await client.load(serviceDate: Fixture.day)
        let tomorrow = try await client.load(serviceDate: "2026-09-23")
        let refreshedActive = try await client.load(serviceDate: Fixture.day)
        #expect(tomorrow.journeys.first?.serviceDate == "2026-09-23")
        #expect(tomorrow.journeys.first?.liveAvailable == false)
        #expect(refreshedActive.journeys.first?.id == active.journeys.first?.id)
        #expect(refreshedActive.journeys.first?.liveAvailable == true)
        #expect(await transport.calls == [.schedule, .live])
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["VIA_LIVE_SMOKE"] == "1"))
    func officialSourcesWithoutAnyBackend() async throws {
        let client = ViaClient()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/Toronto")
        formatter.dateFormat = "yyyy-MM-dd"
        let feed = try await client.load(serviceDate: formatter.string(from: .now))
        #expect(!feed.journeys.isEmpty)
        #expect(feed.error == nil)
        #expect(feed.receivedAt != nil)
        print("Direct VIA smoke: \(feed.journeys.count) journeys; \(feed.journeys.filter { !$0.issues.isEmpty }.count) blocked; no backend.")
    }
}
