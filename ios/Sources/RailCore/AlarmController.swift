import Foundation
import Observation

public struct DeviceAlarm: Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var ringing: Bool
    public init(id: UUID, date: Date, ringing: Bool = false) {
        self.id = id; self.date = date; self.ringing = ringing
    }
}

@MainActor public protocol AlarmDriver {
    func authorize() async throws
    func alarms() throws -> [DeviceAlarm]
    func schedule(id: UUID, date: Date, station: String) async throws
    func cancel(id: UUID) throws
}

public struct WakeSession: Codable, Sendable {
    public var generation: UUID
    public var journey: Journey
    public var stopID: String
    public var leadMinutes: Int
    public var desiredDate: Date
    public var active: Bool
    public var stopRequested = false
    public var alarmIDs: [UUID]
    public var primaryID: UUID?
    public var pendingID: UUID?
    public var verifiedAt: Date?
    public var stop: StationStop? { journey.stops.first { $0.id == stopID } }
}

@MainActor public protocol WakePersistence {
    func load() throws -> WakeSession?
    func save(_ session: WakeSession) throws
}

@MainActor @Observable public final class AlarmController {
    public private(set) var session: WakeSession?
    public private(set) var observed: [DeviceAlarm] = []
    public private(set) var isBusy = false
    public private(set) var status = "Aucun réveil actif"
    public private(set) var error: String?
    private let driver: any AlarmDriver
    private let persistence: any WakePersistence

    public init(driver: any AlarmDriver, persistence: any WakePersistence) {
        self.driver = driver
        self.persistence = persistence
        do { session = try persistence.load() }
        catch { self.error = "Lecture du réveil sauvegardé impossible : \(error.localizedDescription)" }
    }

    private func persist(_ value: WakeSession) throws {
        try persistence.save(value)
        session = value
    }

    public func reconcile() {
        guard !isBusy else { return }
        do { try refresh() }
        catch {
            observed = []
            status = "État actuel inconnu"
            self.error = error.localizedDescription
        }
    }

    private func refresh() throws {
        guard var current = session else { return }
        let all = try driver.alarms()
        observed = all.filter { current.alarmIDs.contains($0.id) }
        if current.stopRequested {
            for alarm in observed { try driver.cancel(id: alarm.id) }
            observed = try driver.alarms().filter { current.alarmIDs.contains($0.id) }
            guard observed.isEmpty else { throw WakeError.unverified }
            current.verifiedAt = .now
            try persist(current)
            status = "Réveil arrêté"
        } else if !current.active {
            status = observed.contains(where: { $0.ringing }) ? "Sonnerie en cours" :
                "Réveil terminé — réactivation nécessaire"
        } else if let pending = current.pendingID,
                  observed.contains(where: { $0.id == pending && !$0.ringing &&
                      abs($0.date.timeIntervalSince(current.desiredDate)) < 1 }) {
            // A crash between scheduling and persistence can be recovered from the OS.
            for alarm in observed where alarm.id != pending { try driver.cancel(id: alarm.id) }
            observed = try driver.alarms().filter { current.alarmIDs.contains($0.id) }
            guard observed.count == 1, observed.first?.id == pending else {
                throw WakeError.unverified
            }
            current.primaryID = pending
            current.pendingID = nil
            current.alarmIDs = [pending]
            current.verifiedAt = .now
            try persist(current)
            status = "Programmation vérifiée"
        } else if observed.contains(where: { $0.ringing }) {
            current.active = false
            try persist(current)
            // Do not stop a ringing alarm merely because it was observed.
            status = "Sonnerie en cours — réactivation ensuite nécessaire"
        } else if observed.isEmpty {
            current.active = false
            try persist(current)
            status = "Alarme absente — réactivation nécessaire"
        } else {
            current.verifiedAt = .now
            try persist(current)
            status = current.pendingID == nil ? "Programmation vérifiée" :
                "Modification non appliquée — ancienne alarme conservée"
        }
    }

    public func activate(journey: Journey, stopID: String, leadMinutes: Int,
                         immediate: Bool = false, now: Date = .now) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        error = nil
        do {
            guard journey.issues.isEmpty,
                  let stop = journey.stops.first(where: { $0.id == stopID }), stop.canArm else {
                throw WakeError.blocked
            }
            if stop.source == "estimated" && !WakePolicy.hasRecentObservation(journey, now: now) {
                throw WakeError.stale
            }
            let desired = try WakePolicy.desiredDate(arrival: stop.arrival, leadMinutes: leadMinutes)
            guard desired > now || immediate else { throw WakeError.immediateConfirmation }
            try await driver.authorize()
            let previousIDs = session?.alarmIDs ?? []
            let current = WakeSession(generation: UUID(), journey: journey, stopID: stopID,
                                      leadMinutes: leadMinutes,
                                      desiredDate: desired > now ? desired : max(now, .now).addingTimeInterval(5),
                                      active: true, alarmIDs: previousIDs)
            try await replace(current)
        } catch {
            self.error = error.localizedDescription
            try? refresh()
        }
    }

    private func replace(_ value: WakeSession) async throws {
        var current = value
        let newID = UUID()
        current.pendingID = newID
        current.alarmIDs.append(newID)
        // Persist intent before OS mutation, and keep the old alarm until the new one is read back.
        try persist(current)
        try await driver.schedule(id: newID, date: current.desiredDate,
                                  station: current.stop?.name ?? "Gare suivie")
        try refresh()
        guard session?.primaryID == newID, session?.pendingID == nil else {
            throw WakeError.unverified
        }
        error = nil
    }

    public func apply(journey: Journey, now: Date = .now) async {
        guard !isBusy, var current = session, current.active else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try refresh()
            guard session?.active == true, observed.count == 1,
                  let existing = observed.first, !existing.ringing, existing.date > now else {
                return // Never recreate a fired, stopped, missing, or already due alarm.
            }
            guard WakePolicy.acceptUpdate(previous: current.journey, incoming: journey,
                                          stopID: current.stopID, now: now),
                  let stop = journey.stops.first(where: { $0.id == current.stopID }) else {
                status = "Mise à jour inexploitable — heure programmée conservée"
                return
            }
            let desired = try WakePolicy.desiredDate(arrival: stop.arrival,
                                                    leadMinutes: current.leadMinutes)
            guard desired > now else {
                status = "Avance devenue impossible — confirmez une sonnerie immédiate"
                return // The feed does not establish that the station is still ahead.
            }
            current = session ?? current
            current.journey = journey
            current.desiredDate = desired
            if abs(existing.date.timeIntervalSince(desired)) < 1 {
                try persist(current)
                return
            }
            try await replace(current)
        } catch {
            self.error = error.localizedDescription
            try? refresh()
        }
    }

    public func stop() {
        guard !isBusy, var current = session else { return }
        do {
            current.active = false
            current.stopRequested = true
            current.generation = UUID()
            try persist(current) // Stops survive a failed cancellation or process interruption.
            try refresh()
            error = nil
        } catch {
            status = "Arrêt non confirmé"
            self.error = error.localizedDescription
        }
    }
}
