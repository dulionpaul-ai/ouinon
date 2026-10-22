# OuiNon

Appli mobile Flutter (iPhone et Android) de suivi de vie minimaliste :
l'appli pose des questions oui/non dans les notifications (« Bien
dormi ? », « Café après 16 h ? »), on répond d'un geste sans ouvrir
l'appli, puis l'appli croise les réponses pour faire ressortir des liens
(« les jours avec café après 16 h, tu dors moins bien 2 fois sur 3 »).
Tout est stocké sur le téléphone (SQLite), sans compte ni serveur.

## Consignes de Paul

- Paul ne code pas et échange souvent à la voix depuis son téléphone :
  réponses courtes, en français, sans jargon.
- Tout en français, sans exception : réponses, messages intermédiaires
  pendant le travail, points d'avancement.
- Lire `docs/plan_action.md` en début de session et le tenir à jour.
- Tenir `docs/fonctionnement.md` à jour à chaque changement d'architecture
  (à créer avec le socle).
- `docs/revue_produit.md` : périmètre V1 proposé le 22/10/2026,
  à faire valider par Paul avant de coder au-delà du socle.
- Rien ne part sur le Play Store ou l'App Store sans l'accord explicite
  de Paul.
- Structure du code reprise de Trousse à Pharma et Wavents :
  `lib/models`, `lib/data`, `lib/screens`, `lib/utils`, `lib/theme`,
  tests dans `test/`. Compilation sur Codemagic.

## Garde-fous (non négociables)

- Aucune réponse ne quitte le téléphone : pas de compte, pas de serveur,
  pas d'outil d'analyse ni de publicité.
- L'appli constate, elle ne conseille pas : jamais de diagnostic ni de
  conseil médical. Les liens trouvés sont présentés comme des
  coïncidences observées (« va souvent avec »), pas comme des causes.
- Pas de lien affiché tant qu'il n'y a pas assez de réponses (seuil
  minimal de jours, voir `docs/revue_produit.md`).

## Conventions techniques

- Une réponse = (question, jour, oui | non). « Pas répondu » n'est pas
  « non » : on ne l'enregistre pas.
- Le « jour » d'une réponse est le jour concerné, pas l'heure de la
  réponse (« Bien dormi ? » posé le matin parle de la nuit d'avant).
- Identifiant de l'appli prévu : `fr.ouinon.app` (à confirmer par Paul).
