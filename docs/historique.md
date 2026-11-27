# Historique de Ouinon

Le plus récent en bas. Le détail de la première version (APK n° 1 à
n° 37, du 22/10 au 5/11/2026) est dans l'historique git.

## 22/10 → 5/11/2026 : première version

37 APK et plusieurs refontes : questions en notification (réponse appli
fermée, confirmée par Paul), stats en graphiques, to-do et planning,
« les deux toi », trois onglets, puis l'étape 1 du coaching (seulement
les questions et le bilan pour le coach).

## 25/11/2026 : repartie de zéro (2.0.0+38)

- Audit : trop de virages, la moitié du code ne servait plus (dossier
  `ancien/`, to-do et stats cachées), documents contradictoires.
- Paul valide une version minimaliste. Gardé : les notifications à
  boutons, la base du téléphone (ses questions et réponses), la clé de
  test. Tout le reste retiré : to-do, planning, stats, dictée, onglets,
  réglages, bilan du dimanche, rappel du soir.
- Un écran, un formulaire, 16 tests.
- APK n° 38 envoyé à Paul le 25/11/2026.

## 26/11/2026 : devenir une meilleure version de soi (2.0.0+39)

- Paul : « un truc minimaliste qui m'aide à devenir une meilleure
  version de moi-même », et l'appli aussi pour le ménage et les plantes.
  Maquette validée (« Go »), sans limite d'habitudes.
- Codé : la phrase « Je deviens quelqu'un qui… », le compte de la
  semaine, 7 points par question, réponse en pastille, « Pas
  aujourd'hui » et « En pause » repliés ; le « pourquoi » dans la
  notification ; les tâches « tous les N jours ». Base en version 9.
- Coaching : `docs/coaching/habitudes.md`, l'analyse et la liste des
  habitudes à trier.

## 26/11/2026 : thème HUD, réponses dans les notifications, réglable sans APK (2.0.0+39)

- Paul arrête l'APK et demande un thème futuriste ; quatre essais
  modernes, puis deux pistes (HUD, Acide) : HUD retenu.
- On répond seulement dans les notifications. Liste et formulaire au
  style HUD ; aperçu de la notification dans le formulaire. Notifications
  colorées, en capitales, avec deux images dessinées par l'appli.
- Réglable sans APK : l'appli lit un fichier public de réglages
  (accord de Paul, rien n'est envoyé). Le dépôt public
  `ouinon-reglages` est à créer par Paul (Claude ne peut pas créer de
  dépôt) ; il conseille aussi de passer `ouinon` en privé (le carnet de
  coaching y est lisible par tous).
- Polices : Oxanium + JetBrains Mono. 28 tests.
- APK n° 39 (2.0.0+39) envoyé à Paul le 26/11/2026.

## 26/11/2026 : retour à la version minimaliste (2.0.0+40)

- Paul : « je préférais la version minimaliste du début ». Retour aux
  écrans validés (vert et orange, la phrase, la semaine, 7 points,
  réponses dans l'appli comme sur la maquette, notifications sobres).
- Gardé : le « pourquoi », les tâches tous les N jours, les réglages sans
  APK (couleurs, textes, tailles, affichage, et maintenant les boutons de
  réponse dans l'appli).
- APK n° 40 (2.0.0+40) envoyé à Paul le 26/11/2026.

## 26/11/2026 : copie en ligne (2.0.0+41)

- Paul lève la règle « rien ne quitte le téléphone » et choisit
  Supabase : sauvegarde, et le coach lit les réponses sans bilan à
  coller. Projet « Ouinon » créé à côté de Wavents (sans y toucher).
- Chaque changement part en ligne ; à l'ouverture, tout est renvoyé ;
  nouveau téléphone → tout revient.
- APK n° 41 (2.0.0+41) envoyé à Paul le 26/11/2026.

## 27/11/2026 : jours fixes ou tous les N jours (2.0.0+42)

- Paul trouvait « dimanche + tous les 7 jours » contradictoire : le
  formulaire propose maintenant l'un **ou** l'autre, avec « Prochaine
  fois » pour une tâche. Faite un autre jour, la tâche se recale.
- On peut répondre dans « Pas aujourd'hui ».
- Base en version 10 (`depart`) : une ancienne tâche avec des jours garde
  l'intervalle, sa prochaine fois est le prochain de ses jours.
- APK n° 42 (2.0.0+42) envoyé à Paul le 27/11/2026.
