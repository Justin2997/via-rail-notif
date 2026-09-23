# État du prototype — 23 septembre 2026

L’app est autonome : aucun backend propre au projet, aucun serveur local et aucune clé API. Les fichiers Python, Poetry et Docker ont été retirés. Le plan et les recherches existants sont conservés comme historique. Aucun commit, push, publication App Store ou résultat CI distant.

## Incrément 0.3.2 — dashboard sans onglets

- « Temps réel » est l’unique écran principal; l’onglet « Réveil » et la barre d’onglets sont retirés.
- « Configurer un réveil » / « Gérer le réveil » ouvrent le formulaire dans une fenêtre. Fermeture automatique après activation ou arrêt confirmé; les erreurs restent visibles.
- Choix du train, de la gare, de l’avance et arrêt AlarmKit conservés.
- Compilations simulateur et appareil réussies. Version 0.3.2 (5) signée, installée et lancée sur iPhone 16 Pro; processus principal présent après lancement.
- Parcours sur simulateur avec le vrai train 41 : ouverture, sélection, activation, retour automatique au dashboard, gestion, arrêt puis retour à l’état vide. Alarme d’essai arrêtée.

[Configuration](evidence/alarm-editor-0.3.2.png) · [Dashboard actif](evidence/dashboard-0.3.2-active.png) · [Après arrêt](evidence/dashboard-0.3.2-stopped.png) · [Déploiement](evidence/deployment-0.3.2.json)

## Incrément 0.3.1 — uniquement les trains avec réveil

- « Temps réel » ne présente plus le catalogue, le filtre de recherche ou le sélecteur de date. Le train du réveil actif est affiché indépendamment du trajet en cours de sélection dans « Réveil ».
- Sans alarme : état vide avec accès à la configuration. Une alarme encore présente dans AlarmKit reste visible, y compris pendant sa sonnerie ou un arrêt non confirmé.
- La liste complète reste dans le sélecteur de train de « Réveil ». Les données de suivi sont associées à l’identité et à la date de l’alarme.
- Le détail met en avant l’arrivée à la gare cible du réveil et conserve cette gare lors de l’ouverture de sa configuration.
- Compilation simulateur et appareil réussie; 0.3.1 (4) signée, installée et lancée sur iPhone. Validation visuelle du parcours activation → suivi → arrêt dans le simulateur; preuves ci-dessous.

[Sans réveil](evidence/dashboard-0.3.1-empty.png) · [Train suivi](evidence/dashboard-0.3.1-active.png) · [Après arrêt](evidence/dashboard-0.3.1-stopped.png)

## Incrément 0.3 — dashboard et réveil séparés

- « Temps réel » : chargement automatique des sources VIA réelles, recherche, date, liste et détail des gares; distinction entre horaire prévu et estimation récente.
- « Réveil » : choix du train réel, de la gare et de l’avance; activation explicite. Aucun train synthétique proposé. Les anciennes alarmes synthétiques encore actives restent accessibles pour être arrêtées.
- Consultation d’une autre date indépendante du suivi du réveil actif.
- Couleurs adaptées aux modes clair/sombre et disposition verticale aux tailles de texte d’accessibilité.
- Revue avec le skill Designly visual-qa : captures réelles du simulateur inspectées, contrastes et disposition corrigés. [Rapport](DESIGN_REVIEW.md).

| Vérification actuelle | Résultat du 23 septembre |
| --- | --- |
| Tests Swift avec test réseau activé | 31 tests réussis; sources officielles lues directement, 46 trajets pour le 23 septembre, dont 13 bloqués par les contrôles. Mesure ponctuelle. |
| Compilation simulateur et appareil | Réussies; version 0.3.0 (3). |
| Signature | Vérifiée avec `codesign --verify --deep --strict`. |
| iPhone 16 Pro | Installation réussie, lancement réussi à 07:41 HAE, processus principal encore présent lors de la vérification suivante (PID 44409). |
| Parcours visuel | Navigation dashboard → détail, onglet réveil → choix d’un vrai train; clair/sombre et Dynamic Type accessibility-medium inspectés. Aucune alarme activée pour ces captures. |
| Accessibilité | Contrastes personnalisés calculés et grands caractères contrôlés; VoiceOver et toutes les tailles/appareils non audités. |

Preuves : [manifest de déploiement](evidence/deployment-0.3.json), [dashboard](evidence/dashboard-0.3.png), [réveil](evidence/alarm-0.3.png). La barre de statut du simulateur affiche une heure forcée; elle ne date pas les observations.

## Historique 0.2 — suivi local et identité

- Icône 1024 × 1024 opaque et logo intégrés aux assets iOS.
- Actualisation chaque minute pendant un réveil actif lorsque l’app est au premier plan, ainsi qu’au retour dans l’app.
- BGAppRefreshTask déclaré, demandé et replanifié pour un réveil réel actif. L’expiration de la tâche empêche l’application tardive de la réponse; l’horaire d’exécution appartient à iOS. Une demande déposée ne prouve pas son exécution en veille.
- Les réponses commencées avant l’arrêt ou le remplacement d’une session sont ignorées.
- Extension WidgetKit pour écran verrouillé et Dynamic Island. Elle affiche l’heure effectivement relue dans AlarmKit et signale le suivi périmé. Démarrage au premier plan à moins de sept heures du réveil; mises à jour silencieuses et fin lors de l’arrêt.
- Aucune notification distante, aucun serveur et aucun contournement par une session audio ou GPS permanente.

