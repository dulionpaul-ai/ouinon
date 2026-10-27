# Ouinon

Appli mobile Flutter (Android d'abord, iPhone ensuite) de suivi de vie
minimaliste : chaque question à suivre (« Sport ? », « En forme ? »,
« Sommeil ? ») arrive en notification à son heure, on répond
directement depuis la notification avec 2 ou 3 boutons, sans ouvrir
l'appli. L'appli garde les réponses et en tire des stats en graphiques animés :
courbes, anneaux, barres, calendrier, et liens trouvés seuls entre
questions (courbes qui se ressemblent, décalées de 0 à 3 jours).
Deuxième partie, la to-do : une liste (temps de chaque chose, Important
et Urgent) ; chaque soir, « Préparer demain » en 2 étapes : choisir
(une jauge dit si ça rentre) puis caser dans la journée (glisser ou
« Caser pour moi ») ; créneaux fixes grisés (« Enfants 17 h – 23 h ») ; une notification au début (« C'est
l'heure ») et une à la fin (« C'est fait ? » : Pas fait · Reporter ·
Fait).
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
- Une chose prévue (planning) : « Fait » = 0, « Pas fait » = 1, sans
  réponse = nulle (ne compte pas dans le pourcentage) ; « Reporter » la
  remet une heure après l'appui, jamais après minuit. Tirée de la liste
  (`listeId`) : « Fait » la sort de la liste, sinon elle revient « à
  placer ». Cases : D'abord, À planifier, Vite fait, Peut-être jamais.
- Toujours sombre ; style et couleurs dans `lib/theme/app_theme.dart`
  (`Teintes`) et `lib/widgets/rond.dart`, pas de puces Material.
- Le parcours (refonte validée par Paul le 27/10/2026, maquette
  « Ouinon, le rituel du soir ») : la journée tourne seule avec les
  notifications ; on ouvre l'appli une fois, le soir. Accueil
  (`BilanScreen`) : « Bonsoir. », l'anneau du jour, la journée en lignes,
  les questions sans réponse, « Préparer demain » (l'ascenseur monte, à
  garder pour l'animation), « Mon suivi » (`StatsScreen` : questions,
  courbes, liens) et la roue des Réglages. Étape 1 (`ChoisirScreen`) :
  saisie en vrac, matrice d'Eisenhower en aimants, un toucher choisit et
  ouvre les réglages en bas (durée, Important, Urgent, heure), une case
  trop pleine se replie en « + 3 autres ». Étape 2 (`PlacerScreen`) :
  toute la journée dans l'écran, glisser sans appui long, « Caser pour
  moi », « C'est prêt ». Puis `PretScreen` : « Demain est prêt. », les
  rappels de demain, « Bonne nuit ». Un seul thème, `AppTheme.soir`
  (accent ambre, bleu-vert pour « fait »). Le Décideur et l'Exécutant
  restent dans l'intro et le ton, plus comme rôles. Les heures de la
  journée (Réglages) servent aux notifications et à « Caser pour moi ».
  Rien de la série Severance (nom, logo, vocabulaire).
- Identifiant de l'appli : `fr.ouinon.app`, nom affiché « Ouinon ».
