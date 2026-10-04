# Réveil VIA — première bêta TestFlight

Sources actuelles : version 1.0 (9), iPhone iOS 26 minimum. Application compagnon indépendante, sans compte ni serveur applicatif. Le bundle identifier historique `ca.codingpanda.reveilvia.prototype` est conservé pour permettre la mise à jour de l’installation et de son réveil existant.

## État vérifié le 4 octobre 2026

- 50 tests Swift hors réseau passent : calendriers, fuseaux/changements d’heure, trajets de quatre jours, remplacement d’alarme, reprise après interruption, conservation des anciens trajets enregistrés, relevés partiels, gares sans horaires, numéros composés et progression temporelle.
- Test avec les deux sources VIA réelles : 63 trajets visibles. Les instances courantes des trains 1, 2, 14, 15 et 693 ne présentent pas de conflit. Huit autres trajets présentent des incohérences et restent bloqués : aucun conflit réel n’est ignoré pour permettre une alarme.
- Archive Release 1.0 (6), antérieure à l’audit, signée en développement : compilation réussie. Cette archive ne contient pas les corrections de l’audit : reconstruire les sources actuelles 1.0 (9). Compilation app/extension pour simulateur vérifiée après audit. Version et build de l’app et de l’extension alignés sur les réglages Xcode.
- Cette archive est installée et lancée sur l’iPhone 16 Pro connecté par le réseau. Cela ne démontre pas la sonnerie physique ni les mises à jour téléphone verrouillé.
- Icône 1024 × 1024 sans transparence; confidentialité accessible dans l’app; chiffrement limité aux fonctionnalités HTTPS du système (`ITSAppUsesNonExemptEncryption = false`).

Rapport de code : `CODE_AUDIT.md`. Aucun nouvel envoi ou déploiement n’a été réalisé pendant l’audit; le propriétaire fera le build de distribution.

## Blocage Apple observé

L’export App Store Connect, essayé avec la gestion automatique des profils, échoue avec **Unable to process request – PLA Update available**, puis absence des profils de distribution pour l’app et son extension. Le titulaire du compte doit accepter le contrat mis à jour dans le portail développeur. L’archive actuelle utilise une signature de développement; elle n’est pas un IPA distribué par TestFlight. Aucun build n’a été téléversé et aucun testeur n’a été invité.

Archive conservée dans Xcode Organizer :
Archive locale `ReveilVIA 1.0 (6).xcarchive` dans Xcode Organizer, datée du 4 octobre 2026.

Après résolution du contrat et reconstruction des sources 1.0 (9), reprendre l’export automatique de la nouvelle archive pour App Store Connect, vérifier/enregistrer les identifiants explicites de l’app et de l’extension et la fiche de l’app, puis téléverser et attendre le traitement Apple. Le numéro 9 devra être augmenté s’il est déjà utilisé dans App Store Connect. Une première bêta externe peut nécessiter Beta App Review.

Exemple d’export de la nouvelle archive créée dans Xcode après acceptation du contrat (remplacer le chemin) :

```sh
xcodebuild -exportArchive \
  -archivePath '/chemin/vers/la/nouvelle/archive-1.0-9.xcarchive' \
  -exportPath /tmp/via-testflight-export \
  -exportOptionsPlist ios/ExportOptions-TestFlight.plist \
  -allowProvisioningUpdates
```

Le fichier partagé ne contient pas d’équipe Apple personnelle. Sélectionner votre équipe dans Xcode pour l’app et l’extension; au besoin copier les options dans `ios/ExportOptions-Local.plist` (ignoré par Git) et y renseigner votre `teamID`.

Cette commande exporte localement; elle ne téléverse pas automatiquement le build. Xcode Organizer permet ensuite de valider et distribuer vers App Store Connect avec le compte connecté.

Référence Apple : https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/

## Informations TestFlight préparées

**Description**
Réveil VIA vous aide à programmer un réveil avant votre gare d’arrivée. Choisissez votre train VIA Rail Canada, votre gare et votre avance. L’app prend en charge les trajets de plusieurs jours et affiche les heures dans le fuseau de chaque gare. Les nouvelles estimations exploitables peuvent modifier le réveil enregistré. Le suivi en arrière-plan dépend des actualisations accordées par iOS. Application indépendante, sans affiliation officielle avec VIA Rail Canada.

**À tester**
Sélection du train et d’une gare intermédiaire; Halifax–Montréal; trajets transcontinentaux; date et fuseau du réveil; programmation, modification et arrêt; passage hors connexion; conservation de l’heure lorsque le suivi est indisponible; réouverture après fermeture; lisibilité du fond et de la progression.

**Notes pour l’équipe de revue**
Aucun compte, clé ni serveur à configurer. Internet est nécessaire au premier chargement des horaires et aux nouvelles estimations. La programmation utilise AlarmKit et nécessite une autorisation système. L’app n’accède pas à la position du voyageur. Les horaires proviennent du GTFS VIA et le suivi est téléchargé directement en HTTPS. En cas de données incohérentes, le réveil ne peut pas être programmé. Le réveil est local; les mises à jour opportunistes ne garantissent pas une adaptation continue.

## Avant ouverture aux testeurs

1. Renseigner les contacts de revue et d’assistance dans App Store Connect, sans inventer d’adresse. Publier la politique de confidentialité à une URL accessible : texte préparé dans `PRIVACY.md` et déjà accessible dans l’app.
2. Confirmer les conditions d’utilisation du suivi JSON. La photographie VIA a été retirée des sources actuelles; le bandeau et le fond utilisent une illustration générée. L’identité visuelle ne revendique aucun statut officiel.
3. Vérifier une vraie sonnerie sur iPhone : mode silencieux, Sommeil, écran verrouillé, absence de réseau et redémarrage; relever séparément l’heure programmée et l’heure entendue. Vérifier une adaptation sur de nouvelles estimations. Aucun succès de simulation ou de pilote fictif ne remplace cette preuve.
4. Lancer d’abord une bêta interne, puis ouvrir aux testeurs externes après les validations et le traitement Apple. Ne pas annoncer une adaptation permanente en arrière-plan.


## Installation après audit — 4 octobre 2026

À la demande du propriétaire, la version source 1.0 (7) a ensuite été compilée et signée en développement pour l’iPhone 16 Pro Justin, installée par le réseau et lancée avec succès (13 h 01, America/Toronto). L’installation est une mise à jour du même bundle identifier. Aucun envoi TestFlight et aucune sonnerie physique ne sont démontrés par cette opération. L’archive 1.0 (6) demeure antérieure aux corrections.


## Évolution vers 1.0 (9)

La version 1.0 (9) est compilée, signée en développement, installée et lancée sur l’iPhone 16 Pro. Le diagnostic local confirme qu’iOS a accepté une Activité en direct active ou périmée, avec les autorisations activées. La restriction de démarrage dans les seules sept dernières heures est retirée; une nouvelle carte peut démarrer après expiration à la réouverture de l’app. La durée active de huit heures imposée par iOS demeure. La confidentialité et les sources sont accessibles depuis la configuration du réveil; aucune mention de TestFlight ne figure dans l’interface. Aucun nouveau téléversement TestFlight n’a eu lieu.
