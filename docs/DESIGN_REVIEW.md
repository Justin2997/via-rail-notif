# Revue visuelle — Réveil VIA 0.3

23 septembre 2026. Revue effectuée par Codex avec le skill **Designly visual-qa**, sur les captures réelles de l’application exécutée dans le simulateur iPhone 17 Pro, iOS 26.1. Ce n’est pas une évaluation par un intervenant externe.

## Résultat

Le périmètre visuel inspecté est accepté après corrections : deux destinations distinctes, données VIA réelles, action d’activation explicite et lisibilité en modes clair/sombre. Évaluation qualitative selon la grille Designly : **94,64/100**, pondération égale des catégories applicables, seuil de 92 atteint et planchers respectés. [Grille complète](evidence/designly-review-0.3.json). Cette note ne constitue pas une certification d’accessibilité ou de fiabilité de sonnerie.

## Défauts trouvés et corrigés

| Défaut observé | Effet | Correction ciblée |
| --- | --- | --- |
| Vert de suivi et texte secondaire trop pâles sur fond clair | Lecture difficile des états et des horaires | Couleurs adaptatives spécifiques aux deux apparences |
| Séparateurs des lignes de train décalés vers la droite | Groupement visuel ambigu | Alignement sur le bord du contenu |
| Libellé des minutes et raccourci « 15 min » coupés aux grandes tailles | Formulaire irrégulier et commande moins lisible | Libellé court, raccourcis verticaux aux tailles d’accessibilité |
| Valeurs des heures souhaitées trop atténuées | Information principale visuellement secondaire | Couleur primaire pour les heures de réveil et d’arrivée |

Le logo existant, les calculs d’alarme et les identités des trains ne sont pas remplacés pour obtenir les captures. Aucun réveil n’a été activé pendant cette revue.

## Contrôles sur le rendu final

- Hiérarchie immédiate : titre de page, train/route puis horaires sur le dashboard; trajet, avance puis activation dans Réveil. Les onglets restent identifiables par icône et texte.
- Données : 46 trains réellement chargés; train 41 Ottawa → Toronto ouvert, puis sélectionné dans le formulaire. Réception datée et distinction « Estimée » / « Prévue » visibles. Les dessertes incohérentes portent un avertissement, sans estimation inventée.
- Typographie et contours : captures examinées à leur taille d’affichage; aucun texte essentiel tronqué dans les états capturés. Les listes défilent derrière la barre native iOS; les éléments inférieurs restent accessibles au défilement.
- Dynamic Type : `large` et `accessibility-medium` inspectés. Les statuts et horaires des trains ainsi que les raccourcis du réveil passent à une disposition verticale. Le bouton d’activation reste entièrement lisible après défilement.
- Contrastes calculés à partir des couleurs sRGB des assets : bouton clair 6,70:1, bouton sombre 11,54:1, suivi vert clair 5,91:1, suivi vert sombre 10,24:1, texte secondaire clair 7,00:1 et sombre 8,63:1 sur les fonds de référence blanc / #1C1C1E. Les couleurs natives translucides ne sont pas couvertes par ces mesures.
- Fidélité : nom et icône existants conservés, français cohérent, aucune apparence d’affiliation officielle ajoutée. Pas d’illustration décorative, de personnage ou de texte généré incorporé aux captures.

## Captures inspectées

Les captures du simulateur ont été examinées pendant la revue, mais les images PNG ne sont pas incluses dans cette PR. La grille et les résultats détaillés restent dans [le rapport JSON](evidence/designly-review-0.3.json). L’heure 02:30 de la barre système du simulateur était forcée et ne représentait pas l’heure des données; les réglages de taille et d’apparence ont été restaurés après vérification.

## Limites de la revue

VoiceOver n’a pas été validé : la capture de l’arbre d’accessibilité par l’outil ne se stabilisait pas. La navigation a été contrôlée par interactions et captures. Un audit VoiceOver manuel et les autres tailles/appareils restent à réaliser. Les seuils de fraîcheur des données sont vérifiés séparément par les tests Swift. L’installation et le lancement physiques sont prouvés dans le manifest de déploiement; la sonnerie réelle et la fréquence des mises à jour en veille ne le sont pas.
