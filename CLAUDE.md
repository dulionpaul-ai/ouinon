# Oui-Non

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
- Lire `docs/plan_action.md` en début de session et le tenir à jour.
- Tenir `docs/fonctionnement.md` à jour à chaque changement d'architecture.
- `docs/revue_produit.md` : choix de Paul du 22/10/2026, référence pour
  le périmètre V1.
- Rien ne part sur le Play Store ou l'App Store sans l'accord explicite
  de Paul.
- Structure du code reprise de Trousse à Pharma (`dulionpaul-ai/trousse-a-pharma`) :
  `lib/models`, `lib/data`, `lib/screens`, `lib/utils`, `lib/theme`,
  tests dans `test/`. Flutter 3.47.7 partout. APK de test fabriqués
  dans la session ; Codemagic pour l'iPhone.

## Garde-fous (non négociables)

- Aucune réponse ne quitte le téléphone : pas de compte, pas de serveur,
  pas d'outil d'analyse ni de publicité.
- L'appli constate, elle ne conseille pas : jamais de diagnostic ni de
  conseil médical. Les croisements sont présentés comme des coïncidences
  observées (« va souvent avec »), jamais comme des causes.

## Conventions techniques

- Une question a 2 ou 3 réponses, toujours rangées de la meilleure à la
  moins bonne (indice 0 = meilleure). Ce nombre ne change plus après la
  création (sinon l'historique deviendrait faux) ; les libellés, eux,
  peuvent changer.
- Une réponse = (question, jour, indice). « Pas répondu » n'est pas une
  réponse : rien n'est enregistré.
- Le jour d'une réponse est le jour de la notification qui l'a posée
  (une nuit de lundi à mardi, demandée mardi matin, compte pour mardi).
- Identifiant de l'appli prévu : `fr.ouinon.app`, nom affiché « Oui-Non ».
