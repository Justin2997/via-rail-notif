import AlarmKit
import SwiftUI

@main struct ReveilVIAApp: App {
    @State private var model = JourneyModel()
    @Environment(\.scenePhase) private var scenePhase

    private var refreshIdentity: String {
        "\(scenePhase)-\(model.alarm.session?.generation.uuidString ?? "none")-\(model.alarm.session?.active == true)"
    }

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
                .environment(\.locale, Locale(identifier: "fr_CA"))
                .tint(Color("AccentColor"))
                .task {
                    await model.reconcile()
                    for await _ in AlarmManager.shared.alarmUpdates {
                        guard !Task.isCancelled else { break }
                        await model.reconcile()
                    }
                }
                .task {
                    for await _ in AlarmManager.shared.authorizationUpdates {
                        guard !Task.isCancelled else { break }
                        await model.reconcile()
                    }
                }
                .task(id: refreshIdentity) {
                    guard scenePhase == .active else { return }
                    await model.refreshForeground()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(60)) }
                        catch { return }
                        await model.refreshForeground()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { model.scheduleBackground() }
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await model.runBackgroundRefresh()
        }
    }
}
