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
- APK n° 38 (2.0.0+38) envoyé le 25/11/2026.
- **26/11/2026 (2.0.0+39)** : maquette validée et codée : la phrase
  « Je deviens quelqu'un qui… », la semaine, 7 points par question, le
  « pourquoi » dans la notification, les tâches « tous les N jours ».
  Voir `docs/cahier.md`. Habitudes proposées par le coach :
  `docs/coaching/habitudes.md`. APK n° 39 (thème HUD) puis n° 40 (retour au
  minimaliste) envoyés le 26/11/2026. 
- **26/11/2026 : retour à la version minimaliste** (2.0.0+40, Paul n'a
  pas aimé le thème HUD de l'APK n° 39), réglages sans APK (voir `CLAUDE.md`,
  « Réglable sans APK »). En attente de Paul : créer le dépôt public
  `ouinon-reglages` (vide) et passer `ouinon` en privé ; Claude y pousse
  ensuite `reglages/reglages.json` (add_repo). Sans ce fichier, l'appli
  garde le thème par défaut.
- **26/11/2026 : copie en ligne** dans Supabase (projet « Ouinon »,
  Paris), version 2.0.0+41, APK pas encore fabriqué (**toujours
  demander à Paul avant**). Chaque changement part en ligne ; à
  l'ouverture, tout est renvoyé ; téléphone vide → tout revient. Rien
  n'est supprimé en ligne, sauf une suppression faite dans l'appli.

## Le code (`lib/`)

| Fichier | Rôle |
|---|---|
| `main.dart` | Lancement, thème, français. |
| `screens/questions_screen.dart` | La liste : la phrase, la semaine, les habitudes (heure, fréquence, 7 barres) ; pas de réponses ici. Bilan copié, alerte si l'heure précise n'est pas autorisée. |
| `screens/question_screen.dart` | L'écran clé : créer, modifier, supprimer une habitude, avec l'aperçu de sa notification. |
| `data/base.dart` | Base SQLite `ouinon.sqlite` (version 9) : `questions` (avec `pourquoi` et `intervalle`), `reponses`, `reglages` (la phrase). |
| `utils/frequence.dart` | Quand une question est posée (`poseeLe` : jours, et intervalle pour une tâche), le compte de la semaine, les fréquences en français. |
| `data/supabase.dart` | La copie en ligne (API REST de Supabase). |
| `data/notifications.dart` | Notifications à boutons, réponse enregistrée même appli fermée, tout reprogrammé à chaque changement. |
| `utils/planification.dart` | Quoi programmer : 14 jours d'avance, rappel « ouvre l'appli » au-delà. |
| `utils/bilan.dart` | Le bilan des 7 derniers jours pour le coach. |
| `utils/jour.dart` | Jours, heures et dates en français. |
| `theme/app_theme.dart` | Le style HUD, d'après l'apparence en cours. |
| `models/apparence.dart` | Tout ce qui se règle sans APK, avec les valeurs par défaut ; lecture du fichier `reglages.json`. |
| `data/apparence_distante.dart` | Télécharge le fichier public de réglages, le garde dans la base. |
| `data/images_notif.dart` | Les deux images des notifications (série, 7 derniers jours). |

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
2. `bash tool/cle_supabase.sh` (clé Supabase dans `supabase.json`, non
   commité ; **sans elle, pas de copie en ligne**), puis
   `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define-from-file=supabase.json`
3. Envoyer `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Clé de test stable (`android/app/cle-test.jks`) : chaque APK s'installe
par-dessus le précédent sans effacer les réponses.

- Icônes : `python3 tool/icones.py`.
- iPhone : `codemagic.yaml` prêt, jamais lancé.
