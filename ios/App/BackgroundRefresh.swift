import BackgroundTasks
import Foundation
import RailCore

@MainActor enum BackgroundRefresh {
    static let identifier = "ca.codingpanda.reveilvia.prototype.refresh"

    static func schedule(for session: WakeSession?) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        guard TrackingPolicy.shouldFetch(session) else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch { return }
    }
}
