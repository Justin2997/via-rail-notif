# Identité visuelle du compagnon VIA

Le jaune des actions et des bandeaux est #FFCC00, selon le guide technique VIA Rail Canada (2023). Les surfaces utilisent des neutres chauds, avec un mode sombre anthracite.

Photo intégrée : nouvelle flotte VIA, publiée par VIA Rail Canada. Elle est incluse dans le catalogue d’images pour rester disponible hors connexion.

- Source de la photo : https://corpo.viarail.ca/en/news/2021/new-fleet
- Fichier : https://corpo.viarail.ca/sites/default/files/articles/VIARail-New-Fleet.jpg
- Guide : https://corpo.viarail.ca/sites/default/files/media/brand-book/VIARail_Technical%20Brand%20Guidelines_2023.pdf

Le bandeau identifie le produit comme un compagnon de voyage. Aucun statut d’application officielle ni licence de redistribution n’est revendiqué.

Le formulaire ne contient plus la section « Réveil enregistré ». L’heure, l’état actuel et la désactivation restent sur le dashboard.

Le bandeau photo est réservé à l’accueil sans réveil actif. Il est masqué pendant le suivi d’un réveil et absent du formulaire de configuration.

## Fond canadien

Fond généré avec le skill ImageGen et son outil intégré, puis intégré au catalogue CanadianNature.imageset/canadian-nature.png. Paysage illustratif inspiré des Rocheuses canadiennes, non présenté comme une photographie d’un endroit précis.

Prompt : portrait photoréaliste de nature canadienne, lac calme, montagnes des Rocheuses, conifères, brume à l’aube et reflets doux; centre dégagé pour le texte, sans personne, train, texte ni logo.

Le fond reste visible, y compris avec Réduire la transparence. Un voile gradué protège la lisibilité au centre et laisse le paysage plus visible en haut et en bas. Le dashboard actif réduit les espacements et la carte du trajet; le défilement reste disponible pour les tailles de texte d’accessibilité et les messages exceptionnels.

La barre du trajet représente le temps écoulé entre le départ planifié et l’heure d’alarme réellement enregistrée. Elle ne représente pas une distance ou une position GPS. Elle est masquée si l’alarme est absente, ambiguë, ou antérieure au départ.


## Écran verrouillé — version 1.0 (8)

L’Activité en direct affiche l’heure réellement enregistrée, sa date et son fuseau, ainsi que la gare d’arrivée. Une barre jaune représente le temps écoulé du départ planifié jusqu’au réveil enregistré, comme sur le dashboard. Elle utilise le ProgressView natif à intervalle de dates, sans nécessiter un téléchargement pour avancer. Le départ est un champ optionnel pour préserver la lecture des anciens états; la barre n’est affichée que si le départ précède l’alarme. La Dynamic Island développée affiche également cette barre.

La mention de suivi périmé reste indépendante de la progression temporelle. Depuis la version 1.0 (9), la restriction de sept heures avant l’alarme est retirée. La carte démarre dès l’ouverture avec une alarme future vérifiée, y compris sur un trajet de plusieurs jours. Une activité expirée est remplacée à la réouverture de l’app; la durée active de huit heures imposée par iOS n’est pas contournée. Les autorisations ActivityKit du système restent nécessaires. La sonnerie reste gérée par AlarmKit.

Référence : https://developer.apple.com/documentation/swiftui/progressview/init(timerinterval:countsdown:label:currentvaluelabel:)


Validation 1.0 (9) sur iPhone 16 Pro : build signé, installation et lancement réussis. Le relevé de diagnostic local du 4 octobre à 15 h 11 HAE indique `updated`, autorisations activées et application au premier plan, sur une activité active ou périmée reconnue par ActivityKit. L’affichage visuel sur l’écran verrouillé reste à confirmer par le voyageur. Le diagnostic est conservé uniquement sur l’appareil dans `live-activity-status.json`; il n’est transmis à aucun serveur.
