import MapKit
import RailCore
import SwiftUI

struct TrainMap: View {
    let journey: Journey
    var body: some View {
        Group {
            if let position = journey.position {
                Map {
                    Marker("Dernière position publiée", systemImage: "tram.fill",
                           coordinate: CLLocationCoordinate2D(latitude: position.latitude,
                                                              longitude: position.longitude))
                }
                .safeAreaInset(edge: .bottom) {
                    VStack {
                        Text("Dernière position connue").font(.headline)
                        if let observed = journey.positionObservedAt {
                            Text(observed.formatted(date: .abbreviated, time: .standard))
                        } else { Text("Heure d’observation inconnue") }
                    }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
                }
            } else {
                ContentUnavailableView("Position indisponible", systemImage: "map",
                                       description: Text("Aucune position n’est inventée pour ce trajet."))
            }
        }.navigationTitle("Train \(journey.number)")
    }
}
