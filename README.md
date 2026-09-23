# Réveil VIA — prototype personnel

Première tranche exécutable : app SwiftUI iOS 26, alarme locale AlarmKit, choix du train/de la gare/de l’avance, connexion directe aux sources VIA et rapprochement des horaires GTFS avec le suivi VIA sur l’iPhone. « Temps réel » est l’unique écran principal. La configuration du réveil s’ouvre dans une fenêtre depuis le dashboard. Les données VIA réelles sont chargées dès l’ouverture; aucun trajet de démonstration n’est proposé.

L’app ajuste une alarme vers une heure antérieure ou postérieure lorsqu’une nouvelle estimation exploitable est chargée dans l’app. **Le dashboard est actualisé environ chaque minute lorsque l’app est au premier plan, même sans réveil actif. En veille, les actualisations sont opportunistes et décidées par iOS.** Une Activité en direct affiche le réveil enregistré et signale le suivi périmé. Aucune sonnerie sur iPhone physique ni précision de trente secondes n’est démontrée. L’objectif produit adaptatif reste inchangé; ce prototype sert à établir la première preuve locale.

## Application autonome

Aucun serveur à installer, compte à créer ou clé API à fournir. L’iPhone télécharge directement les horaires GTFS et le suivi JSON publiés par VIA, en HTTPS. La décompression ZIP, la lecture CSV, les contrôles de cohérence, le calcul du réveil et la gestion AlarmKit sont exécutés dans l’app.

Les horaires et le dernier suivi sont sauvegardés localement. Le GTFS est actualisé après six heures; les lectures répétées sont espacées d’au moins une minute lorsque les horaires sont déjà disponibles pour la date demandée. Les chargements simultanés partagent les transferts. Aucun collecteur distant ni ressource cloud. Au premier plan, les lectures alimentent la date consultée et le réveil actif. En arrière-plan, elles concernent uniquement un réveil réel actif et s’arrêtent quand celui-ci est arrêté ou échu. Consulter une autre date ne redirige pas le suivi de l’alarme.

Internet est nécessaire au premier chargement réel et aux nouvelles estimations. Hors connexion, l’app utilise les données déjà sauvegardées avec leur date d’origine et conserve l’alarme programmée. L’autonomie vis-à-vis d’un serveur propre au projet ne garantit pas des mises à jour permanentes en arrière-plan sur iOS.

## Ouvrir l’app

