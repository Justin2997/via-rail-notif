# Revue avant publication — 4 octobre 2026

Cette revue prépare les sources du dépôt et distingue la publication du code de la distribution de l’application. Le dépôt GitHub est déjà public. Les corrections décrites ici sont locales tant qu’elles ne sont pas poussées et intégrées.

## Corrections

- Documentation de contribution et procédure de signalement privé de vulnérabilités.
- CI avec permissions en lecture seule, checkout épinglé à un commit vérifié, sans conservation des identifiants Git, délais maximum et annulation des exécutions obsolètes.
- Scan de secrets Gitleaks en CI : version et SHA-256 verrouillés, historique complet et résultats expurgés.
- Configuration Dependabot hebdomadaire pour SwiftPM et GitHub Actions.
- Exclusion des clés de signature, profils, archives, IPA et configurations locales; retrait du teamID personnel des options d’export partagées. Cet identifiant n’était pas une clé secrète.
- Photographie VIA retirée des sources actuelles, remplacée par l’illustration générée déjà intégrée. La photographie subsiste dans les anciens commits; aucune licence du projet ne s’applique à cette image.
- Politique de confidentialité complétée pour les connexions Apple Maps lorsque la carte est affichée.

Les actions sont épinglées selon les [recommandations GitHub](https://docs.github.com/en/actions/reference/security/secure-use). La configuration de mises à jour utilise les [écosystèmes pris en charge par Dependabot](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference).

## Vérifications locales

- Xcode 26.1.1 / Swift 6.2.1 : 52 tests Swift réussis, test réseau optionnel ignoré.
- Gitleaks 8.30.1, binaire vérifié par SHA-256 : aucun secret détecté dans les références Git locales (`git --log-opts=--all`, 16 commits accessibles, 12 commits avec différences analysées) ni dans les fichiers locaux (`dir`). Ce résultat reste limité aux règles du scanner et aux références disponibles; il ne couvre pas les forks, anciennes références supprimées, pièces jointes ou journaux GitHub.
- Compilation finale de l’app et de l’extension pour simulateur réussie après nettoyage, sans avertissement ni erreur dans le journal. `git diff --check` réussi. Aucun test de sonnerie sur appareil effectué dans cette revue.

Les limites de téléchargement, décompression ZIP en mémoire, CRC, parsing CSV, fraîcheur et cohérence des données ainsi que la reprise des alarmes sont déjà implémentés et couverts par les tests existants. Cette revue ne garantit pas l’absence de tout défaut.

## Réglages GitHub

Vérifiés sur `Justin2997/via-rail-notif` : détection des secrets et protection au push activées. Signalement privé des vulnérabilités et alertes/mises à jour de sécurité Dependabot activés pendant cette revue. La branche `main` n’a pas de protection observée : avant d’accueillir des contributions, configurer les vérifications CI obligatoires et interdire les force-push sur la branche principale. Les nouveaux workflows et la configuration Dependabot nécessitent encore leur intégration au dépôt distant.

## Décisions et validations restantes

1. Choisir la licence du code et ajouter `LICENSE`. Sans cette décision, ne pas présenter les sources comme librement réutilisables. Ne pas étendre la licence aux données/marques VIA ou à la photographie historique. Si l’objectif est de retirer également cette photographie de tout l’historique publié, décider d’une purge coordonnée : aucune réécriture Git n’a été faite ici.
2. Pour la sortie de l’app : confirmer les conditions d’utilisation du suivi JSON VIA, renseigner le contact d’assistance et publier la politique de confidentialité.
3. Refaire la validation sur iPhone avec la version distribuée : sonnerie, silencieux/Sommeil, réseau perdu, fermeture et redémarrage, et affichage de l’Activité en direct. Les tests Swift et le build simulateur ne prouvent pas ces comportements.
4. Finaliser contrat Apple, signature de distribution et traitement TestFlight/App Store Connect, comme décrit dans [le suivi de distribution](TESTFLIGHT_RELEASE.md).
