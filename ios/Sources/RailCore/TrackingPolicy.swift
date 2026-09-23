import Foundation

public enum TrackingPolicy {
    public static func shouldFetch(_ session: WakeSession?, now: Date = .now) -> Bool {
        guard let session else { return false }
        return session.active && !session.stopRequested &&
            session.journey.id != "synthetic-demo" && session.desiredDate > now
    }

    public static func mayApplyResponse(started: WakeSession?, current: WakeSession?) -> Bool {
        started?.generation == current?.generation && started?.active == current?.active
    }
}
