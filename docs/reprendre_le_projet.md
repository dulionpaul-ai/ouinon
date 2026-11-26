# Reprendre le projet Ouinon

À lire en premier, avec `CLAUDE.md`. Mis à jour le 25/11/2026.

## Où on en est

- **25/11/2026 : repartie de zéro**, version 2.0.0+38. Un seul écran :
  mes questions (avec les réponses du jour), « + » pour en créer, le
  bouton en haut copie le bilan pour le coach. Un formulaire pour créer
  ou modifier une question.
- La nouvelle appli reprend la base du téléphone : les questions et les
  réponses de Paul sont gardées (les questions en pause passent sans
  jours, les réponses de test sont effacées).
- APK n° 38 (2.0.0+38) envoyé le 25/11/2026. Prochain : 2.0.0+39,
  **toujours demander à Paul avant**.
- **26/11/2026 (2.0.0+39)** : maquette validée et codée : la phrase
  « Je deviens quelqu'un qui… », la semaine, 7 points par question, le
  « pourquoi » dans la notification, les tâches « tous les N jours ».
  Voir `docs/cahier.md`. Habitudes proposées par le coach :
  `docs/coaching/habitudes.md`.

## Le code (`lib/`)

| Fichier | Rôle |
|---|---|
| `main.dart` | Lancement, thème, français. |
| `screens/questions_screen.dart` | L'écran unique : la phrase, la semaine, les questions du jour (7 points, réponses, pastille), « Pas aujourd'hui » et « En pause » repliés, bilan copié, alerte si l'heure précise n'est pas autorisée. |
| `screens/question_screen.dart` | Créer, modifier, supprimer une question. |
| `data/base.dart` | Base SQLite `ouinon.sqlite` (version 9) : `questions` (avec `pourquoi` et `intervalle`), `reponses`, `reglages` (la phrase). |
| `utils/frequence.dart` | Quand une question est posée (`poseeLe` : jours, et intervalle pour une tâche), le compte de la semaine, les fréquences en français. |
| `data/notifications.dart` | Notifications à boutons, réponse enregistrée même appli fermée, tout reprogrammé à chaque changement. |
| `utils/planification.dart` | Quoi programmer : 14 jours d'avance, rappel « ouvre l'appli » au-delà. |
| `utils/bilan.dart` | Le bilan des 7 derniers jours pour le coach. |
| `utils/jour.dart` | Jours, heures et dates en français. |
| `theme/app_theme.dart` | Le style. |

## Installer les outils (session neuve)

```
bash tool/installer_outils.sh
export ANDROID_HOME=/home/user/outils/android
export PATH=/home/user/outils/flutter/bin:$PATH
```

Pas d'émulateur (pas de KVM) : les vrais essais se font sur le téléphone
de Paul (Samsung, texte agrandi).

## Vérifier avant d'envoyer

```
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter test tool/captures_test.dart --update-goldens   # images dans tool/captures/
```

GitHub refait format, analyse et tests à chaque envoi sur `main`.

## Fabriquer un APK (toujours avec l'accord de Paul)

1. Monter le numéro après le `+` dans `pubspec.yaml`.
2. `flutter build apk --release --split-per-abi --target-platform android-arm64`
3. Envoyer `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Clé de test stable (`android/app/cle-test.jks`) : chaque APK s'installe
par-dessus le précédent sans effacer les réponses.

- Icônes : `python3 tool/icones.py`.
- iPhone : `codemagic.yaml` prêt, jamais lancé.
