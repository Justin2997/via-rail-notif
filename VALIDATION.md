# Validation du plan — 14 septembre 2026

**Verdict : poursuivre un prototype, puis décider du produit à partir des mesures.** SwiftUI et AlarmKit conviennent au réveil local. Les données VIA observées rendent l’intégration plausible. Cette recherche ne valide pas encore un réveil qui suit automatiquement toutes les variations d’arrivée pendant le sommeil.

Trois agents ont examiné indépendamment iOS, les données VIA et l’architecture. La synthèse a revérifié le contre-exemple GTFS à partir des fichiers téléchargés et étudié Core Location comme variante. Travail effectué en lecture seule sur les services : sources Apple/VIA/GTFS, deux lectures du suivi, un téléchargement GTFS et inspection du dépôt. Aucun prototype, essai iPhone, déploiement ou contact avec VIA n’a été réalisé.

Les résultats ci-dessous distinguent documentation, observation ponctuelle et recommandations. Les corrections sont intégrées à [PLAN.md](PLAN.md); les mesures VIA et le désaccord de desserte sont conservés dans [les preuves structurées](research/validation-2026-09-14.json).

**Constats déterminants**

1. **AlarmKit est le bon point de départ; la sonnerie reste à éprouver sur appareil.** Le framework fournit des alarmes autorisées depuis iOS 26, passant le silencieux et les modes de concentration. `AlarmManager` expose programmation, lecture et observation de l’état. Aucune opération de remplacement atomique n’a été identifiée dans le contrat consulté. Le premier prototype doit rester une alarme à date fixe, sans compte à rebours ni snooze si l’extension Widget est différée. [Présentation Apple](https://developer.apple.com/videos/play/wwdc2025/230/), [AlarmManager](https://developer.apple.com/documentation/alarmkit/alarmmanager), [exemple de programmation](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)

2. **Une collecte fréquente ne donne pas une adaptation fréquente sur iPhone.** Apple ne garantit ni la livraison ni le délai des notifications silencieuses, recommande de ne pas dépasser deux ou trois envois par heure, et laisse le système décider du lancement des tâches de rafraîchissement. C’est une limite documentée; quelques essais réussis ne la suppriment pas. Un produit aux limites mesurées reste possible. [Notifications silencieuses](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app), [tâches de fond](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)

3. **La règle initiale du premier plan pouvait armer trop tard.** Contre-exemple de calcul : arrivée planifiée à 14 h, première ETA à 14 h 30 et avance de 15 minutes donnent une alarme à 14 h 15. Si le train arrive finalement à 14 h sans mise à jour appliquée, le réveil sonne après l’arrivée, même sans report ultérieur. Le plan propose maintenant un repère initial prudent fondé sur la plus tôt des heures compatibles, et traite le cas où ce repère est déjà passé. Cette précaution réduit ce risque sans garantir une avance sur toute arrivée réelle.

4. **GTFS et suivi peuvent décrire des dessertes différentes.** Le lundi 14 septembre, le trajet GTFS 541 du train 26 comporte dix arrêts, sans Coteau. Le trajet 95 comporte Coteau mais circule le vendredi; aucune exception de calendrier ne concerne ces deux services. Les deux lectures du suivi incluent pourtant Coteau pour le 14 septembre. Le désaccord est confirmé; sa cause ne l’est pas. La correction est de conserver les provenances et de ne pas proposer de réveil lié à cet arrêt tant que sa desserte n’est pas établie. [GTFS VIA](https://www.viarail.ca/sites/all/files/gtfs/viarail.zip), [suivi VIA](https://tsimobile.viarail.ca/data/allData.json)

5. **La licence GTFS ne justifie pas à elle seule un service temps réel.** La page développeurs associe explicitement le téléchargement GTFS à la licence ouverte canadienne. Aucune licence équivalente du JSON n’a été trouvée. Les conditions générales visent aussi les autres sites exploités par VIA et comportent des restrictions commerciales. L’application précise de ces dispositions à la collecte, au cache et à la redistribution doit être éclaircie avant une bêta fondée sur ce flux. Cette revue ne tranche pas le statut juridique d’un prototype local. [Ressources VIA](https://www.viarail.ca/en/developer-resources), [licence](https://open.canada.ca/en/open-government-licence-canada), [conditions VIA](https://www.viarail.ca/en/terms-and-conditions)

6. **Le serveur complet et le calendrier étaient prématurés.** Le dépôt contient seulement la route Hello World et son test. Le Dockerfile existant ne copie pas le code de l’application et ne définit pas sa commande de démarrage. Le prototype local et un petit banc d’actualisation suffisent pour trancher les premières questions. PostgreSQL et l’API complète viennent ensuite, si utiles. L’estimation précédente de trois à cinq semaines est retirée comme base de planification; le travail restant sera estimé après les prototypes.

**Ce que montrent les données VIA**

| Capture UTC le 14 septembre | Réponse / trajets | Date HTTP du fichier | Ancienneté des observations `poll` présentes |
| --- | --- | --- | --- |
| 11:15:41 | 200 / 65 | 11:15:32 | Environ 1,18 à 3,48 minutes |
| 11:18:17 | 200 / 65 | 11:18:02 | Environ 2,80 à 4,05 minutes |

Ces deux captures ne prouvent ni la précision des ETA ni la disponibilité sur un trajet complet. Aucun horodatage propre aux prévisions de chaque arrêt n’a été identifié. L’âge d’un `poll` et l’âge de réception HTTP doivent donc rester séparés de l’âge, éventuellement inconnu, de la prévision.

La jointure vérifiée passe par `trip_short_name`, `calendar` et `calendar_dates`, puis `stops.stop_code` et `stop_times.stop_id`. Les codes des 300 gares de l’échantillon ont une correspondance, mais cela ne résout pas le désaccord de desserte. Le GTFS annonce un horizon du 17 août au 17 décembre 2026 : les calendriers de services plus longs ne doivent pas étendre implicitement sa validité. La conversion GTFS suit le fuseau de l’agence, avec des heures pouvant dépasser 24 h; les dates JSON sont traitées séparément. [Spécification GTFS](https://gtfs.org/documentation/schedule/reference/)

**Pistes supplémentaires à éprouver**

| Piste | Base vérifiée | Ce qui reste à démontrer |
| --- | --- | --- |
| Localisation pendant le trajet | Core Location prévoit des sessions en arrière-plan pour des fonctions réelles de localisation et des actions liées à la proximité. | Réception à bord, précision, énergie consommée et capacité à appliquer l’alarme à temps. Une zone géographique ne correspond pas à une durée garantie avant l’arrivée. |
| Notification Service Extension | Un push visible approprié peut exécuter une extension pour modifier la notification. | Autorisation et identité du client AlarmKit depuis l’extension, accès aux alarmes de l’app principale et remplacement effectif. La réussite ne garantirait toujours pas la livraison ponctuelle d’APNs. |
| Live Activities / App Intents | Affichage actualisable et actions système. La nouveauté AlarmKit présentée à la WWDC26 enrichit le contexte fourni à Siri. | Les documents consultés n’établissent pas une commande serveur fiable de reprogrammation d’alarme par ces mécanismes. |

Sources de ces pistes : [Core Location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background), [déclencheurs de proximité et leurs heuristiques](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger), [extension de notification](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension), [ActivityKit](https://developer.apple.com/documentation/ActivityKit/starting-and-updating-live-activities-with-activitykit-push-notifications), [session WWDC26](https://developer.apple.com/videos/play/wwdc2026/343/).

Core Location ne doit pas être écarté au motif général qu’aucune app ne peut être relancée après fermeture forcée : une réponse d’un ingénieur Apple décrit des relancements par surveillance de régions, avec heuristiques et limites. Ce témoignage technique n’est pas une garantie de précision à grande vitesse. [Réponse Apple de mars 2026](https://developer.apple.com/forums/thread/818908)

Les tâches continues en arrière-plan et les Critical Alerts n’ont pas fourni de solution démontrée pour ce produit : les premières peuvent être interrompues; les secondes nécessitent un entitlement dont l’obtention pour cet usage est inconnue. [Tâches continues](https://developer.apple.com/documentation/BackgroundTasks/BGContinuedProcessingTask), [Critical Alerts](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts)

**Conditions pour poursuivre vers une bêta**

Avant les essais, fixer le délai acceptable d’application d’un changement, la tolérance de sonnerie, la marge minimale recherchée et le budget batterie. Ces seuils seront des exigences du prototype, pas des garanties attribuées à Apple ou VIA.

| Preuve attendue | Critère de décision |
| --- | --- |
| Calculs et sélection | Tous les scénarios définis produisent la bonne date et le bon arrêt, y compris retard initial, rattrapage sans livraison, passage de minuit et désaccord Coteau. |
| Réconciliation et arrêt | Aucun faux état activé/désactivé dans les échecs injectés. Aucun ancien message ne recrée une génération arrêtée ou terminée. |
| Programmation locale | Après interruption d’un remplacement, identifier les alarmes effectivement présentes et récupérer vers un état explicite. L’invariant doit être démontré par le prototype. |
| Sonnerie physique | Consigner nombre d’essais, iPhone/iOS, configuration, heure programmée, début et durée de sonnerie observés extérieurement. Tester sans débogueur et sur plusieurs heures. |
| Adaptation | Mesurer séparément événement source, réception, exécution, programmation relue et sonnerie. Un changement appliqué après l’échéance compte comme échec pour ce scénario. |
| Données et diffusion | Conditions de réutilisation établies, liste de dessertes qualifiées et comportement connu en cas d’indisponibilité ou de conflit. |
| Produit | Choisir explicitement les configurations prises en charge et le compromis entre sommeil prolongé et réveil anticipé; ne pas présenter les reports manuels comme une adaptation automatique validée. |

La matrice physique doit ajouter aux états réseau, Sommeil et économie d’énergie : fermeture forcée, redémarrage avant déverrouillage, application masquée ou protégée, casque, boutons physiques et alarme Horloge simultanée. Une FAQ signée par un ingénieur DTS en août 2025 décrit des limites pour plusieurs de ces cas; elles constituent des points à revérifier sur l’iOS ciblé, pas des résultats obtenus ici. [FAQ AlarmKit](https://developer.apple.com/forums/thread/797158)

La recherche valide donc l’intérêt d’un prototype ciblé. La preuve restante porte sur le comportement central : obtenir une alarme correctement ajustée et audible avant l’arrêt choisi dans les conditions de voyage retenues.
