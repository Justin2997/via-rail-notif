import Foundation
import Observation
import RailCore

@MainActor @Observable final class JourneyModel {
    var feed: Feed?
    private var trackedFeed: Feed?
    var showAlarmEditor = false
    var selected: Journey?
    var stopID = ""
    var feedDate: String?
    var leadMinutes = 15
    var date = Date.now
    var number = ""
    private let via = ViaClient(cacheURL: URL.applicationSupportDirectory
        .appending(path: "VIA/sources-v1.json"))
    var isLoading = false
    var error: String?
    private let activity = TripActivityController()
    let alarm: AlarmController

    init() {
        alarm = AlarmController(driver: AlarmKitDriver(), persistence: FileWakeStore())
        if let session = alarm.session, session.active, session.journey.id != "synthetic-demo" {
            selected = session.journey
            stopID = session.stopID
            leadMinutes = session.leadMinutes
        }
    }

    var stop: StationStop? { selected?.stops.first { $0.id == stopID } }
    var trackedJourney: Journey? {
        guard let session = alarm.session,
              session.journey.id != "synthetic-demo",
              session.active || !alarm.observed.isEmpty else { return nil }
        return trackedFeed?.journeys.first { $0.id == session.journey.id }
            ?? feed?.journeys.first { $0.id == session.journey.id }
            ?? session.journey
    }
    var desired: Date? {
        guard let stop else { return nil }
        return try? WakePolicy.desiredDate(arrival: stop.arrival, leadMinutes: leadMinutes)
    }

    var serviceDate: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Toronto")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var filtered: [Journey] {
        guard feedDate == serviceDate else { return [] }
        let query = number.trimmingCharacters(in: .whitespacesAndNewlines)
        return (feed?.journeys ?? []).filter {
            query.isEmpty || $0.number.contains(query) ||
                $0.origin.localizedStandardContains(query) || $0.destination.localizedStandardContains(query)
        }.sorted { lhs, rhs in
            let leftFuture = (lhs.stops.last?.arrival ?? .distantPast) > .now
            let rightFuture = (rhs.stops.last?.arrival ?? .distantPast) > .now
            if leftFuture != rightFuture { return leftFuture }
            return lhs.departure < rhs.departure
        }
    }

    func select(_ journey: Journey) {
        selected = journey
        stopID = journey.stops.last?.id ?? ""
    }

    func configure(_ journey: Journey, stopID: String? = nil) {
        select(journey)
        if let stopID { self.stopID = stopID }
        if let session = alarm.session, session.journey.id == journey.id {
            leadMinutes = session.leadMinutes
        }
        showAlarmEditor = true
    }

    func journey(id: String) -> Journey? {
        if let trackedJourney, trackedJourney.id == id { return trackedJourney }
        return feed?.journeys.first { $0.id == id }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            let requestedDate = serviceDate
            let incoming = try await via.load(serviceDate: requestedDate)
            try Task.checkCancellation()
            guard requestedDate == serviceDate else { return }
            feed = incoming
            feedDate = requestedDate
            error = incoming.error
            if var update = incoming.journeys.first(where: { $0.id == selected?.id }) {
                if update.position == nil {
                    update.position = selected?.position
                    update.positionObservedAt = selected?.positionObservedAt
                }
                selected = update
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = "Actualisation impossible : \(error.localizedDescription)"
        }
        guard !Task.isCancelled else { return }
        await updateActiveAlarm()
        await syncActivity()
    }

    private func updateActiveAlarm() async {
        guard let started = alarm.session, TrackingPolicy.shouldFetch(started) else { return }
        do {
            // Browsing another service date must not redirect the active alarm.
            let activeFeed = try await via.load(serviceDate: started.journey.serviceDate)
            try Task.checkCancellation()
            guard TrackingPolicy.mayApplyResponse(started: started, current: alarm.session),
                  let update = activeFeed.journeys.first(where: { $0.id == started.journey.id }) else { return }
            trackedFeed = activeFeed
            if selected?.id == update.id { selected = update }
            await alarm.apply(journey: update)
        } catch is CancellationError { return }
        catch { self.error = "Suivi du réveil indisponible. L’heure enregistrée est conservée." }
    }

    func refreshForeground() async {
        alarm.reconcile()
        await load()
        guard !Task.isCancelled else { return }
        await syncActivity()
    }

    func syncActivity() async {
        await activity.sync(alarm, warning: error != nil || alarm.error != nil)
    }

    func reconcile() async {
        alarm.reconcile()
        await syncActivity()
    }

    func scheduleBackground() {
        BackgroundRefresh.schedule(for: alarm.session)
    }

    func refreshActiveJourney() async {
        alarm.reconcile()
        await updateActiveAlarm()
        guard !Task.isCancelled else { return }
        await syncActivity()
    }

    func runBackgroundRefresh() async {
        // Resubmit first: iOS may expire this execution at any point.
        scheduleBackground()
        guard !Task.isCancelled else { return }
        await refreshActiveJourney()
    }

    func activate(immediate: Bool = false) async {
        guard let selected, selected.id != "synthetic-demo" else { return }
        await alarm.activate(journey: selected, stopID: stopID,
                             leadMinutes: leadMinutes, immediate: immediate)
        scheduleBackground()
        await syncActivity()
    }

    func stopAlarm() async {
        alarm.stop()
        scheduleBackground()
        await syncActivity()
    }

}
