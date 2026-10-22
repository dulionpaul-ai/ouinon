# Fonctionnement de Ouinon

## En deux mots

Chaque question est programmée en notification sur le téléphone, à son
heure et ses jours. La notification porte ses 2 ou 3 réponses en
boutons ; un appui enregistre la réponse dans la base SQLite du
téléphone, même appli fermée. L'appli lit ensuite cette base pour les
écrans et les stats. Rien ne part sur internet.

## Code (`lib/`)

| Dossier | Contenu |
|---|---|
| `models/question.dart` | Une question : texte, réponses (meilleure d'abord), heure, jours (masque lundi = bit 0), en pause ou non ; les 4 questions de départ. |
| `data/base.dart` | Base `ouinon.sqlite` : tables `questions` et `reponses` (une réponse par question et par jour, effacée avec sa question). |
| `data/suggestions.dart` | Suggestions de réponses de l'écran Nouvelle question (« Oui / Non », « Bien / Moyen / Pas bien » au départ), créées, modifiées ou supprimées par la personne, gardées dans les préférences du téléphone. |
| `data/notifications.dart` | Programmation des notifications, boutons, réponse depuis la notification (`reponseNotifArrierePlan`). |
| `utils/planification.dart` | Calcul pur de ce qu'il faut programmer (testé). |
| `utils/stats.dart` | Bilans, évolution, jour de la semaine, croisements et leurs phrases (testé). |
| `utils/jour.dart`, `utils/date_fr.dart` | Jours de calendrier (« 2026-10-22 ») et dates en français. |
| `screens/` | Accueil (onglets), Aujourd'hui, Stats, fiche d'une question, Mes questions, modification, Réglages. |
| `theme/app_theme.dart` | Style « Nuit ronde », toujours sombre (choix de Paul du 22/10/2026) : couleurs dans `Teintes`, polices Unbounded (titres) et Figtree (texte), embarquées dans `assets/fonts` (licence OFL). Réponses : citron, abricot, corail. |
| `widgets/choix_heure.dart` | Choix de l'heure : panneau du bas à deux roulettes (heures, minutes de 5 en 5) avec son bouton « Valider l'heure » ; il cache « Enregistrer » pendant le choix (retour de Paul : la fenêtre d'heure d'Android prêtait à confusion, et son bouton clavier ne servait à rien). |
| `widgets/rond.dart` | Briques rondes : carte, pastille, bouton rond et bouton +, grand titre (réduit plutôt que coupé), barre d'onglets flottante, choix en pilules, pilule à toucher, jour de la semaine en rond. Pas de puces Material (police et couleurs mal reprises). |

## Icône

- Logo n° 3 (choix de Paul du 22/10/2026) : rond coupé en deux, moitié
  citron, moitié corail, sur fond sombre. `tool/icones.py` (Python +
  Pillow) écrit toutes les icônes : Android classiques, adaptatives
  (avec monochrome pour Android 13) et iPhone.
- Petite icône des notifications : `drawable/ic_stat_ouinon.xml` (logo
  en blanc), gardée par `raw/keep.xml`. Écran de démarrage sombre.

## Notifications

- **Une par une, 14 jours d'avance.** Chaque notification porte la
  question et le jour dont elle parle (`id|2026-10-22`). Les jours déjà
  répondus et les heures passées sont sautés.
- **Reprogrammation complète** (les notifications en attente sont
  remplacées, celles déjà affichées restent) : à l'ouverture de l'appli,
  au retour dans l'appli, après chaque modification (regroupées sur
  0,6 s) et après chaque réponse depuis une notification.
- **Rappel « continuer »** : le lendemain du dernier jour programmé, à
  l'heure de la première question, « Ouvre l'appli pour continuer… ».
  Toujours repoussé tant que Paul répond.
- **Limites** : Android 500 alarmes par appli (on en garde 400) ;
  iPhone 64 notifications en attente (63 + le rappel). Avec beaucoup de
  questions, moins de jours sont programmés d'avance.
- **Heure « à quelques minutes près »** (`inexactAllowWhileIdle`) : pas
  d'autorisation spéciale « alarme exacte », que le Play Store réserve
  aux réveils.
- **Appli fermée** : Android lance un petit moteur Flutter
  d'arrière-plan qui appelle `reponseNotifArrierePlan` ; il ouvre la base,
  enregistre, reprogramme. L'appli relit la base à son retour au premier
  plan. Sur iPhone, les boutons sont déclarés d'avance (une catégorie par
  question, refaite à chaque reprogrammation) et apparaissent par appui
  long sur la notification ; `AppDelegate.swift` enregistre les modules
  pour le moteur d'arrière-plan.
- **Réponse dans l'appli** : la notification affichée de ce jour est
  retirée.
- Redémarrage du téléphone : les notifications en attente sont remises
  par le module (`ScheduledNotificationBootReceiver`).

## Stats

- **Bilan** : nombre de chaque réponse sur 7 jours, 30 jours ou depuis
  le début.
- **Évolution** : part de la meilleure réponse, semaine par semaine
  (12 semaines, lundi → dimanche).
- **Selon le jour** : part de la meilleure réponse par jour de la
  semaine.
- **Croisements** : pour deux questions A et B, part de la meilleure
  réponse de B les jours où A a sa meilleure réponse, contre les autres
  jours. Même jour (un seul sens par paire, le plus net) et lendemain
  (A un jour, B le jour suivant). Affiché seulement avec au moins 7 jours
  communs, 3 jours de chaque côté et 20 points d'écart. Phrase : « Les
  jours avec « Sport ? Oui » : « En forme ? Bien » 8 fois sur 10, contre
  2 fois sur 10 les autres jours. » Jamais de mot de cause.

## Vérifications et compilation

- Captures d'écran avec les vraies polices : `flutter test
  tool/captures_test.dart --update-goldens` (images dans `tool/captures/`,
  non commitées), dont un petit téléphone (360 de large) avec texte
  agrandi 1,3 fois : tout débordement fait échouer la capture.

- `flutter analyze` et `flutter test` (tests dans `test/`, base SQLite
  en mémoire, notifications simulées).
- GitHub Actions `verifications.yml` : format, analyse, tests à chaque
  envoi de code.
- APK de test fabriqués dans la session : `flutter build apk --release
  --split-per-abi --target-platform android-arm64`. Signés avec la clé de
  test du dépôt (`android/app/cle-test.jks`, pas un secret) : chaque APK
  s'installe par-dessus le précédent sans effacer les réponses.
- Dans une session Claude, Maven Central peut répondre « trop de
  demandes » (429) : un script Gradle propre à la session
  (`~/.gradle/init.d/miroir.gradle.kts`, hors du dépôt) remplace son
  adresse par le miroir Google
  `https://maven-central.storage-download.googleapis.com/maven2/`.
- Codemagic (`codemagic.yaml`, lancement à la main) : APK et TestFlight.
- Flutter 3.47.7 partout.
