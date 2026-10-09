import MapKit
import RailCore
import SwiftUI

struct TrainMap: View {
    let journey: Journey
    var body: some View {
        Group {
            if let position = journey.position {
                Map {
                    Marker(String(localized: "Dernière position publiée"), systemImage: "tram.fill",
                           coordinate: CLLocationCoordinate2D(latitude: position.latitude,
                                                              longitude: position.longitude))
                }
                .safeAreaInset(edge: .bottom) {
                    VStack {
                        Text(String(localized: "Dernière position connue")).font(.headline)
                        if let observed = journey.positionObservedAt {
                            Text(observed.formatted(date: .abbreviated, time: .standard))
                        } else { Text(String(localized: "Heure d’observation inconnue")) }
                    }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
                }
            } else {
                ContentUnavailableView(String(localized: "Position indisponible"), systemImage: "map",
                                       description: Text(String(localized: "Aucune position n’est inventée pour ce trajet.")))
            }
        }.navigationTitle(String(localized: "Train \(String(journey.number))"))
    }
}


struct AppInformationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "Réveil VIA")) {
                    Text(String(localized: "Un compagnon de voyage indépendant pour les voyageurs de VIA Rail Canada. Cette application n’est pas une application officielle de VIA Rail."))
                    Text(String(localized: "Version \(String(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")) (\(String(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")))"))
                }
                Section(String(localized: "Votre réveil")) {
                    Text(String(localized: "Le réveil reste programmé sur votre iPhone. Une nouvelle estimation exploitable peut avancer ou retarder son heure lorsque l’app reçoit une mise à jour. En arrière-plan, iOS décide du moment des actualisations; elles ne sont pas continues."))
                    Text(String(localized: "Les dates et heures du trajet utilisent le fuseau de chaque gare. Le réveil utilise le fuseau de votre gare d’arrivée. La barre de progression représente le temps écoulé jusqu’au réveil."))
                }
                Section(String(localized: "Confidentialité")) {
                    Text(String(localized: "Le trajet choisi, la gare, l’avance, l’état du réveil et les derniers horaires sont conservés sur votre iPhone. L’app ne demande ni compte ni accès à votre position et n’intègre aucun outil publicitaire ou d’analyse d’utilisation."))
                    Text(String(localized: "L’app télécharge les horaires et le suivi directement auprès de VIA Rail en HTTPS. Comme pour toute connexion Internet, les serveurs destinataires peuvent recevoir votre adresse IP. Votre configuration de réveil n’est pas envoyée à VIA Rail ni à un serveur de l’application."))
                    Text(String(localized: "La désactivation arrête le réveil mais conserve votre dernière configuration. La suppression de l’app supprime son stockage local. Arrêtez votre réveil avant de supprimer l’app."))
                    Link(String(localized: "Politique de confidentialité"), destination: URL(string: "https://github.com/Justin2997/via-rail-notif/blob/main/docs/PRIVACY.md")!)
                }
                Section(String(localized: "Sources")) {
                    Text(String(localized: "Horaires et suivi : VIA Rail Canada inc. Les horaires GTFS sont publiés sous Licence du gouvernement ouvert – Canada. Les images de paysage sont des illustrations générées."))
                    Link(String(localized: "Licence des horaires"), destination: URL(string: String(localized: "https://open.canada.ca/fr/licence-du-gouvernement-ouvert-canada"))!)
                }
                Section(String(localized: "Assistance")) {
                    Link(String(localized: "Signaler un problème"), destination: URL(string: "https://github.com/Justin2997/via-rail-notif/issues")!)
                    Text(String(localized: "N’incluez pas de renseignements personnels dans les signalements publics. Vous pouvez aussi envoyer vos commentaires depuis TestFlight."))
                }
            }
            .navigationTitle(String(localized: "Informations"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Fermer")) { dismiss() } } }
        }
    }
}
