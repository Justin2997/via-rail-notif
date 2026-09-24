# Revue de simplicité — Réveil VIA

23 septembre 2026

## Nettoyage effectué

- Le tableau de bord n’a plus de bouton « Actualiser » : le geste iOS pour tirer afin d’actualiser est conservé.
- La page « À propos » et son bouton ont été retirés du parcours quotidien. Ils exposaient surtout des états de prototype et des détails de rafraîchissement en arrière-plan.
- L’état des données est réduit à une seule ligne datée (« Mis à jour à… » ou « Actualisation… »). La date du train est présentée en français plutôt qu’au format ISO.
- Le formulaire du réveil a perdu un bloc explicatif répété. Il conserve une seule note sur le moment où l’alarme est enregistrée et le maintien d’un réveil existant.
- Les estimations, les heures prévues, la fraîcheur des données et les conflits de desserte restent visibles : ils changent la décision de l’usager et ne sont pas de la décoration.

## Vérifications

- Compilation, installation et lancement réussis sur le simulateur iPhone 17 Pro (iOS 26.1). L’inspection du premier écran a confirmé l’absence de bouton d’information et de commande d’actualisation distincte.
- `swift test --package-path ios` : 31 tests réussis; le test réseau optionnel a été ignoré.
- `git diff --check` sur les fichiers touchés : réussi.

## Limite de cette revue

Le vrai iPhone 16 Pro est jumelé et l’app 0.3.2 y est installée, mais la session de Recopie de l’iPhone était expirée. Les commandes Xcode disponibles dans cette session ne contrôlent que le simulateur. Je n’ai donc pas pu toucher les écrans de l’iPhone; cette compilation n’a pas été installée sur l’appareil. Le résultat physique doit être vérifié après réouverture de Recopie de l’iPhone ou par Justin directement sur l’appareil.

## Tentative de déploiement — 23 septembre 2026

La compilation pour l’iPhone a été tentée avec l’équipe `PKUX85TGS8`, sans installation. Xcode ne trouve aucun compte connecté pour cette équipe ni de profils de développement pour les deux identifiants de l’app (application et extension Activité en direct). Les profils locaux et anciens produits signés sont absents. L’app déjà installée sur l’iPhone n’a pas été remplacée.
