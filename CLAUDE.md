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
- Garder l'appli simple (demande de Paul du 25/10/2026) : trois onglets
  (To-do, Aujourd'hui, Stats), des lignes plutôt que des cartes, pas de
  textes d'aide permanents, pas de nouveau bouton sans nécessité.

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
- Les deux toi (26/10/2026) : le soir, le Décideur (accent ambre,
  `AppTheme.soir`, to-do en 4 cases) ; le jour, l'Exécutant (Aujourd'hui
  calme, `AppTheme.jour`, accent bleu-vert, calendrier). Le terminal
  rétro (`AppTheme.retro`, `lib/widgets/retro.dart`) par petites touches
  seulement : Paul le trouve fatigant en plein écran. Style « tableau »
  pour le Décideur (moins rond, matrice en croix), « terminal sobre »
  pour l'Exécutant (`Teintes.terminal`, `Teintes.rayon`), validés le
  26/10/2026. Onglets : To-do, Aujourd'hui, Stats. Plages : l'anneau
  des 24 heures est toujours plein (pas de repos) : la journée (début /
  fin) à l'Exécutant, tout le reste au Décideur. Rien de la série
  Severance (nom, logo, vocabulaire).
- Identifiant de l'appli : `fr.ouinon.app`, nom affiché « Ouinon ».
