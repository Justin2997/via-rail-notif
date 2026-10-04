@preconcurrency import ActivityKit
import Foundation
import Observation
import RailCore
import UIKit

@MainActor @Observable final class TripActivityController {
    private(set) var message: String?

    private func record(_ status: String, detail: String? = nil) {
        let values = ["status": status, "detail": detail ?? "",
                      "recordedAt": ISO8601DateFormatter().string(from: .now),
                      "enabled": String(ActivityAuthorizationInfo().areActivitiesEnabled),
                      "foreground": String(UIApplication.shared.applicationState == .active)]
        let url = URL.applicationSupportDirectory.appending(path: "live-activity-status.json")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(values) { try? data.write(to: url, options: .atomic) }
    }
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
            message = nil
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
                record("no-eligible-alarm")
                continue
            }
            let content = ActivityContent(state: TripActivityAttributes.ContentState(
                station: stop.name, arrival: stop.arrival, alarm: registered.date,
                estimated: stop.source == "estimated", verifiedAt: verified,
                receivedAt: current.journey.receivedAt,
                timeZone: stop.timeZone,
                departure: current.journey.departure,
                warning: warning || !WakePolicy.hasRecentObservation(current.journey, now: .now)),
                staleDate: min(current.journey.receivedAt?.addingTimeInterval(120) ?? .now, registered.date))
            if let existing = Activity<TripActivityAttributes>.activities.first(where: {
                $0.attributes.generation == current.generation &&
                    ($0.activityState == .active || $0.activityState == .stale)
            }) {
                await existing.update(content)
                record("updated", detail: existing.id)
            } else if UIApplication.shared.applicationState == .active {
                guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                    message = "Activités en direct désactivées : activez-les dans les réglages de Réveil VIA pour afficher le réveil sur l’écran verrouillé."
                    record("disabled")
                    continue
                }
                // An ended activity cannot resume. Start a new one when the
                // traveler reopens the app, including on multi-day journeys.
                for expired in Activity<TripActivityAttributes>.activities where
                    expired.attributes.generation == current.generation && expired.activityState == .ended {
                    await expired.end(nil, dismissalPolicy: .immediate)
                }
                do {
                    let started = try Activity.request(attributes: TripActivityAttributes(
                        generation: current.generation, train: current.journey.number), content: content)
                    record("started", detail: started.id)
                } catch {
                    message = "Affichage sur l’écran verrouillé indisponible. Rouvrez l’app pour réessayer; le réveil reste programmé."
                    record("failed", detail: error.localizedDescription)
                }
            } else {
                record("requires-foreground")
            }
        } while needsUpdate
    }
}
