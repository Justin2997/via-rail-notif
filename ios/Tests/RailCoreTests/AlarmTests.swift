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
    var failCancel = false
    var authorized = true
    func authorize() async throws { if !authorized { throw WakeError.denied } }
    func alarms() throws -> [DeviceAlarm] { values }
    func schedule(id: UUID, date: Date, station: String) async throws {
        if failSchedule { throw WakeError.unverified }
        values.append(DeviceAlarm(id: id, date: date))
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