## Preuves historiques 0.2

| Vérification | Résultat |
| --- | --- |
| Tests Swift, Xcode 26.1.1 | 28 tests hors réseau réussis pour la version 0.2; test réseau optionnel non relancé à cet incrément. Le test direct VIA avait réussi pendant la migration autonome. |
| Lecteur natif | ZIP décompressé en mémoire, CSV, calendriers/exceptions, fuseaux, conflits de desserte et horaires, navette sans numéro ignorée, observations non ordonnables bloquées. |
| Cache hors connexion | Test réussi après relancement du client avec réseau indisponible : mêmes trajets, date de réception originale conservée, estimations périmées remplacées par horaires planifiés explicitement identifiés. Premier lancement sans réseau ni cache signalé en erreur. |
| Sources VIA directes | GTFS et JSON lus depuis Swift sans intermédiaire : 46 trajets du 22 septembre, dont 7 bloqués par les contrôles. Mesure ponctuelle, pas une qualification de toute la couverture. |
| Compilation simulateur iOS 26.1 | Réussie sans erreur ni avertissement rapporté par le build. |
| Installation et lancement simulateur | Version 0.2 compilée et lancée; examen visuel de la nouvelle Activité en direct non confirmé : le simulateur dédié est resté bloqué au démarrage du système, puis le disque du Mac a été saturé. Le simulateur de test et les caches de compilation propres à cet incrément ont été nettoyés. Le chargement VIA direct avait été observé dans la version autonome précédente. |
| Installation iPhone 16 Pro | Version 0.2.0 (2) compilée pour arm64, signée et vérifiée avec codesign, puis installée. Le premier lancement a été refusé car l’iPhone était verrouillé; validation du lancement en attente. |
| Icône sur iPhone | Icône réellement installée récupérée depuis l’appareil, sans image de remplacement; voir `evidence/iphone-installed-icon.png`. |
| Configuration réseau | Aucune adresse de serveur configurable, permission réseau local ou exception ATS dans le build. Aucun processus en écoute sur le port 8000 lors de la vérification. |
| AlarmKit | Moteur local conservé; 13 tests sur l’état des alarmes et la politique de suivi passent. Lors de l’incrément précédent, programmation, déplacements dans les deux sens et annulation ont été relus dans le simulateur. Aucune sonnerie sur iPhone physique démontrée. |
| GitHub Actions | Workflow désormais limité aux tests Swift et à la compilation iOS; non exécuté à distance. |

[Capture du chargement autonome dans le simulateur](evidence/autonomous-simulator.png). L’heure affichée dans la barre de statut du simulateur est forcée et ne sert pas de preuve temporelle.

## Périmètre livré

- Une app iPhone SwiftUI, une alarme active, choix du train, de sa date, d’une gare et d’une avance de 1 à 1 440 minutes avec raccourcis 10/15/30.
- Lecture HTTPS directe des sources VIA, parsing et rapprochement sur l’iPhone, cache atomique local. GTFS actualisé après six heures; chargements répétés espacés et simultanés mutualisés.
- Horaires et ETA conservés séparément; conflits bloquants; aucune estimation périmée présentée comme actuelle.
- Carte de la dernière position publiée, sans position inventée.
- Réconciliation de l’alarme depuis l’état système; arrêt persisté; ajustement antérieur/postérieur lorsque l’app reçoit une nouvelle estimation exploitable.
- Données VIA réelles dès l’ouverture; cache local hors connexion. La consultation initiale et les nouvelles estimations VIA nécessitent Internet.

## Travail restant pour le produit prévu

1. Sur le build signé installé et lancé sur iPhone, mesurer la sonnerie, le remplacement, les autorisations révoquées et les interruptions. La programmation relue en simulateur ne remplace pas cette preuve.
2. Mesurer les occasions réelles d’actualisation téléphone verrouillé. Le handler BGAppRefreshTask est implémenté; la fréquence effective n’est pas garantie.
3. Éprouver la durée de l’Activité en direct et le démarrage différé sur appareil. Sans push serveur, une nouvelle activité différée nécessite une ouverture de l’app au moment approprié.
4. Mesurer ou décider explicitement l’acceptation de l’âge inconnu des prévisions, confirmer les conditions de réutilisation du JSON et qualifier les dessertes pour une bêta.
5. Élargir l’avance au-delà de la limite de prototype si nécessaire, la couverture des services et les preuves de progression/annulation. Le flux courant ne permet pas à lui seul de certifier un passage de gare.

L’objectif de sonnerie à trente secondes dans les scénarios connectés et verrouillés n’est pas atteint ni mesuré. Le prototype conserve les heures enregistrées lorsque les mises à jour sont absentes, contradictoires, périmées ou non ordonnables.
