# Réveil VIA — bêta iOS

Application compagnon indépendante : app SwiftUI iOS 26, alarme locale AlarmKit, choix du train/de la gare/de l’avance, connexion directe aux sources VIA et rapprochement des horaires GTFS avec le suivi VIA sur l’iPhone. « Réveil VIA » est l’unique écran principal : l’heure réellement enregistrée est mise en avant, avec la gare cible et un résumé du trajet. La configuration du réveil s’ouvre dans une fenêtre depuis le dashboard. Les données VIA réelles sont chargées dès l’ouverture; aucun trajet de démonstration n’est proposé.

L’app ajuste une alarme vers une heure antérieure ou postérieure lorsqu’une nouvelle estimation exploitable est chargée dans l’app. **Le dashboard est actualisé environ chaque minute lorsque l’app est au premier plan, même sans réveil actif. En veille, les actualisations sont opportunistes et décidées par iOS.** Une Activité en direct affiche le réveil enregistré et signale le suivi périmé. Aucune sonnerie sur iPhone physique ni précision de trente secondes n’est démontrée. La distribution visée est une première bêta TestFlight.

## Développement et contribution

Code Swift/SwiftUI, iOS 26 minimum, Xcode 26.1+ et Swift 6.2. Pour commencer, cloner le dépôt, ouvrir `ios/ReveilVIA.xcodeproj` et choisir le scheme `ReveilVIA`. Les tests et la compilation pour simulateur ne nécessitent aucune clé ni équipe Apple. Pour un appareil physique, choisir votre propre équipe pour l’app et l’extension.

Les contributions en français ou en anglais sont bienvenues : [guide de contribution](CONTRIBUTING.md) et [signalement de sécurité](SECURITY.md). Les documents de validation antérieurs sont des relevés historiques; ils ne constituent pas une preuve de validation de chaque nouvelle version.

La licence du code reste à choisir par le propriétaire avant de présenter le projet comme librement réutilisable. ZIPFoundation possède sa propre licence MIT. Les données et marques VIA ne sont pas couvertes par une éventuelle licence du code; les paysages intégrés sont des illustrations générées.

## Application autonome

Aucun serveur à installer, compte à créer ou clé API à fournir. L’iPhone télécharge directement les horaires GTFS et le suivi JSON publiés par VIA, en HTTPS. La décompression ZIP, la lecture CSV, les contrôles de cohérence, le calcul du réveil et la gestion AlarmKit sont exécutés dans l’app.

Les horaires et le dernier suivi sont sauvegardés localement. Le GTFS est actualisé après six heures; les lectures répétées sont espacées d’au moins une minute lorsque les horaires sont déjà disponibles pour la date demandée. Les chargements simultanés partagent les transferts. Aucun collecteur distant ni ressource cloud. Au premier plan, les lectures alimentent la date consultée et le réveil actif. En arrière-plan, elles concernent uniquement un réveil réel actif et s’arrêtent quand celui-ci est arrêté ou échu. Consulter une autre date ne redirige pas le suivi de l’alarme.

Internet est nécessaire au premier chargement réel et aux nouvelles estimations. Hors connexion, l’app utilise les données déjà sauvegardées avec leur date d’origine et conserve l’alarme programmée. L’autonomie vis-à-vis d’un serveur propre au projet ne garantit pas des mises à jour permanentes en arrière-plan sur iOS.

## Ouvrir l’app

