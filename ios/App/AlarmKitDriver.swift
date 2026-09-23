import AlarmKit
import Foundation
import RailCore
import SwiftUI

private struct StationMetadata: AlarmMetadata {
    var station: String
}

@MainActor final class AlarmKitDriver: AlarmDriver {
    func authorize() async throws {
        let state = try await AlarmManager.shared.requestAuthorization()
        guard state == .authorized else { throw WakeError.denied }
    }

    func alarms() throws -> [DeviceAlarm] {
        if AlarmManager.shared.authorizationState == .denied { throw WakeError.denied }
        return try AlarmManager.shared.alarms.compactMap { alarm in
            guard case let .fixed(date) = alarm.schedule else { return nil }
            return DeviceAlarm(id: alarm.id, date: date, ringing: alarm.state == .alerting)
        }
    }

    func schedule(id: UUID, date: Date, station: String) async throws {
        let presentation = AlarmPresentation(alert: .init(
            title: "Votre gare : \(station)",
            stopButton: AlarmButton(text: "Arrêter", textColor: .white, systemImageName: "stop.fill")
        ))
        let attributes = AlarmAttributes(presentation: presentation,
                                         metadata: StationMetadata(station: station),
                                         tintColor: Color(red: 0.95, green: 0.72, blue: 0.12))
        _ = try await AlarmManager.shared.schedule(id: id, configuration: .alarm(
            schedule: .fixed(date), attributes: attributes
        ))
    }

    func cancel(id: UUID) throws { try AlarmManager.shared.cancel(id: id) }
}

@MainActor final class FileWakeStore: WakePersistence {
    private let url: URL
    init() {
        url = URL.applicationSupportDirectory.appending(path: "wake-session.json")
    }
    func load() throws -> WakeSession? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(WakeSession.self, from: Data(contentsOf: url))
    }
    func save(_ session: WakeSession) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(session).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