Ouvrir `ios/ReveilVIA.xcodeproj` dans Xcode 26.1 ou ultérieur, choisir le scheme `ReveilVIA` et un iPhone iOS 26. Le projet généré est inclus; [XcodeGen](https://github.com/yonaskolb/XcodeGen) n’est nécessaire que pour modifier sa structure :

```sh
xcodegen generate --spec ios/project.yml
```

1. « Temps réel » affiche uniquement le train associé au réveil actif (un seul réveil à la fois dans ce prototype), avec sa gare cible et la date de réception. Sans réveil, un bouton invite à en configurer un. Le train disparaît après l’arrêt confirmé. Une estimation périmée cède la place à l’horaire prévu explicitement identifié.
2. « Configurer un réveil » ouvre une fenêtre avec le catalogue complet, la recherche et le choix de date pour sélectionner un vrai train, la gare et l’avance. Une simple sélection sans activation ne fait pas apparaître le train dans « Temps réel ». « Gérer le réveil » ouvre la même fenêtre depuis le train suivi. Elle se ferme après une activation ou un arrêt confirmé, et reste ouverte en cas d’erreur.
3. « Activer le réveil » demande l’autorisation AlarmKit puis relit les alarmes enregistrées. L’heure souhaitée est distincte de l’heure effectivement enregistrée. Choisir un trajet ne programme aucune alarme et ne remplace pas une alarme existante.
4. Sur un iPhone physique, sélectionner son équipe de signature Xcode. Aucun Mac serveur ni réglage d’adresse réseau n’est nécessaire une fois l’app installée.
5. Une Activité en direct démarre avec un réveil enregistré situé dans les sept prochaines heures, si iOS l’autorise. Plus tôt, son démarrage est différé jusqu’à une ouverture de l’app dans cette fenêtre. Elle affiche l’heure réellement enregistrée, pas une programmation seulement souhaitée.

Le remplacement persiste son intention, programme une nouvelle alarme, la relit puis annule l’ancienne. Une interruption peut laisser deux alarmes : l’app l’affiche et réconcilie au relancement. L’arrêt est persisté avant annulation, pour qu’une mise à jour tardive ne réactive pas le réveil. Une alarme absente, déjà échue ou en sonnerie ne doit pas être recréée automatiquement.

## Données et limites

- L’identité inclut numéro, date, origine, destination et départ planifié. Calendriers et exceptions GTFS sont appliqués; l’horizon du flux est respecté.
- Les listes d’arrêts et les horaires planifiés doivent concorder. Un conflit ou une ambiguïté bloque le réveil pour tout le voyage; aucune variante de calendrier n’est choisie arbitrairement.
- `arrival.estimated` est distinct du départ. Les décalages ISO doivent correspondre au fuseau; les heures GTFS utilisent midi local moins douze heures réelles et acceptent les valeurs supérieures à 24 h.
- Les seuils de prototype sont 120 secondes pour la réception et 300 secondes pour `poll`, avec une tolérance d’horloge de 30 secondes. **`poll` ne date pas la prévision** : l’âge de l’ETA reste inconnu.
- Si aucune estimation exploitable n’existe lors de la création, l’horaire planifié est explicitement affiché. Une mise à jour dégradée ne déplace pas une alarme existante.
- Une estimation dépassée affiche « Arrivée à confirmer ». Aucun passage de gare ni annulation n’est inféré de l’heure ou de la disparition du train.
- Les trajets sont actuellement limités aux numéros 20–99 et aux données couvertes par le GTFS. Ce filtre constitue un périmètre de prototype, pas une qualification commerciale du corridor.
- Source des horaires : VIA Rail Canada inc., [Licence du gouvernement ouvert – Canada](https://open.canada.ca/fr/licence-du-gouvernement-ouvert-canada). Cette licence n’est pas attribuée au [suivi JSON](https://tsimobile.viarail.ca/data/allData.json); les conditions de collecte, cache et redistribution restent à établir avant une bêta ou un service hébergé.

Le cadrage des 13–14 septembre dans `PLAN.md` est historique. Les décisions ultérieures utilisées ici comprennent les ajustements dans les deux sens, l’avance libre et les vraies données dès le prototype. Les documents existants n’ont pas été remplacés.

## Vérifications

```sh
swift test --package-path ios
xcodebuild -project ios/ReveilVIA.xcodeproj -scheme ReveilVIA \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Les tests hors réseau couvrent ZIP/CSV, calendriers, changements d’heure, conflits, péremption, lectures simultanées, cache après relancement hors connexion et état des alarmes. Un test réseau optionnel vérifie les deux sources officielles sans serveur intermédiaire :

```sh
VIA_LIVE_SMOKE=1 swift test --package-path ios --filter officialSourcesWithoutAnyBackend
```

La CI exécute les tests Swift hors réseau et compile l’app pour simulateur. Un succès local ne prouve pas une exécution CI distante. Voir [l’état des validations](docs/PROTOTYPE_STATUS.md) et la [revue visuelle Designly](docs/DESIGN_REVIEW.md).

La décompression utilise ZIPFoundation, version verrouillée par SwiftPM; sa licence MIT est incluse dans `ios/App/ZIPFoundation-LICENSE.txt`. Les anciennes dépendances Python, le serveur HTTP et la configuration Docker ont été retirés.

## Identité visuelle

L’app possède une icône d’accueil. Voir [l’asset et son prompt](docs/ICON.md).

## Prochaine preuve

La version 0.3.2 (5) est signée, installée et lancée sur l’iPhone 16 Pro. Il reste à mesurer programmation, relecture et sonnerie séparément, y compris silencieux/Sommeil, réseau perdu, fermeture forcée et redémarrage. Mesurer ensuite les créneaux réels accordés à BGAppRefreshTask et la durée de l’Activité en direct sur appareil. Une adaptation garantie à trente secondes téléphone verrouillé n’est pas démontrée.

Références : [exemple AlarmKit Apple](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit), [dates GTFS](https://gtfs.org/documentation/schedule/reference/), [images CI GitHub](https://github.com/actions/runner-images).
