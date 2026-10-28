# Ouinon

Appli mobile Flutter (Android d'abord, iPhone ensuite) de suivi de vie
minimaliste : chaque question à suivre (« Sport ? », « En forme ? »,
« Sommeil ? ») arrive en notification à son heure, on répond
directement depuis la notification avec 2 ou 3 boutons, sans ouvrir
l'appli. L'appli garde les réponses et en tire des stats en graphiques animés :
courbes, anneaux, barres, calendrier, et liens trouvés seuls entre
questions (courbes qui se ressemblent, décalées de 0 à 3 jours).
Deuxième partie, la to-do : une liste (temps de chaque chose, Important
et Urgent) ; on tire ce qu'on fait aujourd'hui dans l'onglet
Aujourd'hui, puis on le case dans la journée (toucher, glisser ou
« Caser pour moi ») ; créneaux fixes grisés (« Enfants 17 h – 23 h ») ;
une seule notification par chose, à son heure (« C'est l'heure »), avec
deux boutons : Pas fait · Fait (Paul, 28/10/2026).
Tout est stocké sur le téléphone (SQLite), sans compte ni serveur.

## Consignes de Paul

- Paul ne code pas et échange souvent à la voix depuis son téléphone :
  réponses courtes, en français, sans jargon.
- Tout en français, sans exception : réponses, messages intermédiaires
  pendant le travail, points d'avancement, réflexions visibles, messages
  de commit, descriptions des commandes (rappel de Paul du 26/10/2026).
- En début de session : lire `docs/reprendre_le_projet.md` (état,
  outils à installer, comment fabriquer un APK) puis
  `docs/plan_action.md`, et les tenir à jour, avec `docs/historique.md`.
- Tenir `docs/fonctionnement.md` à jour à chaque changement d'architecture.
- `docs/revue_produit.md` : choix de Paul du 22/10/2026, référence pour
  le périmètre V1.
- `docs/idees.md` : idées pour plus tard. Tout ce que Paul dit « pour
  plus tard » y va, avec la date (consigne du 26/10/2026).
- Paul envoie ses retours en captures d'écran de son téléphone.
- **Toujours demander à Paul avant de fabriquer un APK** (consigne du
  23/10/2026) : faire les modifications, les vérifier, les pousser, puis
  lui demander s'il veut l'APK.
- Claude peut travailler et pousser directement sur `main` (accord de
  Paul du 22/10/2026). Le travail de la première session y a été versé
  le 22/10/2026.
- Rien ne part sur le Play Store ou l'App Store sans l'accord explicite
  de Paul.
- Structure du code reprise de Trousse à Pharma (`dulionpaul-ai/trousse-a-pharma`) :
  `lib/models`, `lib/data`, `lib/screens`, `lib/utils`, `lib/theme`,
  `lib/widgets`, tests dans `test/`. Flutter 3.47.7 partout
  (`tool/installer_outils.sh`). APK de test fabriqués dans la session ;
  Codemagic pour l'iPhone.
- Avant chaque APK : regarder les captures (`tool/captures_test.dart`).
- Garder l'appli simple (demande de Paul du 25/10/2026) : pas
  d'onglets (refonte du 27/10/2026), des lignes plutôt que des cartes,
  pas de textes d'aide permanents, pas de nouveau bouton sans nécessité.
- Jamais d'appui long (« c'est juste chiant ») : le glisser-déposer part
  dès qu'on pose le doigt. Pas de défilement dans les écrans, surtout
  pas dans celui de la planification de la journée (consignes de Paul
  du 26/10/2026).

## Garde-fous (non négociables)

- Aucune réponse ne quitte le téléphone : pas de compte, pas de serveur,
  pas d'outil d'analyse ni de publicité.
- L'appli constate, elle ne conseille pas : jamais de diagnostic ni de
  conseil médical. Les croisements sont présentés comme des coïncidences
  observées (« va souvent avec »), jamais comme des causes.

## Conventions techniques

- Une question a 2 ou 3 réponses, toujours rangées de la meilleure à la
  moins bonne (indice 0 = meilleure). Tout se modifie, y compris ce
  nombre (demande de Paul du 22/10/2026), avec conversion de
  l'historique : de 2 à 3, la moins bonne passe en indice 2 ; de 3 à 2,
  les réponses du milieu sont effacées après confirmation et la moins
  bonne passe en 1 (`Base.enregistreAvecNombre`).
- Une réponse = (question, jour, indice). « Pas répondu » n'est pas une
  réponse : rien n'est enregistré.
- Le jour d'une réponse est le jour de la notification qui l'a posée
  (une nuit de lundi à mardi, demandée mardi matin, compte pour mardi).
- De gauche à droite, toujours la moins bonne réponse à gauche et la
  meilleure à droite (notification, boutons, barres).
- Une chose prévue (planning) : « Fait » = 0, « Pas fait » = 1. Sans
  réponse le jour même : nulle ; le lendemain, elle compte « pas fait »
  (pas de réponse = reportée, Paul, 28/10/2026 : `classeSansReponse`) et
  revient dans la to-do. Les questions, elles, ne changent pas : pas de
  réponse = rien d'enregistré. Dans Aujourd'hui,
  le rond d'un bloc passe de « fait » à « pas fait » puis « sans
  réponse ». Tirée de la liste
  (`listeId`) : « Fait » la sort de la liste, sinon elle revient « à
  placer ». Cases : D'abord, À planifier, Vite fait, Peut-être jamais.
- Repartie de zéro le 27/10/2026, à la demande de Paul : l'appli se
  construit écran par écran d'après `docs/cahier.md`, rien n'est codé
  avant que Paul ait validé l'écran. L'ancienne appli (APK n° 22) est
  rangée dans `ancien/` (ni compilée ni analysée) ; on y pioche si un
  écran du cahier en a besoin. Le moteur est gardé : `data/base.dart`,
  `data/notifications.dart` (questions seulement), `utils/planification.dart`.
- Trois onglets, dans cet ordre (Paul, 28/10/2026) : To-do (matrice
  d'Eisenhower ; on tire une chose vers la droite, sur le bandeau
  « Aujourd'hui », ou sur « Fait » si elle est déjà faite), Aujourd'hui (ce qui est à placer, puis le planning
  de la journée sans défilement), Questions (celles du jour, « + » pour
  en créer). Stats et tout le reste dans les Réglages (roue en haut).
  Maquette validée : https://claude.ai/artifact/RZnQ8gh7CKAG8RZALSa8AQ.
  Le jeu « Synchro » a été abandonné (28/10/2026).
- Style (Paul, 27–28/10/2026) : **toujours sombre, jamais de mode
  clair** ; futuriste ; une petite animation à chaque action (ajouter,
  répondre, cocher, glisser) avec vibration et « Annuler » ; pas de
  polices trop rondes, pas de look « IA » (violet, halos flous,
  dégradés). **Deux couleurs seulement, translucides** : orange (la
  to-do, ce qui reste à faire, la moins bonne réponse) et vert d'eau
  (Aujourd'hui, ce qui est fait, la meilleure réponse) ; gris pour la
  réponse du milieu. **Une seule police partout : Oxanium** (choix de Paul
  du 28/10/2026, `lib/theme/app_theme.dart`).
- Une notification ratée reste affichée jusqu'à la suivante de la même
  question (Android : `timeoutAfter`) ; sans réponse, rien n'est
  enregistré. Une question sans aucun jour ne sonne jamais (en pause).
- Identifiant de l'appli : `fr.ouinon.app`, nom affiché « Ouinon ».
