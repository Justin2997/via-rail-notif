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


struct AppInformationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Réveil VIA") {
                    Text("Un compagnon de voyage indépendant pour les voyageurs de VIA Rail Canada. Cette application n’est pas une application officielle de VIA Rail.")
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"))")
                }
                Section("Votre réveil") {
                    Text("Le réveil reste programmé sur votre iPhone. Une nouvelle estimation exploitable peut avancer ou retarder son heure lorsque l’app reçoit une mise à jour. En arrière-plan, iOS décide du moment des actualisations; elles ne sont pas continues.")
                    Text("Les dates et heures du trajet utilisent le fuseau de chaque gare. Le réveil utilise le fuseau de votre gare d’arrivée. La barre de progression représente le temps écoulé jusqu’au réveil.")
                }
                Section("Confidentialité") {
                    Text("Le trajet choisi, la gare, l’avance, l’état du réveil et les derniers horaires sont conservés sur votre iPhone. L’app ne demande ni compte ni accès à votre position et n’intègre aucun outil publicitaire ou d’analyse d’utilisation.")
                    Text("L’app télécharge les horaires et le suivi directement auprès de VIA Rail en HTTPS. Comme pour toute connexion Internet, les serveurs destinataires peuvent recevoir votre adresse IP. Votre configuration de réveil n’est pas envoyée à VIA Rail ni à un serveur de l’application.")
                    Text("La désactivation arrête le réveil mais conserve votre dernière configuration. La suppression de l’app supprime son stockage local. Arrêtez votre réveil avant de supprimer l’app.")
                }
                Section("Sources") {
                    Text("Horaires et suivi : VIA Rail Canada inc. Les horaires GTFS sont publiés sous Licence du gouvernement ouvert – Canada. Les images de paysage sont des illustrations générées.")
                    Link("Licence des horaires", destination: URL(string: "https://open.canada.ca/fr/licence-du-gouvernement-ouvert-canada")!)
                }
            }
            .navigationTitle("Informations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }
    }
}
