import Foundation

/// Presentation never turns a stale estimate or a timetable into live tracking.
public enum JourneyDisplay {
    /// Elapsed time from scheduled departure to the device's registered alarm.
    /// This is not a measured train position or distance.
    public static func wakeProgress(departure: Date, alarm: Date, now: Date = .now) -> Double? {
        let duration = alarm.timeIntervalSince(departure)
        guard duration > 0 else { return nil }
        return min(1, max(0, now.timeIntervalSince(departure) / duration))
    }

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
        if !journey.issues.isEmpty { return String(localized: "Desserte à vérifier", bundle: .module) }
        if hasLiveEstimate(journey, now: now) { return String(localized: "Suivi récent", bundle: .module) }
        return journey.liveAvailable ? String(localized: "Suivi à actualiser", bundle: .module) : String(localized: "Horaire prévu", bundle: .module)
    }
}