Ouvrir `ios/ReveilVIA.xcodeproj` dans Xcode 26.1 ou ultérieur, choisir le scheme `ReveilVIA` et un iPhone iOS 26. Le projet généré est inclus; [XcodeGen](https://github.com/yonaskolb/XcodeGen) n’est nécessaire que pour modifier sa structure :

```sh
xcodegen generate --spec ios/project.yml
```

1. « Réveil VIA » affiche uniquement le train associé au réveil actif (un seul réveil à la fois), avec sa gare cible et la date de réception. Sans réveil, un bouton invite à en configurer un. Le train disparaît après l’arrêt confirmé. Une estimation périmée cède la place à l’horaire prévu explicitement identifié.
2. « Configurer un réveil » ouvre une fenêtre avec le catalogue complet, la recherche et le choix de date pour sélectionner un vrai train, la gare et l’avance. Une simple sélection sans activation ne fait pas apparaître le train sur le dashboard. « Gérer le réveil » ouvre la même fenêtre depuis le train suivi. Elle se ferme après une activation ou un arrêt confirmé, et reste ouverte en cas d’erreur.
3. « Activer le réveil » demande l’autorisation AlarmKit puis relit les alarmes enregistrées. L’heure souhaitée est distincte de l’heure effectivement enregistrée. Choisir un trajet ne programme aucune alarme et ne remplace pas une alarme existante.
4. Sur un iPhone physique, sélectionner son équipe de signature Xcode. Aucun Mac serveur ni réglage d’adresse réseau n’est nécessaire une fois l’app installée.
5. Une Activité en direct démarre dès l’ouverture de l’app avec un réveil enregistré futur, si iOS l’autorise, y compris pour les trajets de plusieurs jours. iOS limite sa durée active à huit heures; une réouverture de l’app peut démarrer une nouvelle carte après expiration. Elle affiche l’heure réellement enregistrée, pas une programmation seulement souhaitée. Si les autorisations sont désactivées ou si le démarrage échoue, le dashboard l’indique.

Le remplacement persiste son intention, programme une nouvelle alarme, la relit puis annule l’ancienne. Une interruption peut laisser deux alarmes : l’app l’affiche et réconcilie au relancement. L’arrêt est persisté avant annulation, pour qu’une mise à jour tardive ne réactive pas le réveil. Une alarme absente, déjà échue ou en sonnerie ne doit pas être recréée automatiquement.

## Données et limites

- L’identité inclut numéro, date, origine, destination et départ planifié. Calendriers et exceptions GTFS sont appliqués; l’horizon du flux est respecté.
- Les arrêts publiés doivent former un sous-ensemble unique et ordonné de la desserte GTFS, et les horaires planifiés doivent concorder. VIA peut publier seulement une fenêtre d’arrêts pour un trajet longue distance; les gares restantes gardent leur horaire prévu. Un conflit ou une ambiguïté bloque le réveil pour tout le voyage; aucune variante de calendrier n’est choisie arbitrairement.
- `arrival.estimated` est distinct du départ. Les décalages ISO doivent correspondre au fuseau; les heures GTFS utilisent midi local moins douze heures réelles et acceptent les valeurs supérieures à 24 h.
- Les seuils de fraîcheur sont 120 secondes pour la réception et 300 secondes pour `poll`, avec une tolérance d’horloge de 30 secondes. **`poll` ne date pas la prévision** : l’âge de l’ETA reste inconnu.
- Si aucune estimation exploitable n’existe lors de la création, l’horaire planifié est explicitement affiché. Une mise à jour dégradée ne déplace pas une alarme existante.
- Une estimation dépassée affiche « Arrivée à confirmer ». Aucun passage de gare ni annulation n’est inféré de l’heure ou de la disparition du train.
- Tous les trains numérotés publiés dans le GTFS sont inclus, y compris les numéros composés. Les trajets de plusieurs jours restent consultables avec leur date de départ originale. Les heures GTFS utilisent le fuseau de l’agence; l’interface affiche la date et le fuseau local de chaque gare. Les transferts non numérotés ne sont pas des trains sélectionnables.
- Source des horaires : VIA Rail Canada inc., [Licence du gouvernement ouvert – Canada](https://open.canada.ca/fr/licence-du-gouvernement-ouvert-canada). Cette licence n’est pas attribuée au [suivi JSON](https://tsimobile.viarail.ca/data/allData.json); les conditions de collecte, cache et redistribution restent à établir avant une bêta ou un service hébergé.

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

La CI exécute les tests Swift hors réseau et compile l’app pour simulateur. Voir la [revue de simplicité](docs/MINIMALIST_REVIEW.md) pour les changements d’interface et leurs limites.

La décompression utilise ZIPFoundation, version verrouillée par SwiftPM; sa licence MIT est incluse dans `ios/App/ZIPFoundation-LICENSE.txt`. Les anciennes dépendances Python, le serveur HTTP et la configuration Docker ont été retirés.

## Validation sur appareil

Des builds de développement ont été signés, installés et lancés sur l’iPhone 16 Pro pendant cette itération. La version source actuelle est 1.0 (9), signée, installée et lancée sur l’iPhone après les corrections et l’ajout de la carte de progression sur l’écran verrouillé. L’archive 1.0 (6) est antérieure aux corrections. Voir [l’audit du code](docs/CODE_AUDIT.md). Installation et lancement ne prouvent pas la sonnerie : il reste à mesurer programmation, relecture et sonnerie séparément, y compris silencieux/Sommeil, réseau perdu, fermeture forcée et redémarrage. Les actualisations en arrière-plan sont opportunistes; une adaptation garantie à trente secondes téléphone verrouillé n’est pas démontrée.

La page Informations donne accès à la confidentialité, aux limites du suivi et aux sources. Le bundle identifier historique est conservé pour préserver les mises à jour et le réveil existant; le suffixe technique `.prototype` ne s’affiche pas aux voyageurs.

Références : [exemple AlarmKit Apple](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit), [dates GTFS](https://gtfs.org/documentation/schedule/reference/), [images CI GitHub](https://github.com/actions/runner-images).

## English and French

The app, alarm alerts, accessibility labels and Live Activity support English and French. The English name is **VIA Wake**; the French name remains **Réveil VIA**. iOS selects the language from your preferred languages. You can also choose English or French in Settings → Apps → VIA Wake → Language. Date and time formatting follows your locale while keeping each station’s time zone.

To preview either language in Xcode, edit the `ReveilVIA` scheme’s Run options and set App Language to English or French. Recreate an existing alarm or Live Activity after changing languages so its system presentation uses the new language.
