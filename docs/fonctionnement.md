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
| `models/tache.dart` | Une chose prévue du planning : jour, début et durée (minutes), texte, réponse (`fait` = 0, `pasFait` = 1, ou nulle), nombre de reports, marque « test ». |
| `data/base.dart` | Base `ouinon.sqlite` (version 2) : tables `questions` (rendues dans l'ordre de la journée : heure, puis création), `reponses` (une réponse par question et par jour, effacée avec sa question) et `planning` (ajoutée en version 2, par mise à jour de la base). Reporter une chose (`reporteTache`), raccourcis (`habitudes`). Changement du nombre de réponses avec conversion de l'historique (`enregistreAvecNombre`). |
| `data/preferences.dart` | Choix gardés sur le téléphone : bilan du dimanche, rappel du soir et son heure (activés par défaut, 21 h 30). |
| `data/suggestions.dart` | Suggestions de réponses de l'écran Nouvelle question (« Oui / Non », « Bien / Moyen / Pas bien » au départ), créées, modifiées ou supprimées par la personne, gardées dans les préférences du téléphone. |
| `data/notifications.dart` | Programmation des notifications (questions, choses prévues, rappel du soir, bilan), boutons, réponse depuis la notification (`reponseNotifArrierePlan`). |
| `utils/planning.dart` | Calculs du planning (testés) : rappels à programmer, textes, part faite, planning vu comme une question (`questionPlanning`), stats (moment, jour, charge, plus reportées), horaires qui se croisent, ligne du bilan. |
| `utils/planification.dart` | Calcul pur de ce qu'il faut programmer (testé). |
| `utils/stats.dart` | Bilans, jour de la semaine, séries (`serie`), bilan de la semaine (`bilanSemaine`) (testé). |
| `utils/courbes.dart` | Notes de 0 à 1, moyenne glissante sur 7 jours, ressemblance de deux courbes avec décalage, découvertes, points par semaine, droite de tendance (testé). |
| `data/donnees_test.dart` | 6 mois de réponses et de planning de test (marqués « test » dans la base, effaçables d'un coup ; jamais sur un jour déjà planifié). |
| `widgets/bloc_tache.dart` | Une chose prévue en bloc horaire (heures à gauche, liseré à la couleur de la réponse, boutons « Pas fait / Fait »), temps libre entre deux. |
| `widgets/graphiques.dart` | Graphiques (module `fl_chart` 1.2.0) : courbes, anneau, barres, nuage de points, grille de 6 mois, carte des liens ; animation quand on s'arrête dessus (`AnimeQuandVisible`). |
| `utils/jour.dart`, `utils/date_fr.dart` | Jours de calendrier (« 2026-10-22 ») et dates en français. |
| `screens/` | Accueil (4 onglets : Jour, Demain, Stats, Questions), Demain (planning d'aujourd'hui ou de demain, « Pas fait aujourd'hui » à remettre demain), À prévoir (ajout ou modification d'une chose), Aujourd'hui (une page par jour, on glisse vers la droite pour la veille, jamais après aujourd'hui), Stats (découvertes, comparateur de deux courbes, carte des liens, une carte par question), fiche d'une question, Questions (par heure, sans rangement à la main), modification, Réglages. |
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

- **Séries** : jours d'affilée avec la meilleure réponse, seulement les
  jours où la question revient ; aujourd'hui sans réponse ne casse pas
  la série. Flamme et nombre sur la page Jour dès 2 jours ; série en
  cours et record sur la fiche d'une question.
- **Bilan du dimanche** : notification à 20 h (`idBilanDimanche` = 2,
  canal « Bilan de la semaine ») : chaque question (« Sport ? Oui : 4
  jours sur 6 »), la meilleure série (dès 3 jours), la découverte la
  plus forte. Son texte est recalculé à chaque
  reprogrammation (donc après chaque réponse). Désactivable dans les
  Réglages.

- **Notes et courbes** : chaque réponse devient une note (meilleure =
  1, moins bonne = 0, milieu = 0,5) ; la courbe est la moyenne sur 7
  jours (le jour et les 6 d'avant).
- **Ressemblance** de deux questions : corrélation des notes jour par
  jour (de −100 % à 100 %), la seconde regardée 0 à 3 jours après la
  première. Il faut 14 jours communs. Pour chaque paire, on garde le
  décalage le plus net (à égalité, le plus petit, et un plus grand
  doit faire au moins 2 points de mieux). **Découverte** dès 30 %,
  « lien fort » dès 50 % ; négative = « à l'inverse » (la courbe est
  alors retournée pour la comparaison). Jamais de mot de cause.
- **Page Stats** (refaite en graphiques le 23/10/2026, Paul : « je veux
  que l'outil trouve les liens tout seul ») :
  - Découvertes : les 4 plus fortes, deux courbes superposées sur 3
    mois (la seconde décalée), touche pour ouvrir le comparateur.
  - Comparer deux courbes : deux questions au choix, décalage de 0 à 3
    jours, 1 / 3 / 6 mois, grand pourcentage de ressemblance, courbes,
    puis « Semaine par semaine » (nuage : un point par semaine, droite
    de tendance).
  - Tous les liens : tableau de toutes les paires (citron = même
    courbe, corail = à l'inverse, plus vif = plus net) ; une case ouvre
    le comparateur.
  - Tes questions : anneau (part de la meilleure réponse sur 30 jours),
    petite courbe, flamme de la série.
  - Sans assez de réponses : explication (« après 14 jours »).
- **Fiche d'une question** : séries, anneau et nombres (7 jours, 30
  jours, tout), la courbe (1 / 3 / 6 mois), selon le jour (barres),
  6 mois en un coup d'œil (une case par jour), calendrier modifiable.
- **Animations** : chaque graphique se dessine (courbe de gauche à
  droite, anneau qui tourne, barres qui montent, points qui
  apparaissent) quand le défilement s'arrête et qu'il est visible aux
  trois cinquièmes ; il se rejoue quand on revient dessus.
- **Données de test** : Réglages → « Ajouter 6 mois de test » (une
  « énergie » cachée, certaines questions avec un jour de retard, une à
  l'inverse ; toujours le même tirage). Elles ne remplacent jamais une
  vraie réponse et s'effacent d'un coup (« Effacer les réponses de
  test »).

## Planning

- **Une chose prévue** : jour (aujourd'hui ou demain), début, durée
  (15 min à 3 h), texte (40 caractères). Pas de répétition : chaque
  soir, on prépare le lendemain.
- **Rappel à l'heure pile** (canal « Planning », identifiant négatif
  = −id de la chose, contenu caché « t|id ») avec trois boutons, de
  gauche à droite : « Pas fait » (`tp`), « Reporter » (`tr`), « Fait »
  (`tf`). Reporter : la chose revient une heure après l'appui, même
  durée, compteur de reports + 1 ; si ça passe minuit, rien ne bouge
  (elle reste sans réponse). Dans l'appli : « Pas fait / Fait »
  seulement (on change l'heure pour reporter).
- **Sans réponse** ne compte pas comme « pas fait » : la part faite
  = faits / (faits + pas faits).
- **Rappel du soir** (identifiant 3, canal « Préparer demain ») à
  21 h 30 par défaut : point sur la journée et ce qui est prévu le
  lendemain. Recalculé à chaque reprogrammation.
- **Demain** : blocs horaires, temps libre (dès 30 min), pastille
  « Croise » si deux horaires se chevauchent. « Pas fait aujourd'hui » :
  choses d'aujourd'hui pas faites, ou passées sans réponse, pas déjà
  prévues demain, avec « Remettre demain ».
- **Stats** : le planning est aussi une courbe (« Planning », id −1,
  note du jour = part faite arrondie au dixième), comparée aux
  questions dans les découvertes, le comparateur et la carte des liens.
  Section « Ton planning » : anneau des 30 jours, courbe, selon le
  moment (matin / après-midi dès midi / soir dès 18 h) et le jour,
  « Journées chargées » (un point par jour : heures prévues jusqu'à
  8 h, part faite), « Le plus reporté ».
- **Bilan du dimanche** : ligne « Planning : 12 faits sur 15 ».

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
