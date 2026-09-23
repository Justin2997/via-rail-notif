@preconcurrency import ActivityKit
import RailCore
import UIKit

@MainActor final class TripActivityController {
    private var updating = false
    private var needsUpdate = false

    // Serialize across async ActivityKit calls. Re-read the controller after each await.
    func sync(_ alarm: AlarmController, warning: Bool) async {
        guard !alarm.isBusy else { return }
        if updating { needsUpdate = true; return }
        updating = true
        defer { updating = false }
        repeat {
            needsUpdate = false
            let session = alarm.session
            let valid = session?.active == true && alarm.observed.count == 1 &&
                alarm.observed.first?.ringing == false && alarm.observed.first!.date > .now
            for activity in Activity<TripActivityAttributes>.activities where
                !valid || activity.attributes.generation != session?.generation {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            guard let current = alarm.session, current.active,
                  current.generation == session?.generation,
                  alarm.observed.count == 1, let registered = alarm.observed.first,
                  !registered.ringing, registered.date > .now,
                  let stop = current.stop, let verified = current.verifiedAt else {
                continue
            }
            let content = ActivityContent(state: TripActivityAttributes.ContentState(
                station: stop.name, arrival: stop.arrival, alarm: registered.date,
                estimated: stop.source == "estimated", verifiedAt: verified,
                receivedAt: current.journey.receivedAt,
                warning: warning || !WakePolicy.hasRecentObservation(current.journey, now: .now)),
                staleDate: min(current.journey.receivedAt?.addingTimeInterval(120) ?? .now, registered.date))
            if let existing = Activity<TripActivityAttributes>.activities.first(where: {
                $0.attributes.generation == current.generation
            }) {
                await existing.update(content)
            } else if registered.date.timeIntervalSinceNow > 7 * 3600 {
                continue
            } else if UIApplication.shared.applicationState == .active {
                guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                    continue
                }
                do {
                    _ = try Activity.request(attributes: TripActivityAttributes(
                        generation: current.generation, train: current.journey.number), content: content)
                } catch { continue }
            }
        } while needsUpdate
    }
}
