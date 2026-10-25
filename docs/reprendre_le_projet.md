# Reprendre le projet Ouinon

À lire en premier dans une nouvelle session Claude (avec `CLAUDE.md`).
Mis à jour le 22/10/2026.

## En une minute

- **Ouinon** : appli Android (iPhone plus tard) de suivi de vie. Chaque
  question (« Sport ? », « En forme ? »…) arrive en notification à son
  heure ; on répond avec 2 ou 3 boutons, sans ouvrir l'appli. L'appli
  garde les réponses sur le téléphone et en tire des stats, dont des
  croisements entre questions.
- **Où on en est** : V1 codée et testée en automatique (82 tests).
  Paul teste les APK sur son téléphone Android (Samsung, mode sombre,
  texte agrandi) et envoie des retours en captures d'écran. Dernier APK
  envoyé : **n° 10** (version 1.0.0+10, 23/10/2026) : stats refaites
  en graphiques animés, liens trouvés seuls, bouton « Ajouter 6 mois de
  test » dans les Réglages. **APK n° 11** (1.0.0+11, 24/10/2026) :
  planning et liste « À faire » en 4 cases d'Eisenhower, « Remplir ma
  journée », deux notifications par chose. **APK n° 12** (1.0.0+12) :
  onglet « À faire » calqué sur le tableau blanc de Paul. Depuis, dans le
  code : **grande simplification** (3 onglets Aujourd'hui · To-do ·
  Stats, « Préparer demain » en 2 étapes ; voir `docs/historique.md`),
  version déjà à 1.0.0+13 pour l'APK n° 13, pas encore fabriqué.
  Toujours demander à Paul avant de fabriquer un APK. Les boutons de
  notification marchent appli fermée (confirmé par Paul).
- **Le code est sur `main`** du dépôt `dulionpaul-ai/ouinon` (voir
  « Branche »).

## Paul

- Ne code pas, parle souvent à la voix depuis son téléphone : réponses
  courtes, en français, sans jargon, tutoiement.
- Veut voir avant de valider : propositions visuelles (pages de
  maquettes), captures d'écran, puis APK.
- Envoie des captures de son téléphone : ce qu'il voit en vrai (gros
  texte, mode sombre) fait foi.
- Rien sur les stores sans son accord explicite.
- **Toujours lui demander avant de fabriquer un APK.**

## Les choix de Paul à respecter

Détail dans `docs/revue_produit.md`. Les plus importants :

- Nom affiché **Ouinon** (O majuscule, tout attaché). Identifiant
  `fr.ouinon.app`.
- **Toujours sombre**, style rond « Nuit ronde » : titres en Unbounded,
  texte en Figtree, pilules, réponses citron (meilleure), abricot
  (milieu), corail (moins bonne). Il a refusé un premier style jugé
  « appli d'IA » : éviter le banal (Inter, cartes grises, vert/rouge
  standard).
- **Ordre des réponses de gauche à droite : la moins bonne à gauche, la
  meilleure à droite**, partout (notification, boutons, barres). Dans
  les listes verticales, la meilleure en haut.
- Logo n° 3 : rond coupé en deux, moitié citron, moitié corail.
- Pas de relance de notification ; pas d'objectifs ni de note écrite
  pour l'instant ; sauvegarde plus tard. Séries oui (23/10/2026).
