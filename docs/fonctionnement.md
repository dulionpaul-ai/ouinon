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
| `models/a_faire.dart` | Une chose de la liste « À faire » : texte, durée, important, urgent (coché), date limite, créée le, faite le, choisie pour (jour de son bac), marque « test » ; sa case d'Eisenhower un jour donné (`caseLe`) ; les 4 cases (`Case`). |
| `models/tache.dart` | Une chose prévue du planning : jour, début et durée (minutes), texte, réponse (`fait` = 0, `pasFait` = 1, ou nulle), nombre de reports, marque « test », chose de la liste d'où elle vient (`listeId`, nulle pour un impératif) et sa case au moment du placement (`quadrant`). |
| `models/creneau.dart` | Un créneau fixe qui revient chaque semaine (texte, début, fin, jours). |
| `widgets/grille_journee.dart` | La journée heure par heure (52 px par heure, 8 h – 23 h, élargie si besoin) : blocs à leur vraie taille (couleur de leur case, blanc pour un impératif), créneaux hachurés, trait « maintenant » ; dépôt d'une chose du bac ou d'un bloc (au quart d'heure, d'après le haut de ce qu'on glisse), durée en tirant le bas, toucher une heure vide. |
| `screens/edition_creneau_screen.dart` | Ajout ou modification d'un créneau fixe. |
| `utils/deux_moi.dart` | Les deux toi (testé) : qui est là (`moiA` : exécutant, décideur, repos ; plages qui passent minuit), chose en cours (`enCours`), textes du matin et du compte rendu. |
| `screens/intro_screen.dart` | Intro en 3 pages, cadran des heures, logo animé (`RondDissocie`). |
| `screens/passage_screen.dart` | L'ascenseur : portes, étage SOIR ↓ JOUR, lignes du terminal qui s'écrivent ; 2,4 s puis se ferme seul, un appui le passe. |
| `screens/rapport_screen.dart` | Compte rendu de fin de journée (rétro), mot pour le soir, « Fin de service ». |
| `widgets/retro.dart` | Briques rétro : fond à lignes de balayage, curseur (`Curseur.clignote` coupé dans les tests), bouton rectangulaire, barre « [████░░] », heures « 09:05 ». |
| `data/base.dart` | Base `ouinon.sqlite` (version 4 : colonne `choisie_pour` de `liste` et table `creneaux`) : tables `questions` (rendues dans l'ordre de la journée : heure, puis création), `reponses` (une réponse par question et par jour, effacée avec sa question), `planning` (version 2 ; colonnes `liste_id` et `quadrant` en version 3) et `liste` (version 3), par mise à jour de la base. « Fait » sur une chose tirée de la liste la marque faite dans la liste (`repondTache`) ; `placees` dit ce qui est déjà placé. Reporter une chose (`reporteTache`), raccourcis (`habitudes`). Changement du nombre de réponses avec conversion de l'historique (`enregistreAvecNombre`). |
| `data/preferences.dart` | Choix gardés sur le téléphone : bilan du dimanche, rappel du soir et son heure (activés par défaut, 21 h 30), heures de la journée (9 h – 19 h), notifications du planning (début et fin par défaut). `DeuxMoi` : intro vue (= modes actifs), fin du soir (23 h), mots (`mot_2026-10-23` pour le toi du jour, `mot_soir_…` pour le soir), ascenseur du matin déjà joué. |
| `data/suggestions.dart` | Suggestions de réponses de l'écran Nouvelle question (« Oui / Non », « Bien / Moyen / Pas bien » au départ), créées, modifiées ou supprimées par la personne, gardées dans les préférences du téléphone. |
| `data/notifications.dart` | Programmation des notifications (questions, choses prévues, rappel du soir, bilan), boutons, réponse depuis la notification (`reponseNotifArrierePlan`). |
| `utils/remplissage.dart` | « Remplir ma journée » (testé) : ordre de placement, premier créneau libre, proposition, temps libre. |
| `widgets/cases.dart` | Couleurs des 4 cases, grille 2 × 2 de la liste. |
| `utils/planning.dart` | Calculs du planning (testés) : rappels à programmer, textes, part faite, planning vu comme une question (`questionPlanning`), stats (moment, jour, charge, plus reportées), horaires qui se croisent, ligne du bilan. |
| `utils/planification.dart` | Calcul pur de ce qu'il faut programmer (testé). |
| `utils/stats.dart` | Bilans, jour de la semaine, séries (`serie`), bilan de la semaine (`bilanSemaine`) (testé). |
| `utils/courbes.dart` | Notes de 0 à 1, moyenne glissante sur 7 jours, ressemblance de deux courbes avec décalage, découvertes, points par semaine, droite de tendance (testé). |
| `data/donnees_test.dart` | 6 mois de réponses et de planning de test (marqués « test » dans la base, effaçables d'un coup ; jamais sur un jour déjà planifié). |
| `widgets/bloc_tache.dart` | Une chose prévue en bloc horaire (heures à gauche, liseré à la couleur de la réponse, boutons « Pas fait / Fait »), temps libre entre deux. |
| `widgets/graphiques.dart` | Graphiques (module `fl_chart` 1.2.0) : courbes, anneau, barres, nuage de points, grille de 6 mois, carte des liens ; animation quand on s'arrête dessus (`AnimeQuandVisible`). |
| `utils/jour.dart`, `utils/date_fr.dart` | Jours de calendrier (« 2026-10-22 ») et dates en français. |
| `screens/` | Accueil (3 onglets : Aujourd'hui, To-do, Stats ; le rappel du soir ouvre « Préparer demain »), Aujourd'hui (questions compactes, « Ma journée »), To-do (`todo_screen.dart` : liste, ajout rapide, Préparer demain), Préparer (`preparer_screen.dart` : choisir avec la jauge, puis caser), Créneaux fixes (`creneaux_screen.dart`), Réglages (lignes simples, mènent à Mes questions et Créneaux fixes), écran « À faire » (une chose de la liste), Impératif (ajout ou modification d'une chose prévue), Aujourd'hui (une page par jour, on glisse vers la droite pour la veille, jamais après aujourd'hui), Stats (découvertes, comparateur de deux courbes, carte des liens, une carte par question), fiche d'une question, Questions (par heure, sans rangement à la main), modification, Réglages. |
| `theme/app_theme.dart` | Style « Nuit ronde », toujours sombre (choix de Paul du 22/10/2026) : couleurs dans `Teintes`, polices Unbounded (titres) et Figtree (texte), embarquées dans `assets/fonts` (licence OFL). Réponses : citron, abricot, corail. |
| `widgets/rond.dart` | Briques rondes : carte, pastille, bouton rond et bouton +, grand titre (réduit plutôt que coupé), barre d'onglets flottante, choix en pilules, pilule à toucher, jour de la semaine en rond. Pas de puces Material (police et couleurs mal reprises). |

## Icône

- Logo n° 3 (choix de Paul du 22/10/2026) devenu le « rond dissocié »
  (26/10/2026) : rond coupé en deux, moitié gauche ambre plus haute,
  moitié droite bleu-vert plus basse, sur fond sombre. `tool/icones.py` (Python +
  Pillow) écrit toutes les icônes : Android classiques, adaptatives
  (avec monochrome pour Android 13) et iPhone. Taille du logo réglée par
  `TAILLE` (0,95 : réduit de 5 % à la demande de Paul).
- Petite icône des notifications : `drawable/ic_stat_ouinon.xml`, en
  blanc : moitié gauche pleine plus haute, moitié droite en contour plus
  basse,
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
- **Deux notifications** (canal « Planning », identifiants négatifs :
  début = −2 × id, fin = −2 × id − 1, contenu caché « t|id ») : au
  début « C'est l'heure » avec « Reporter » ; à la fin « …, c'est
  fait ? » avec, de gauche à droite, « Pas fait » (`tp`), « Reporter »
  (`tr`), « Fait » (`tf`). Réglages : les deux, début seul ou fin seule
  (la seule porte alors les trois boutons). Reporter : la chose revient une heure après l'appui, même
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

## Liste « À faire »

- **Une chose** : texte, durée, « Important ? », « Urgent ? », date
  limite facultative. Urgente si cochée, ou à moins de 2 jours de sa
  date limite (ou en retard).
- **4 cases** : D'abord (urgent et important, corail), À planifier
  (important, citron), Vite fait (urgent, abricot), Peut-être jamais
  (neutre). Vue Liste : grille 2 × 2 (nombre et temps par case), puis
  chaque case ; pastilles durée, « Limite … », « Demain 10 h » si
  placée, « Depuis 12 j » dès 7 jours.
- **Placer** : depuis « À placer » (vues Aujourd'hui et Demain), au
  premier créneau libre, ou tout d'un coup avec « Remplir ma journée »
  (proposition à valider). Ordre : dernier jour d'une date limite,
  D'abord, À planifier, Vite fait ; dans une case, date limite la plus
  proche puis la plus ancienne ; « Peut-être jamais » jamais
  automatiquement. Entre le début et la fin de journée (Réglages),
  15 min de marge entre deux choses, horaires au quart d'heure ;
  aujourd'hui, pas avant le prochain quart d'heure.
- **Après** : « Fait » sort la chose de la liste ; « Pas fait » ou pas
  de réponse : elle revient « à placer » d'elle-même. Modifier la liste
  met à jour ses passages prévus sans réponse ; la supprimer ou la
  marquer faite les retire.
- **Rappel du soir** : dit aussi combien de choses attendent dans la
  liste.
- **Stats** : « Les 4 cases » (part du temps fait sur « À planifier »
  sur 30 jours, part faite par case) et « Ce qui attend le plus ».

## Aujourd'hui, To-do, Préparer demain (simplifié le 25/10/2026)

- **Aujourd'hui** : questions en lignes ; répondue, une pastille (la
  toucher rouvre les boutons). « Ma journée » : choses casées et
  créneaux fixes dans l'ordre ; le rond coche « Fait » ; toucher une
  ligne : Pas fait / Fait, Modifier, Remettre dans la to-do. « Préparer »
  / « Modifier » ouvre Préparer pour ce jour.
- **To-do** : choses à faire, triées (dernier jour d'une date limite,
  urgent et important, important, urgent, le reste ; date limite proche
  puis plus ancienne). Rond = fait (avec « Annuler »). Barre « Ajouter… »
  : « Papiers 1 h », « Banque 30 min », « Garage 1h30 » (`lisAjout`),
  30 min sinon. Écran d'une chose : durée, Important et Urgent sur une
  ligne, date limite (urgente à moins de 2 jours).
- **Préparer** (un jour) : étape 1, cocher (`choisitPour`) ; jauge =
  durées choisies face au temps libre de la journée (Réglages, 9 h –
  19 h) moins rendez-vous et créneaux fixes ; citron, orange dès 85 %,
  rouge au-delà. Étape 2 : journée (40 px par heure), glisser les
  choses, « Caser pour moi » (`remplitJournee`), toucher une heure vide
  = rendez-vous. « Terminer » case le reste ; ce qui ne rentre pas n'est
  plus choisi et reste dans la to-do.
- **Après le jour** : une chose casée pas faite reste dans la to-do
  (« Fait » seul l'en sort).

## Les deux toi (26/10/2026)

- **Qui est là** : une fois l'intro vue, l'accueil regarde l'heure
  (chaque minute et au retour dans l'appli). Plage de l'exécutant = début
  et fin de journée ; plage du décideur = heure du rappel du soir → fin
  du soir. Le jour l'emporte si elles se croisent ; ailleurs, repos
  (style habituel).
- **Le jour** : l'onglet Aujourd'hui seul passe en rétro (même arbre de
  widgets dans tous les modes : rien n'est perdu en changeant). En haut,
  la chose en cours ou la prochaine sans réponse, avec Pas fait ·
  Reporter · Fait ; le mot du soir ; « [ COMPTE RENDU ] ».
- **Le soir** : accent ambre partout ; en haut d'Aujourd'hui, le score
  du jour et le mot remonté, puis « Préparer demain ». Préparer s'ouvre
  toujours en ambre. Préparer demain (pour un jour à venir) finit par le
  mot pour demain, puis l'ascenseur vers le jour.
- **Ascenseur du matin** : la première fois que l'appli est ouverte dans
  la plage du jour (une fois par jour).
- **Notifications** (si l'intro a été vue, et seulement si quelque chose
  est prévu) : id 4 au début de la journée, « Ta journée t'attend » ;
  id 5 à la fin, « Fin de service » (contenu caché `rapport` : ouvre le
  compte rendu). Le rappel du soir devient « Et demain, tu fais quoi ? ».

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
