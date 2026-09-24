import Foundation

/// Presentation never turns a stale estimate or a timetable into live tracking.
public enum JourneyDisplay {
    public static func hasLiveEstimate(_ journey: Journey, now: Date = .now) -> Bool {
        journey.liveAvailable && journey.issues.isEmpty &&
            WakePolicy.hasRecentObservation(journey, now: now)
    }

    public static func arrival(_ stop: StationStop, in journey: Journey, now: Date = .now) -> Date {
        if hasLiveEstimate(journey, now: now), stop.source == "estimated", let estimate = stop.estimatedArrival {
            return estimate
        }
        return stop.plannedArrival
    }

    public static func isEstimated(_ stop: StationStop, in journey: Journey, now: Date = .now) -> Bool {
        hasLiveEstimate(journey, now: now) && stop.source == "estimated" && stop.estimatedArrival != nil
    }

    public static func status(_ journey: Journey, now: Date = .now) -> String {
        if !journey.issues.isEmpty { return "Desserte à vérifier" }
        if hasLiveEstimate(journey, now: now) { return "Suivi récent" }
        return journey.liveAvailable ? "Suivi à actualiser" : "Horaire prévu"
    }
}
