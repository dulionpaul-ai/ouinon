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
- Le travail est versé dans `main` avec l'accord de Paul ; les sessions
  suivantes partent de `main` et y poussent directement.

## APK n° 6 (1.0.0+6) : logo un peu plus petit

- Paul confirme que la réponse depuis une notification fonctionne et
  s'enregistre dans l'appli (APK n° 5) : le point le plus risqué du plan
  est validé.
- Logo de l'icône réduit de 5 % (`TAILLE` dans `tool/icones.py`).

## APK n° 7 (1.0.0+7) : notifications à l'heure

- Le soir du 22/10/2026, Paul ne reçoit pas les questions de 21 h.
  Cause : les notifications étaient en « heure approximative », qu'Android
  peut retarder de plusieurs heures quand elles sont programmées
  longtemps à l'avance (et une question déjà répondue dans l'appli est
  volontairement sautée).
- Correction : heure précise avec l'autorisation Android « Alarmes et
  rappels » (demandée une fois au démarrage, et bouton dans les
  Réglages) ; heure approximative seulement si refusée.
- Réglages : état de l'heure précise, prochaine question prévue, nombre
  de notifications programmées, rappel qu'une question déjà répondue
  n'envoie pas de notification.

## APK n° 8 (1.0.0+8) : heure en temps universel, questions par heure

Paul demande désormais qu'on lui pose la question avant chaque APK ; il
a validé celui-ci le 23/10/2026.

- Le 23/10/2026, une question réglée à 7 h 01 arrive à 8 h 01 chez Paul.
  Cause probable : l'heure passait par un fuseau horaire détecté par
  l'appli avant d'être retraduite par Android ; un fuseau faux d'une
  heure donne exactement ce décalage.
- Correction : le moment est calculé avec l'horloge du téléphone et
  envoyé à Android en temps universel (UTC), sans fuseau intermédiaire.
  Module `flutter_timezone` retiré.
- À vérifier avec Paul : Réglages → « Heure précise autorisée » (sinon,
  Android peut aussi retarder les questions).
- Questions rangées dans l'ordre de la journée (heure), dans « Jour »
  comme dans « Questions » ; le rangement à la main (appui long) est
  retiré.

## APK n° 9 (1.0.0+9) : stats en classement, séries, bilan, notification revue

Fabriqué avec l'accord de Paul le 23/10/2026.

- Page Stats refaite autour des croisements (Paul : « une série de
  textes qui ne sert pas à grand-chose ») : croiseur libre de deux
  questions, liens en barres « avec / sans », une ligne par question.
- Notification revue : plus de date sous la question ; plus de couleur
  (le citron devenait vert olive chez Samsung) ; nouveau logo blanc,
  moitié pleine (oui), moitié en contour (non).
- Critique franche demandée par Paul (sa copine « ne voit pas
  l'intérêt ») : la valeur arrive trop tard. Retenu pour l'instant :
  question principale + stats en classement, bilan du dimanche soir,
  séries (idée de Paul). Gardés pour plus tard : sauvegarde, mode
  « expérience », objectifs tout prêts au démarrage.
- Séries : flamme sur la page Jour, série et record sur la fiche, dans
  la ligne de chaque question des stats.
- Stats : « Ce qui va avec tes bonnes journées », classement autour de
  la question principale (choisie dans les stats), lignes grisées quand
  il manque des jours ; croiseur gardé dessous.
- Bilan du dimanche à 20 h, interrupteur dans les Réglages.

## APK n° 10 (1.0.0+10) : stats en graphiques

Fabriqué avec l'accord de Paul le 23/10/2026.

- Paul envoie une capture de l'ancienne page Stats : l'APK n° 9 n'était
  pas installé. Le numéro de l'APK s'affiche désormais en bas des
  Réglages (« Ouinon 1.0.0 · APK n° 10 »), tiré de
  `lib/utils/version.dart`, aligné sur `pubspec.yaml` par un test.
- Paul n'est pas convaincu par la question principale : « c'est à moi
  de trouver les liens… je veux que l'outil les trouve tout seul », avec
  « plein de graphiques » modernes et animés. Stats refaites :
  - l'appli compare toutes les paires de questions, décalées de 0 à 3
    jours, et montre les courbes qui se ressemblent (ou s'opposent) ;
  - comparateur de deux courbes avec décalage, nuage de points semaine
    par semaine, carte de tous les liens, anneaux, barres, grille de
    6 mois ; chaque graphique s'anime quand on s'arrête dessus ;
  - question principale, classement et croiseur retirés.
- Bouton « Ajouter 6 mois de test » dans les Réglages (et « Effacer les
  réponses de test ») pour essayer les graphiques sans attendre.

## APK n° 11 (1.0.0+11) : planning, liste « À faire », Eisenhower

- Paul propose une deuxième partie : « qu'est-ce que je dois faire
  demain, de quelle heure à quelle heure », planifiée chaque soir, avec
  des rappels qui suivent, et pour chacun « oui, non ou reporter » (une
  heure plus tard). Choix : rappel à l'heure pile, seulement demain pour
  l'instant.
- Idée relue et améliorée (`docs/plan_action.md`, « Relecture du
  planning »), puis codée : onglet « Demain » (aujourd'hui / demain),
  écran « À prévoir » (quoi, quand, durée, raccourcis), blocs horaires
  avec le temps libre, « Pas fait aujourd'hui » à remettre demain,
  section « Prévu » sur la page Jour, rappel du soir (Réglages), ligne
  du planning dans le bilan du dimanche, section « Ton planning » dans
  les stats et courbe « Planning » comparée aux questions. Planning de
  test ajouté au bouton « Ajouter 6 mois de test ».
- Deuxième idée de Paul le même jour : une liste « À faire » avec le
  temps de chaque chose, rangée dans les 4 cases d'Eisenhower, placée
  chaque soir sur la journée du lendemain, puis des notifications. Ses
  choix : deux notifications (début et fin), « Remplir ma journée »
  automatique (à creuser ensuite), urgent coché à la main **et** déduit
  d'une date limite ; il pose ses impératifs, l'appli pré-remplit le
  reste.
- Codé : onglet « À faire » (Liste · Aujourd'hui · Demain), grille des
  4 cases (D'abord, À planifier, Vite fait, Peut-être jamais), écran
  « À faire » (temps, important ?, urgent ?, date limite), « Remplir ma
  journée » (proposition à valider), « Placer » d'un toucher, ce qui
  n'est pas fait revient « à placer », notification au début (« C'est
  l'heure », Reporter) et à la fin (« C'est fait ? »), réglages de la
  journée (9 h – 19 h) et des notifications, stats « Les 4 cases » et
  « Ce qui attend le plus ». Base en version 3.
- APK fabriqué avec l'accord de Paul (« Go et apk »).
