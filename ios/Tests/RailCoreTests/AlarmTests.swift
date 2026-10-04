import Foundation
import Testing
@testable import RailCore

@MainActor final class MemoryStore: WakePersistence {
    var value: WakeSession?
    func load() throws -> WakeSession? { value }
    func save(_ session: WakeSession) throws { value = session }
}

@MainActor final class FakeDriver: AlarmDriver {
    var values: [DeviceAlarm] = []
    var failSchedule = false
    var throwAfterSchedule = false
    var failCancel = false
    var authorized = true
    var authorizationDelay: Duration?
    func authorize() async throws {
        if let authorizationDelay { try await Task.sleep(for: authorizationDelay) }
        if !authorized { throw WakeError.denied }
    }
    func alarms() throws -> [DeviceAlarm] { values }
    func schedule(id: UUID, date: Date, station: String) async throws {
        if failSchedule { throw WakeError.unverified }
        values.append(DeviceAlarm(id: id, date: date))
        if throwAfterSchedule { throw WakeError.unverified }
    }
    func cancel(id: UUID) throws {
        if failCancel { throw WakeError.unverified }
        values.removeAll { $0.id == id }
    }
}

@Suite @MainActor struct AlarmTests {
    let now = Date(timeIntervalSince1970: 1_900_000_000)

    @Test func trackingStopsForDemoStoppedAndDueAlarms() async throws {
        let controller = AlarmController(driver: FakeDriver(), persistence: MemoryStore())
        var trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        #expect(!TrackingPolicy.shouldFetch(controller.session, now: now))
        trip.id = "via:20:real-fixture"
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        let started = try #require(controller.session)
        #expect(TrackingPolicy.shouldFetch(started, now: now))
        #expect(!TrackingPolicy.shouldFetch(started, now: now.addingTimeInterval(301)))
        controller.stop()
        #expect(!TrackingPolicy.shouldFetch(controller.session, now: now))
        #expect(!TrackingPolicy.mayApplyResponse(started: started, current: controller.session))
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        #expect(!TrackingPolicy.mayApplyResponse(started: started, current: controller.session))
        #expect(!TrackingPolicy.mayApplyResponse(started: nil, current: controller.session))
        #expect(TrackingPolicy.mayApplyResponse(started: controller.session, current: controller.session))
    }

    @Test func dstUsesElapsedMinutes() throws {
        let formatter = ISO8601DateFormatter()
        let arrival = try #require(formatter.date(from: "2026-11-01T01:15:00-05:00"))
        let result = try WakePolicy.desiredDate(arrival: arrival, leadMinutes: 30)
        #expect(formatter.string(from: result) == "2026-11-01T05:45:00Z")
    }

