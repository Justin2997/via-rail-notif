# Réveil VIA · VIA Wake

Reposez-vous. Gardez votre gare en vue.

Un compagnon iPhone pour programmer un réveil avant votre gare d’arrivée sur les trains VIA Rail Canada. Choisissez votre train, votre gare et combien de minutes à l’avance vous souhaitez être réveillé.

*An iPhone companion that helps you set an alarm before your VIA Rail stop. Available in English and French.*

## Aperçu

<p align="center">
  <img src="docs/screenshots/home.png" width="250" alt="Accueil de Réveil VIA">
  <img src="docs/screenshots/trains.png" width="250" alt="Catalogue des trains VIA et leurs trajets">
  <img src="docs/screenshots/alarm.png" width="250" alt="Configuration de la gare et de l’avance du réveil">
</p>

Captures de l’app en français sur simulateur iPhone 17 Pro, iOS 26.1.

## Fonctionnalités

- Recherche de trains, choix de la gare et de l’avance du réveil.
- Alarme locale avec AlarmKit et suivi sur l’écran verrouillé avec les Activités en direct.
- Horaires et estimations VIA, trajets de plusieurs jours et fuseaux de chaque gare.
- Derniers horaires conservés pour la consultation hors connexion.
- Français et anglais, sans compte, publicité ni serveur à installer.

## Lancer le projet

**Xcode 26.1+ · Swift 6.2 · iOS 26+**

```sh
git clone https://github.com/Justin2997/via-rail-notif.git
cd via-rail-notif
open ios/ReveilVIA.xcodeproj
```

Sélectionnez le scheme `ReveilVIA` et un simulateur iPhone. Pour un appareil physique, choisissez votre équipe de signature pour l’app et l’extension. Aucune clé API nécessaire.

```sh
swift test --package-path ios
```

## Contribuer

Les issues et PR en français ou en anglais sont bienvenues. Consultez le [guide de contribution](CONTRIBUTING.md), la [politique de sécurité](SECURITY.md) et la [confidentialité](docs/PRIVACY.md).

## À savoir

L’app est en bêta. Les mises à jour en arrière-plan dépendent d’iOS; le suivi n’est pas continu. La sonnerie sur iPhone reste à valider avant distribution.

Application indépendante, sans affiliation officielle avec VIA Rail Canada. Horaires : VIA Rail Canada inc., sous [Licence du gouvernement ouvert – Canada](https://open.canada.ca/fr/licence-du-gouvernement-ouvert-canada). Les conditions d’utilisation du suivi JSON restent à confirmer. La licence du code reste à choisir; ZIPFoundation conserve sa [licence MIT](ios/App/ZIPFoundation-LICENSE.txt).
