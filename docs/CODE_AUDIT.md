# Audit du code — Réveil VIA 1.0 (7)

Réalisé le 4 octobre 2026 sur le code natif actuel et les modifications non commitées de cette session. Périmètre : machine d’état des alarmes et persistance, pilotes AlarmKit/ActivityKit, actualisations et navigation, client réseau/cache, ZIP/CSV/GTFS, rapprochement du suivi VIA, trajets de plusieurs jours, fuseaux, interface et configuration de distribution.

## Problèmes corrigés

| Impact | Problème | Correction |
| --- | --- | --- |
| Élevé | Une modification échouée conservait l’ancienne alarme mais pouvait remplacer le trajet, la gare et l’avance sauvegardés. | Restaurer la session précédente seulement si le système confirme que la nouvelle alarme n’a pas été installée. Conserver la reprise transactionnelle si l’état système est inconnu. |
| Élevé | Un pilote pouvait signaler une erreur après avoir installé la nouvelle alarme. | Relire les alarmes : une nouvelle programmation réellement installée et vérifiée est réconciliée, sans revenir arbitrairement à l’ancienne. |
| Élevé | Après interruption pendant un remplacement, le nettoyage pouvait annuler une ancienne alarme déjà en sonnerie. | La réconciliation ne nettoie pas les autres alarmes lorsqu’une alarme sonne; l’arrêt reste explicite. |
| Élevé | Le temps pouvait devenir passé pendant la demande d’autorisation AlarmKit. | Vérifier de nouveau l’heure après autorisation; une sonnerie immédiate exige toujours la confirmation. |
| Élevé | Le fuseau déclaré par le suivi pouvait remplacer celui de la gare GTFS pour valider un décalage horaire. | Valider les instants contre le fuseau de la gare publiée dans le GTFS; rejeter un fuseau de gare invalide. |
| Élevé | Des horaires planifiés non chronologiques pouvaient permettre une alarme avant un arrêt précédent. | Vérifier arrivée/départ de chaque arrêt et la continuité entre arrêts; bloquer un trajet temporellement incohérent. |
| Modéré | Le parsing des heures ignorait certaines composantes non numériques et pouvait réinterpréter une heure mal formée. | Exiger une heure GTFS complète et valide avant conversion, y compris les heures supérieures à 24. |
| Modéré | Une heure énorme dans un trajet inactif pouvait étendre indéfiniment la recherche des jours précédents. | Limiter la recherche aux heures GTFS effectivement prises en charge, au maximum 240 heures. |
| Modéré | L’addition de tailles ZIP déclarées pouvait déborder avant le contrôle de limite. | Vérifier chaque taille contre la capacité restante avant addition. Aucun fichier de l’archive n’est extrait sur disque. |
| Modéré | Une consultation hors horizon pouvait faire échouer une consultation valide partageant le même téléchargement. | Normaliser la date du demandeur en attente lorsque les horaires partagés ont déjà été chargés. |
| Modéré | Plusieurs alarmes pouvaient être décrites comme une seule programmation vérifiée. | Afficher explicitement l’ambiguïté; ne confirmer une programmation unique que si son heure concorde. |

Les tests de régression couvrent notamment restauration complète après échec, erreur après installation, sonnerie pendant une reprise, délai d’autorisation, chronologie, fuseaux, parsing, bornage du catalogue, requêtes concurrentes et alarmes dupliquées.

## Vérifications

- 50 tests Swift hors réseau réussis. Les tests d’alarme utilisent un pilote simulé : ils vérifient la logique, pas la sonnerie physique.
- Test réseau optionnel avec GTFS et suivi VIA réels réussi : 63 trajets visibles; instances courantes des trains 1, 2, 14, 15 et 693 sans conflit. Huit trajets incohérents restent bloqués.
- Compilation complète app et extension pour simulateur réussie avec Xcode 26.1.1. Le manifeste de confidentialité ZIPFoundation est présent dans l’app compilée.
- `git diff --check` réussi. Projet régénéré depuis `ios/project.yml`; app et extension utilisent la version 1.0 et le build 7.

Commandes :

```sh
swift test --package-path ios
VIA_LIVE_SMOKE=1 swift test --package-path ios --filter officialSourcesWithoutAnyBackend
xcodebuild -project ios/ReveilVIA.xcodeproj -scheme ReveilVIA \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Limites avant distribution

Aucun nouveau build signé, archive de distribution ou déploiement sur l’iPhone n’a été réalisé pendant cet audit : le propriétaire fera son build. L’archive 1.0 (6) et l’installation sur l’iPhone sont antérieures aux corrections; reconstruire depuis les sources actuelles 1.0 (7).

Il reste à vérifier la sonnerie réelle, les changements d’heure d’alarme sur appareil, l’écran verrouillé, silencieux/Sommeil, les interruptions de réseau et le redémarrage. Les actualisations iOS en arrière-plan demeurent opportunistes. L’audit ne démontre pas une adaptation permanente téléphone verrouillé.

Les démarches de distribution restent séparées : acceptation du contrat Apple signalé par l’export précédent, profils App Store Connect, contacts/URL de confidentialité, droits de la photographie VIA et conditions du suivi JSON. Aucun nouveau problème bloquant dans le code relu ne reste identifié après les corrections; cela ne garantit pas l’absence de tout défaut ni l’approbation Apple.


## Installation après audit — 4 octobre 2026

À la demande du propriétaire, la version source 1.0 (7) a ensuite été compilée et signée en développement pour l’iPhone 16 Pro Justin, installée par le réseau et lancée avec succès (13 h 01, America/Toronto). L’installation est une mise à jour du même bundle identifier. Aucun envoi TestFlight et aucune sonnerie physique ne sont démontrés par cette opération. L’archive 1.0 (6) demeure antérieure aux corrections.
