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
| `data/base.dart` | Base `ouinon.sqlite` : tables `questions` (rendues dans l'ordre de la journée : heure, puis création) et `reponses` (une réponse par question et par jour, effacée avec sa question). Changement du nombre de réponses avec conversion de l'historique (`enregistreAvecNombre`). |
| `data/suggestions.dart` | Suggestions de réponses de l'écran Nouvelle question (« Oui / Non », « Bien / Moyen / Pas bien » au départ), créées, modifiées ou supprimées par la personne, gardées dans les préférences du téléphone. |
| `data/notifications.dart` | Programmation des notifications, boutons, réponse depuis la notification (`reponseNotifArrierePlan`). |
| `utils/planification.dart` | Calcul pur de ce qu'il faut programmer (testé). |
| `utils/stats.dart` | Bilans, évolution, jour de la semaine, liens automatiques, croisement libre de deux questions (`croisement`) (testé). |
| `utils/jour.dart`, `utils/date_fr.dart` | Jours de calendrier (« 2026-10-22 ») et dates en français. |
| `screens/` | Accueil (onglets), Aujourd'hui (une page par jour, on glisse vers la droite pour la veille, jamais après aujourd'hui), Stats (croiseur libre de deux questions, liens les plus nets en barres « avec / sans », une ligne par question), fiche d'une question, Questions (par heure, sans rangement à la main), modification, Réglages. |
| `theme/app_theme.dart` | Style « Nuit ronde », toujours sombre (choix de Paul du 22/10/2026) : couleurs dans `Teintes`, polices Unbounded (titres) et Figtree (texte), embarquées dans `assets/fonts` (licence OFL). Réponses : citron, abricot, corail. |
| `widgets/rond.dart` | Briques rondes : carte, pastille, bouton rond et bouton +, grand titre (réduit plutôt que coupé), barre d'onglets flottante, choix en pilules, pilule à toucher, jour de la semaine en rond. Pas de puces Material (police et couleurs mal reprises). |

## Icône

- Logo n° 3 (choix de Paul du 22/10/2026) : rond coupé en deux, moitié
  citron, moitié corail, sur fond sombre. `tool/icones.py` (Python +
  Pillow) écrit toutes les icônes : Android classiques, adaptatives
  (avec monochrome pour Android 13) et iPhone. Taille du logo réglée par
  `TAILLE` (0,95 : réduit de 5 % à la demande de Paul).
- Petite icône des notifications : `drawable/ic_stat_ouinon.xml`, en
  blanc : moitié gauche pleine (oui), moitié droite en contour (non),
  gardée par `raw/keep.xml`. Pas de couleur de notification (Samsung
  assombrissait le citron en vert olive). Écran de démarrage sombre.

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
- **Moment envoyé à Android en temps universel** (`instantProgramme`) :
  l'heure locale est calculée avec l'horloge du téléphone, puis passée
  en UTC. Plus de fuseau détecté par l'appli (une question de 7 h 01
  est arrivée à 8 h 01 chez Paul le 23/10/2026).
- **Heure précise** (`exactAllowWhileIdle`) quand la personne a accordé
  « Alarmes et rappels » (`SCHEDULE_EXACT_ALARM`, demandée une fois au
  démarrage et dans les Réglages). Sinon heure approximative
  (`inexactAllowWhileIdle`) : Android peut alors décaler une
  notification d'environ les trois quarts du temps qui la sépare de sa
  programmation, donc de plusieurs heures pour une notification
  programmée des jours à l'avance. Constaté le 22/10/2026 (aucune
  notification le soir chez Paul). On n'utilise pas `USE_EXACT_ALARM`,
  réservé par le Play Store aux réveils et agendas.
- **Réglages** : état des autorisations, prochaine question prévue,
  nombre de notifications en attente sur le téléphone.
- **Appli fermée** : Android lance un petit moteur Flutter
  d'arrière-plan qui appelle `reponseNotifArrierePlan` ; il ouvre la base,
  enregistre, reprogramme. L'appli relit la base à son retour au premier
  plan. Sur iPhone, les boutons sont déclarés d'avance (une catégorie par
  question, refaite à chaque reprogrammation) et apparaissent par appui
  long sur la notification ; `AppDelegate.swift` enregistre les modules
  pour le moteur d'arrière-plan.
- **Contenu** : titre = la question, sans texte dessous (la date ne
  servait à rien) ; le jour concerné est dans le contenu caché.
- **Ordre des boutons** : la moins bonne réponse à gauche, la meilleure
  à droite (choix de Paul du 22/10/2026), dans la notification comme
  dans l'appli (boutons de la page Jour, barre de bilan, pastilles de la
  liste). Les identifiants ne changent pas (« r0 » = meilleure). Les
  listes verticales (saisie des réponses, légende) gardent la meilleure
  en haut.
- **Réponse dans l'appli** : la notification affichée de ce jour est
  retirée.
- Redémarrage du téléphone : les notifications en attente sont remises
  par le module (`ScheduledNotificationBootReceiver`).

## Stats

- **Page Stats** (refaite le 23/10/2026, Paul s'intéresse surtout aux
  croisements) : en haut, croiser deux questions au choix (« Quand »,
  « Regarder », même jour ou lendemain) : une barre des réponses de la
  seconde pour chaque réponse de la première ; puis les liens les plus
  nets en cartes (pastilles, barres « avec » et « sans ») ; toucher un
  lien l'ouvre dans le croiseur ; enfin une ligne par question (barre
  des 30 jours). Peu de texte.

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

- Outils d'une session neuve : `bash tool/installer_outils.sh` (Flutter
  3.47.7, SDK Android 36, miroir Maven). Étapes complètes dans
  `docs/reprendre_le_projet.md`.

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
