# Historique de Ouinon

Ce qui a été décidé et fait, dans l'ordre. Le plus récent en bas.

## 22/10/2026 : cadrage

- Paul décrit l'idée : des notifications pour savoir si on a fait
  telle chose (sport, forme, dehors, sommeil), réponse directe depuis la
  notification avec 2 ou 3 réponses (ex. sommeil : 8 h et + / 6 à 8 h /
  moins de 6 h), questions ajoutables, stats à long terme et croisées.
- 16 questions posées à Paul, réponses dans `docs/revue_produit.md` :
  2 ou 3 réponses au choix, rangées de la meilleure à la moins bonne,
  chaque question à son heure, pas de relance, jours au choix, pas
  d'objectifs ni de note, toutes les stats, croisements même jour et
  lendemain dès 7 jours, la nuit compte pour le jour qui suit, Android
  d'abord, pour Paul puis les stores, sauvegarde plus tard.
- Plan écrit, relu et corrigé (`docs/plan_action.md`, partie
  « Relecture »).
- Accès GitHub d'abord refusé (appli Claude pas installée sur le dépôt),
  réglé par Paul dans la journée.

## APK n° 1 (1.0.0+1) : première version

- Questions, notifications à boutons (appli fermée), 14 jours
  programmés d'avance, rappel « continuer », écrans Aujourd'hui, Stats
  (bilan, liens), fiche d'une question (évolution, jour de la semaine,
  calendrier), Mes questions, Réglages (« Essayer une notification »).
- Style provisoire « Blanc net ».

## APK n° 2 (1.0.0+2) : style rond, nom Ouinon

- Paul trouve les 3 premiers styles trop « appli d'IA ». Nouvelle série
  ronde : D Bulles, E Galets, F Nuit ronde. Appliqué : D en clair, F en
  sombre, polices Unbounded (titres) et Figtree (texte), embarquées.
- Le nom devient « Ouinon » (au lieu de « Oui-Non »).

## APK n° 3 (1.0.0+3) : retours sur captures

- Corrigé : titre « Questions » coupé en deux, jours illisibles en mode
  sombre, intitulés des champs mal placés.
- Ajouté : bouton + rond, carte « Ajouter une question », modèles de
  réponses, jours en ronds avec raccourcis, heure en grosse pastille,
  « Enregistrer » toujours visible, vibration à chaque réponse,
  avancement du jour sous le titre. Vérification sur petit téléphone
  avec gros texte.

## APK n° 4 (1.0.0+4) : logo, sombre seulement

- 4 pistes de logo ; Paul choisit le n° 3 (rond coupé citron / corail),
  avec « Ouinon » (O majuscule). Icônes Android et iPhone, petite icône
  blanche des notifications, écran de démarrage sombre.
- Appli toujours sombre : thème clair retiré.
- Suggestions de réponses modifiables (créer, modifier, supprimer).
- Raccourcis de jours sur une ligne ; aide « vert / rouge ».
- Écran Jour plus compact (pilules de 44) pour voir les 4 questions.

## APK n° 5 (1.0.0+5) : retours sur l'APK n° 4

Paul a demandé d'attendre la fin de ses retours, puis a validé l'APK.

- Heure : un essai de roulettes a été refusé ; retour au cadran
  d'Android, sans bouton clavier, « Enregistrer » caché pendant le
  choix.
- Ordre des réponses : la moins bonne à gauche, la meilleure à droite,
  dans la notification puis partout dans l'appli.
- Nombre de réponses modifiable sur une question existante, avec
  conversion de l'historique (confirmation si des réponses du milieu
  sont effacées).
- « + Nouvelle » devient « + Autre » dans les suggestions.
- Page Jour : on glisse vers la droite pour la veille, jamais après
  aujourd'hui.
- Documentation de reprise (`docs/reprendre_le_projet.md`, ce fichier,
  `tool/installer_outils.sh`).
