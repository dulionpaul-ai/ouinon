# Ouinon

Appli mobile Flutter (Android d'abord, iPhone ensuite) de suivi de vie
**minimaliste** : chaque question (« Sport ? », « Assez dormi ? »)
arrive en notification à son heure ; on répond directement depuis la
notification avec 2 ou 3 boutons, sans ouvrir l'appli. Tout est stocké
sur le téléphone (SQLite), sans compte ni serveur.

Repartie de zéro le 25/11/2026 (Paul : « trop de choses, partons sur du
minimaliste »). L'appli tient en **un seul écran** (mes habitudes) et un
formulaire. Depuis le 26/11/2026 : **on répond seulement dans les
notifications** ; l'écran clé est le formulaire (créer, modifier, avec
l'aperçu de la notification). Tout le reste (to-do, planning,
stats, onglets) est mis de côté (`docs/idees.md`) ; l'ancien code reste
dans l'historique git.

## Coaching (5/11/2026)

Claude est aussi le **coach de vie** de Paul (cash et factuel). Mémoire :
`docs/coaching/carnet.md`, à lire et tenir à jour à chaque session.
Ouinon est l'outil de suivi du coaching : le bouton en haut copie le
bilan des 7 derniers jours, à coller au coach.

## Consignes de Paul

- Paul ne code pas et échange souvent à la voix depuis son téléphone :
  réponses courtes, en français, sans jargon, tutoiement.
- Tout en français, sans exception : réponses, messages pendant le
  travail, réflexions visibles, messages de commit, descriptions des
  commandes.
- En début de session : lire `docs/reprendre_le_projet.md` (état, outils,
  APK) et le tenir à jour, avec `docs/historique.md`.
- `docs/cahier.md` : les écrans validés par Paul. **Rien n'est codé
  avant que Paul ait validé l'écran.**
- `docs/idees.md` : tout ce que Paul dit « pour plus tard », avec la date.
- Paul envoie ses retours en captures d'écran de son téléphone.
- **Toujours demander à Paul avant de fabriquer un APK** : faire les
  modifications, les vérifier, regarder les captures
  (`tool/captures_test.dart`), pousser, puis lui demander.
- Claude peut pousser directement sur `main` (accord de Paul du
  22/10/2026).
- Rien ne part sur le Play Store ou l'App Store sans l'accord explicite
  de Paul.
- **Garder l'appli simple** : pas d'onglets, des lignes plutôt que des
  cartes, pas de textes d'aide permanents, pas de nouveau bouton sans
  nécessité. Un formulaire tient sur un écran, sans défiler. Jamais
  d'appui long.

## Garde-fous (non négociables)

- Aucune réponse ne quitte le téléphone : pas de compte, pas de serveur,
  pas d'outil d'analyse ni de publicité. Seule exception, décidée par
  Paul le 26/11/2026 : l'appli **télécharge** un fichier public de
  réglages (couleurs, textes, tailles), sans rien envoyer de Paul.
- L'appli constate, elle ne conseille pas : jamais de diagnostic ni de
  conseil médical.

## Conventions

- Une question a 2 ou 3 réponses, rangées de la meilleure à la moins
  bonne (indice 0 = meilleure). Changer leur nombre convertit
  l'historique (`Base.enregistreAvecNombre`) : de 2 à 3, la moins bonne
  passe en 2 ; de 3 à 2, celles du milieu sont effacées après
  confirmation.
- Une réponse = (question, jour, indice). Pas de réponse = rien
  d'enregistré.
- De gauche à droite, toujours la moins bonne réponse à gauche et la
  meilleure à droite (notification, boutons). Dans une liste verticale,
  la meilleure en haut.
- Une question sans aucun jour est en pause : elle ne sonne jamais, son
  historique est gardé. Une notification ratée reste affichée jusqu'à la
  suivante de la même question.
- Style : thème **HUD** (choisi le 26/11/2026), toujours sombre : noir,
  **bleu glacier** (meilleure réponse, accent), **rouge-orange** (moins
  bonne), gris pour celle du milieu ; lignes fines, équerres, quadrillage.
  Polices : **Oxanium** (texte) et **JetBrains Mono** (chiffres,
  étiquettes). Pas de violet, de halos ni de dégradés. Une vibration
  légère à chaque action.
- **Réglable sans APK** : `lib/models/apparence.dart` (valeurs par défaut)
  et le fichier public `reglages.json` du dépôt `dulionpaul-ai/
  ouinon-reglages` (copie de référence : `reglages/reglages.json`). Pour
  un ajustement de couleur, texte, taille, symbole ou d'affichage : ne
  modifier que ce fichier et le pousser ; l'appli le relit à chaque
  ouverture (une minute au plus de délai). Une nouvelle réglette =
  ajouter la clé dans `Apparence` (APK une fois), puis régler par le
  fichier.
- Structure : `lib/models`, `lib/data`, `lib/screens`, `lib/utils`,
  `lib/theme`, tests dans `test/`. Flutter 3.47.7
  (`tool/installer_outils.sh`). Identifiant `fr.ouinon.app`, nom
  « Ouinon ».
