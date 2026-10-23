# Ouinon

Appli mobile Flutter (Android d'abord, iPhone ensuite) de suivi de vie
minimaliste : chaque question à suivre (« Sport ? », « En forme ? »,
« Sommeil ? ») arrive en notification à son heure, on répond
directement depuis la notification avec 2 ou 3 boutons, sans ouvrir
l'appli. L'appli garde les réponses et en tire des stats : bilan par
question, calendrier, jour de la semaine, et croisements entre questions
(même jour et lendemain).
Tout est stocké sur le téléphone (SQLite), sans compte ni serveur.

## Consignes de Paul

- Paul ne code pas et échange souvent à la voix depuis son téléphone :
  réponses courtes, en français, sans jargon.
- Tout en français, sans exception : réponses, messages intermédiaires
  pendant le travail, points d'avancement.
- En début de session : lire `docs/reprendre_le_projet.md` (état,
  outils à installer, comment fabriquer un APK) puis
  `docs/plan_action.md`, et les tenir à jour, avec `docs/historique.md`.
- Tenir `docs/fonctionnement.md` à jour à chaque changement d'architecture.
- `docs/revue_produit.md` : choix de Paul du 22/10/2026, référence pour
  le périmètre V1.
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
- Toujours sombre ; style et couleurs dans `lib/theme/app_theme.dart`
  (`Teintes`) et `lib/widgets/rond.dart`, pas de puces Material.
- Identifiant de l'appli : `fr.ouinon.app`, nom affiché « Ouinon ».
