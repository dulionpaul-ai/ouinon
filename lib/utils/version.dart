/// Version de l'appli, la même que `version:` dans `pubspec.yaml` (un test
/// le vérifie). Le nombre après le « + » est le numéro de l'APK de test,
/// affiché en bas des Réglages pour savoir lequel est installé.
const versionAppli = '1.0.0+16';

/// « Ouinon 1.0.0 · APK n° 10 ».
String versionLisible() {
  final morceaux = versionAppli.split('+');
  return 'Ouinon ${morceaux[0]} · APK n° ${morceaux[1]}';
}
