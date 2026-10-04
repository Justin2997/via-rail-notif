import Foundation
import Testing
@testable import RailCore

@Test func wakeProgressUsesRegisteredAlarmAndClampsToJourneyWindow() {
    let departure = Date(timeIntervalSince1970: 1000)
    let alarm = departure.addingTimeInterval(3600)
    #expect(JourneyDisplay.wakeProgress(departure: departure, alarm: alarm, now: departure.addingTimeInterval(-60)) == 0)
    #expect(JourneyDisplay.wakeProgress(departure: departure, alarm: alarm, now: departure.addingTimeInterval(1800)) == 0.5)
    #expect(JourneyDisplay.wakeProgress(departure: departure, alarm: alarm, now: alarm.addingTimeInterval(60)) == 1)
    #expect(JourneyDisplay.wakeProgress(departure: departure, alarm: alarm.addingTimeInterval(3600), now: departure.addingTimeInterval(1800)) == 0.25)
    #expect(JourneyDisplay.wakeProgress(departure: departure, alarm: departure, now: departure) == nil)
    #expect(JourneyDisplay.wakeProgress(departure: departure, alarm: departure.addingTimeInterval(-60), now: departure) == nil)
}
