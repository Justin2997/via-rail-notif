# Confidentialité — Réveil VIA

Dernière mise à jour : 8 octobre 2026. / Last updated: October 8, 2026.

Réveil VIA est une application compagnon indépendante pour les voyageurs de VIA Rail Canada, sans affiliation officielle avec VIA Rail.

## Données sur votre appareil

L’application conserve sur votre iPhone le trajet choisi, la gare, l’avance, l’état du réveil, les derniers horaires et les relevés de suivi téléchargés. L’alarme est programmée avec le service AlarmKit d’iOS. Une Activité en direct peut afficher la gare et l’heure du réveil sur l’écran verrouillé.

L’application ne demande aucun compte ni accès à votre position et n’intègre aucun outil publicitaire ou d’analyse d’utilisation. Le développeur n’exploite pas de serveur recevant votre configuration de réveil. Le stockage local peut être soumis aux fonctions de sauvegarde et de protection de votre appareil gérées par Apple.

## Connexions réseau

L’application télécharge les horaires GTFS et le suivi directement auprès des serveurs VIA Rail, en HTTPS. Les serveurs destinataires peuvent recevoir votre adresse IP et les informations habituelles d’une requête réseau. Votre configuration de réveil n’est pas envoyée à VIA Rail ni à un serveur du développeur. Le traitement des connexions par VIA relève de ses propres politiques. Lorsqu’une carte du train est affichée, MapKit charge également les données cartographiques auprès d’Apple; ces connexions relèvent des politiques d’Apple. La carte utilise la position publiée du train, sans demander la position du voyageur.

## Conservation et suppression

La désactivation arrête le réveil mais conserve votre dernière configuration. Les données sont conservées localement pour permettre la reprise et l’utilisation des derniers horaires hors connexion. La suppression de l’application supprime son stockage local. Arrêtez le réveil avant de supprimer l’application. Les sauvegardes du système se gèrent depuis les réglages Apple.

## Assistance

Signalez les problèmes sur [GitHub](https://github.com/Justin2997/via-rail-notif/issues) ou envoyez vos commentaires depuis TestFlight. Les signalements GitHub sont publics : n’y incluez pas de renseignements personnels, de billets ou de détails permettant de vous identifier.

## Bêta TestFlight

Apple traite les informations liées aux installations, aux diagnostics et aux commentaires selon sa [politique TestFlight](https://www.apple.com/legal/privacy/data/en/test-flight/). Lorsque vous envoyez des commentaires ou des diagnostics depuis TestFlight, Apple peut les communiquer au développeur. L’application elle-même n’intègre aucun outil d’analyse.

---

# Privacy — VIA Wake

VIA Wake is an independent companion for VIA Rail Canada passengers. It is not affiliated with VIA Rail.

## Data on your device

The app stores your selected journey, station, alarm lead time, alarm state, downloaded schedules and tracking observations on your iPhone. iOS AlarmKit schedules the alarm. A Live Activity can display your destination and alarm time on the lock screen.

The app requires no account or access to your location and contains no advertising or analytics tools. The developer runs no server that receives your alarm settings. Apple’s device backup and protection features may apply to local storage.

## Network connections

The app downloads schedules and tracking directly from VIA Rail over HTTPS. Those servers may receive your IP address and standard network request information, subject to VIA Rail’s policies. Your alarm settings are not sent to VIA Rail or to a developer server. Displaying a train map also loads map data from Apple through MapKit, subject to Apple’s policies. The map uses the published train position without requesting your location.

## Retention and deletion

Turning off an alarm preserves your last configuration. Data remains on your device to support resuming a journey and browsing cached schedules offline. Deleting the app removes its local storage. Stop your alarm before deleting the app. Manage system backups in Apple’s settings.

## Support and TestFlight

Report issues on [GitHub](https://github.com/Justin2997/via-rail-notif/issues) or send feedback through TestFlight. GitHub reports are public: do not include personal information, tickets or identifying travel details.

Apple processes installation, diagnostic and feedback information under its [TestFlight privacy policy](https://www.apple.com/legal/privacy/data/en/test-flight/). When you submit feedback or diagnostics through TestFlight, Apple may share them with the developer. The app itself contains no analytics tools.
