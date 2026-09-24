import ActivityKit
import Foundation

struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var station: String
        var arrival: Date
        var alarm: Date
        var estimated: Bool
        var verifiedAt: Date
        var receivedAt: Date?
        var warning: Bool
    }
    var generation: UUID
    var train: String
}