    @Test func positiveLeadRequired() {
        #expect(throws: WakeError.self) {
            try WakePolicy.desiredDate(arrival: now, leadMinutes: 0)
        }
    }

    @Test func movesBothEarlierAndLaterAndKeepsOneAlarm() async throws {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        var trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        #expect(driver.values.count == 1)
        for (index, shift) in [120.0, -60.0].enumerated() {
            trip.observedAt = now.addingTimeInterval(Double(index + 1))
            trip.stops[0].arrival = now.addingTimeInterval(1200 + shift)
            await controller.apply(journey: trip, now: now)
            #expect(driver.values.count == 1)
            #expect(driver.values[0].date == now.addingTimeInterval(300 + shift))
        }
        #expect(controller.session?.pendingID == nil)
    }

    @Test func multidayArrivalSchedulesAndReschedulesAnAbsoluteInstant() async throws {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        var trip = Journey.demo(now: now)
        trip.id = "via:1:long-distance"
        trip.stops[0].timeZone = "America/Vancouver"
        trip.stops[0].plannedArrival = now.addingTimeInterval(4 * 86400)
        trip.stops[0].arrival = trip.stops[0].plannedArrival
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 30, now: now)
        #expect(driver.values.first?.date == now.addingTimeInterval(4 * 86400 - 1800))
        trip.observedAt = now.addingTimeInterval(1)
        trip.stops[0].arrival.addTimeInterval(3600)
        await controller.apply(journey: trip, now: now)
        #expect(driver.values.count == 1)
        #expect(driver.values.first?.date == now.addingTimeInterval(4 * 86400 + 1800))
    }

    @Test func failedReplacementPreservesPreviousAlarm() async throws {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        var trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        let original = driver.values
        driver.failSchedule = true
        trip.observedAt = now.addingTimeInterval(1)
        trip.stops[0].arrival.addTimeInterval(120)
        await controller.apply(journey: trip, now: now)
        #expect(driver.values == original)
        #expect(controller.error != nil)
    }

    @Test func failedChangeOfTrainRestoresTheEntirePreviousSession() async throws {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        let original = Journey.demo(now: now)
        await controller.activate(journey: original, stopID: "2", leadMinutes: 15, now: now)
        let old = try #require(controller.session)
        var replacement = original
        replacement.id = "another-train"
        replacement.stops[0].name = "Ottawa"
        replacement.stops[0].arrival.addTimeInterval(3600)
        driver.failSchedule = true
        await controller.activate(journey: replacement, stopID: "2", leadMinutes: 30, now: now)
        #expect(controller.error != nil)
        #expect(controller.session?.journey == original)
        #expect(controller.session?.leadMinutes == 15)
        #expect(controller.session?.generation == old.generation)
        #expect(controller.session?.pendingID == nil)
        let restored = AlarmController(driver: driver, persistence: store)
        restored.reconcile()
        #expect(restored.session?.journey == original)
        #expect(driver.values.count == 1)
    }

    @Test func driverErrorAfterInstallationStillReconcilesTheActualAlarm() async throws {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        driver.throwAfterSchedule = true
        await controller.activate(journey: Journey.demo(now: now), stopID: "2", leadMinutes: 15, now: now)
        #expect(controller.error == nil)
        #expect(controller.session?.primaryID == driver.values.first?.id)
        #expect(controller.session?.pendingID == nil)
        #expect(driver.values.count == 1)
    }

    @Test func interruptedReplacementNeverSilencesAnAlreadyRingingAlarm() async throws {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        await controller.activate(journey: Journey.demo(now: now), stopID: "2", leadMinutes: 15, now: now)
        var saved = try #require(store.value)
        let pending = UUID()
        saved.pendingID = pending
        saved.alarmIDs.append(pending)
        store.value = saved
        driver.values[0].ringing = true
        driver.values.append(DeviceAlarm(id: pending, date: saved.desiredDate))
        let restored = AlarmController(driver: driver, persistence: store)
        restored.reconcile()
        #expect(driver.values.count == 2)
        #expect(driver.values.contains { $0.ringing })
        #expect(restored.session?.active == false)
        restored.stop()
        #expect(driver.values.isEmpty)
    }

    @Test func interruptedCleanupReconcilesOnRelaunch() async throws {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        var trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        driver.failCancel = true
        trip.observedAt = now.addingTimeInterval(1)
        trip.stops[0].arrival.addTimeInterval(120)
        await controller.apply(journey: trip, now: now)
        #expect(driver.values.count == 2)
        driver.failCancel = false
        let restored = AlarmController(driver: driver, persistence: store)
        restored.reconcile()
        #expect(driver.values.count == 1)
        #expect(restored.session?.pendingID == nil)
        #expect(driver.values[0].date == now.addingTimeInterval(420))
    }

    @Test func stopSurvivesFailedCancellationAndRejectsLateUpdate() async {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        var trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        driver.failCancel = true
        controller.stop()
        #expect(store.value?.active == false)
        driver.failCancel = false
        let restored = AlarmController(driver: driver, persistence: store)
        restored.reconcile()
        trip.observedAt = now.addingTimeInterval(1)
        await restored.apply(journey: trip, now: now)
        #expect(driver.values.isEmpty)
    }

    @Test func ringingNeverRearmsAndReconciliationDoesNotSilenceIt() async {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        var trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        driver.values[0].ringing = true
        controller.reconcile()
        controller.reconcile()
        trip.observedAt = now.addingTimeInterval(1)
        await controller.apply(journey: trip, now: now)
        #expect(driver.values.count == 1)
        #expect(driver.values[0].ringing)
        #expect(controller.session?.active == false)
    }

    @Test func duplicateAlarmsAreNeverLabelledAsOneVerifiedSchedule() async throws {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        await controller.activate(journey: Journey.demo(now: now), stopID: "2", leadMinutes: 15, now: now)
        var saved = try #require(store.value)
        let duplicate = UUID()
        saved.alarmIDs.append(duplicate)
        store.value = saved
        driver.values.append(DeviceAlarm(id: duplicate, date: saved.desiredDate))
        let restored = AlarmController(driver: driver, persistence: store)
        restored.reconcile()
        #expect(restored.observed.count == 2)
        #expect(restored.status != "Programmation vérifiée")
    }

    @Test func absentAlarmDoesNotReappearFromUpdate() async {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        var trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        driver.values = []
        trip.observedAt = now.addingTimeInterval(1)
        await controller.apply(journey: trip, now: now)
        #expect(driver.values.isEmpty)
        #expect(controller.session?.active == false)
    }

    @Test func staleDuplicateWrongTripAndFallbackCannotMoveAlarm() async {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        let trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        let original = driver.values
        var update = trip
        update.stops[0].arrival.addTimeInterval(500)
        await controller.apply(journey: update, now: now)
        update.observedAt = now.addingTimeInterval(-301)
        await controller.apply(journey: update, now: now)
        update.observedAt = now.addingTimeInterval(1)
        update.stops[0].source = "planned"
        await controller.apply(journey: update, now: now)
        update.stops[0].source = "estimated"
        update.id = "another-trip"
        await controller.apply(journey: update, now: now)
        #expect(driver.values == original)
    }

    @Test func deniedAuthorizationAndPastTimeNeverConfirm() async {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        let trip = Journey.demo(now: now)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 30, now: now)
        #expect(driver.values.isEmpty)
        driver.authorized = false
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        #expect(driver.values.isEmpty)
        #expect(controller.session == nil)
    }

    @Test func changedStationAtSameSequenceCannotMoveAlarm() {
        let previous = Journey.demo(now: now)
        var incoming = previous
        incoming.observedAt = now.addingTimeInterval(1)
        incoming.stops[0].code = "MTRL"
        #expect(!WakePolicy.acceptUpdate(previous: previous, incoming: incoming, stopID: "2", now: now))
    }

    @Test func authorizationDelayCannotScheduleAnUnconfirmedPastAlarm() async {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        let actualNow = Date.now
        var trip = Journey.demo(now: actualNow)
        trip.stops[0].arrival = actualNow.addingTimeInterval(60.2)
        driver.authorizationDelay = .milliseconds(400)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 1, now: actualNow)
        #expect(driver.values.isEmpty)
        #expect(controller.session == nil)
        #expect(controller.error == WakeError.immediateConfirmation.errorDescription)
    }

    @Test func staleReceiptCannotArm() async {
        let driver = FakeDriver(), store = MemoryStore()
        let controller = AlarmController(driver: driver, persistence: store)
        var trip = Journey.demo(now: now)
        trip.receivedAt = now.addingTimeInterval(-121)
        await controller.activate(journey: trip, stopID: "2", leadMinutes: 15, now: now)
        #expect(driver.values.isEmpty)
        #expect(controller.error != nil)
    }
}