- Stats en **graphiques** (23/10/2026) : l'appli trouve les liens toute
  seule (« je veux que l'outil les trouve tout seul »), courbes à
  comparer, décalées d'un jour au besoin, nuage de points, anneaux,
  barres, grille ; modernes et animés. La « question principale » est
  abandonnée. Bilan du dimanche à 20 h.
- **To-do et journée** (simplifié le 25/10/2026, il trouvait l'appli
  trop chargée) : une to-do (temps de chaque chose, Important et Urgent
  sur une ligne, tri automatique) ; chaque soir « Préparer demain » :
  choisir (jauge de temps libre), puis caser dans la journée (glisser
  ou « Caser pour moi »). Une chose casée prend une heure et ses deux
  notifications. Créneaux fixes grisés (« Enfants 17 h – 23 h »).
  **Garder l'appli simple** : pas de nouveaux boutons ou bandeaux sans
  nécessité. Deux notifications par chose : au début
  (« C'est l'heure », Reporter), à la fin (« C'est fait ? » : Pas fait ·
  Reporter · Fait) ; reporter = une heure plus tard. Seulement
  aujourd'hui et demain pour l'instant. « Remplir ma journée » est une
  première version à améliorer avec lui.
- Liens dès 14 jours communs et 30 % de ressemblance, présentés comme
  des coïncidences, jamais des causes.
- Heure précise des notifications : autorisation « Alarmes et rappels »
  (sans elle, retards de plusieurs heures).
- Cadran d'heure d'Android gardé (il l'aime), sans bouton clavier, et
  « Enregistrer » caché pendant le choix.

## Pages de maquettes (claude.ai, privées à Paul)

- Styles : https://claude.ai/artifact/8wYzPghoUihjK5CGqjZQSg
  (A à C refusés ; D Bulles + F Nuit ronde retenus).
- Logo : https://claude.ai/artifact/8JC7nnJjfsTQoX79W3FXtW (n° 3 retenu).

## Installer les outils dans une session neuve

Le conteneur est vide à chaque session :

```
bash tool/installer_outils.sh
export ANDROID_HOME=/home/user/outils/android
export PATH=/home/user/outils/flutter/bin:$PATH
flutter analyze && flutter test
```

Le script installe Flutter 3.47.7, le SDK Android 36 et un miroir Maven
(Maven Central répond souvent « 429, trop de demandes » depuis les
sessions). Pas d'émulateur possible (pas de KVM) : les vrais essais se
font sur le téléphone de Paul.

## Vérifier et fabriquer

- Format, analyse, tests : `dart format lib test tool`,
  `flutter analyze`, `flutter test`. GitHub Actions refait les trois à
  chaque envoi (`.github/workflows/verifications.yml`).
- **Captures avec les vraies polices** (à regarder avant chaque APK) :
  `flutter test tool/captures_test.dart --update-goldens`, images dans
  `tool/captures/` (non commitées). Elles couvrent aussi un petit
  téléphone avec texte agrandi : un débordement fait échouer la capture.
- **APK de test** : monter le numéro après le `+` dans `pubspec.yaml`
  (`version: 1.0.0+10` pour le prochain, **et la même valeur dans
  `lib/utils/version.dart`**, vérifiée par un test ; le numéro d'APK
  s'affiche en bas des Réglages), puis
  `flutter build apk --release --split-per-abi --target-platform android-arm64`
  → `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (≈ 10 Mo),
  à envoyer à Paul. Clé de test stable (`android/app/cle-test.jks`) :
  chaque APK s'installe par-dessus le précédent sans effacer les
  réponses.
- **Icônes** : `python3 tool/icones.py` (Pillow) régénère toutes les
  icônes Android et iPhone depuis le logo.
- iPhone : `codemagic.yaml` prêt (TestFlight via la clé App Store
  Connect de Wavents), jamais lancé.

## Comment c'est construit

Tout est dans `docs/fonctionnement.md`. L'essentiel :

- `lib/data/base.dart` : SQLite (`questions`, `reponses`).
- `lib/data/notifications.dart` : notifications programmées une par une
  sur 14 jours, boutons de réponse, réponse enregistrée appli fermée
  (moteur d'arrière-plan), rappel « continuer ».
- `lib/utils/planification.dart`, `lib/utils/stats.dart`,
  `lib/utils/courbes.dart` : calculs purs et testés.
- `lib/widgets/graphiques.dart` : graphiques animés (module fl_chart).
- `lib/data/donnees_test.dart` : 6 mois de réponses et de planning de test.
- Planning et liste : `lib/models/a_faire.dart`, `lib/models/tache.dart`,
  `lib/utils/planning.dart`, `lib/utils/remplissage.dart`,
  `lib/screens/edition_a_faire_screen.dart`, `lib/widgets/cases.dart`,
  `lib/models/creneau.dart`, `lib/screens/edition_creneau_screen.dart`,
  `lib/widgets/grille_journee.dart` (la journée, glisser-déposer),
  `lib/screens/planning_screen.dart`, `lib/screens/edition_tache_screen.dart`,
  `lib/widgets/bloc_tache.dart`.
- `lib/screens/` : Jour (pages qui glissent), Stats, fiche d'une
  question, Questions, Nouvelle question / Modifier, Réglages.
- `lib/theme/app_theme.dart` + `lib/widgets/rond.dart` : le style.

## Branche

Tout est sur `main` depuis le 22/10/2026 (accord de Paul) : partir de
`main` et y pousser directement. La première session travaillait sur
`ccr-a5a20ad5-u5tk4c`, versée telle quelle dans `main`.

## Prochaines étapes

Voir `docs/plan_action.md`. En bref :

1. Vérifier avec Paul que les questions arrivent à l'heure (APK n° 8
   et suivants), que le premier bilan du dimanche arrive bien, et
   recueillir son avis sur les stats en graphiques (essayer avec
   « Ajouter 6 mois de test », puis « Effacer les réponses de test »).
   Heure : heure précise autorisée dans les Réglages, plus de décalage
   d'une heure. Si elles restent en
   retard : piste suivante, l'économie de batterie de Samsung.
2. Quelques semaines de vraies réponses, puis ajuster les stats.
3. Plus tard, avec son accord : iPhone, sauvegarde, stores.
