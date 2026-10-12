import Foundation
import Testing
@testable import RailCore

struct JourneySelectionTests {
    private func journey() -> Journey {
        var trip = Journey.demo()
        let destination = trip.stops[0]
        var origin = destination
        origin.id = "origin"
        origin.name = "Ottawa"
        var intermediate = destination
        intermediate.id = "intermediate"
        intermediate.name = "Montréal"
        trip.stops = [origin, intermediate, destination]
        return trip
    }

    @Test func reselectingSameServiceKeepsIntermediateStation() {
        let previous = journey()
        var refreshed = previous
        refreshed.stops[1].arrival = refreshed.stops[1].arrival.addingTimeInterval(300)
        #expect(refreshed.selectedStopID(previous: previous, stopID: "intermediate") == "intermediate")
    }

    @Test func differentServiceDefaultsToDestinationEvenWithMatchingStationIDs() {
        let previous = journey()
        var next = previous
        next.id = "next-service"
        #expect(next.selectedStopID(previous: previous, stopID: "intermediate") == next.stops.last?.id)
        #expect(next.selectedStopID(previous: nil, stopID: "intermediate") == next.stops.last?.id)
    }

    @Test func removedStationAndOriginCannotRemainSelected() {
        let previous = journey()
        var next = previous
        next.stops.removeAll { $0.id == "intermediate" }
        #expect(next.selectedStopID(previous: previous, stopID: "intermediate") == next.stops.last?.id)
        #expect(next.selectedStopID(previous: previous, stopID: "origin") == next.stops.last?.id)
        next.stops = []
        #expect(next.selectedStopID(previous: previous, stopID: "intermediate") == "")
    }
}
