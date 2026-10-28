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

## APK n° 12 (1.0.0+12) : comme le tableau blanc

- Paul montre son tableau blanc : tout à droite les tâches de fond (sa
  matrice d'Eisenhower), au milieu en rouge ce qu'il fait le lendemain,
  à gauche les heures de 8 h à 23 h où il trace des flèches, et un bloc
  « enfants » de 17 h à 23 h. Maquettes validées (« génère l'APK »).
- Onglet « À faire » refait : vue « En fond » (la matrice, un toucher
  choisit pour demain, un appui long modifie), bac « À placer » avec
  « Piocher » et « Remplir », journée heure par heure (8 h – 23 h,
  heures régulières) où l'on glisse les choses du bac ; appui long pour
  déplacer un bloc, tirer son bas pour la durée, toucher un bloc pour
  répondre ou le modifier, toucher une heure vide pour un impératif ou
  un créneau fixe. Créneaux fixes qui reviennent chaque semaine
  (« Enfants 17 h – 23 h »), grisés, contournés par « Remplir », sans
  notification. Base en version 4. Les horaires d'école du tableau sont
  un simple mémo : pas repris.
- APK fabriqué à la demande de Paul.

## APK n° 13 (1.0.0+13) : grande simplification

Fabriqué à la demande de Paul le 26/10/2026.

- Paul : « l'appli est devenue un peu trop compliquée, il y a des boutons
  et des bandeaux partout ». Revue complète et comparaison avec les
  applis du moment (Structured : journée en ligne du temps ; Sunsama :
  rituel du soir et alerte quand la journée déborde ; Things 3 : listes
  sobres, cases à cocher). Maquettes « version simple » validées avec ses
  corrections : Important et Urgent gardés, sur une ligne (pas
  d'étoile) ; pas de « sans heure » : une chose de la to-do prend une
  heure quand on la case, avec ses deux notifications.
- Codé : trois onglets (Aujourd'hui, To-do, Stats) ; « Mes questions »
  et « Créneaux fixes » passent dans les Réglages, refaits en lignes
  simples. Aujourd'hui : questions en lignes compactes (répondue = une
  pastille), puis « Ma journée » (heure, rond à cocher, texte). To-do :
  une seule liste triée toute seule, barre « Ajouter… » (« Papiers
  1 h »), bouton « Préparer demain ». Préparer demain en 2 étapes :
  choisir (jauge « Choisi : 4 h 15 sur 7 h de libre », orange puis
  rouge) puis caser (glisser sur une heure ou « Caser pour moi » ;
  « Terminer » case le reste, ce qui ne rentre pas retourne dans la
  to-do). Le rappel du soir ouvre « Préparer demain ». Supprimés : la
  matrice en 4 cases, le bac, « Piocher », « En fond », les blocs en
  cartes et les textes d'aide permanents. Version 1.0.0+13 prête.

## APK n° 14 (1.0.0+14) : les deux toi

Fabriqué à la demande de Paul le 26/10/2026 (« je teste ça pour
demain »).

- Idée de Paul, inspirée de la série « Severance » : « je décide le soir
  ce que le moi de demain va faire, deux personnes distinctes ». Puis :
  une intro, l'ascenseur, une animation au passage de décideur à
  exécutant, les plages horaires de chacun, un compte rendu en fin de
  journée, le style informatique à l'ancienne pour l'exécutant.
  Maquettes (pages « Thème v2 » et « Les deux toi ») : Paul « adore le
  concept ». On garde l'idée, rien de la série (ni nom, ni logo).
- Codé : intro en 3 pages (« Il y a deux toi », les heures de chacun sur
  un cadran de 24 h, les notifications), montrée une fois, y compris à
  ceux qui avaient déjà vu l'ancienne bienvenue. Le jour (plage de
  l'exécutant = début / fin de journée), Aujourd'hui passe en terminal
  rétro (VT323 + IBM Plex Mono, bleu-vert sur noir, lignes de balayage,
  curseur) : la chose en cours en grand avec Pas fait · Reporter · Fait,
  le mot d'hier soir, les « ordres du jour », « [ COMPTE RENDU ] ». Le
  soir (rappel du soir → fin du soir, 23 h par défaut), accent ambre :
  ce que le toi du jour remonte, « Préparer demain ». Préparer demain se
  termine par « Un mot pour toi, demain ? » puis l'ascenseur (SOIR ↓
  JOUR). Premier passage de la journée dans l'appli : l'ascenseur et
  « BONJOUR. 4 TÂCHES REÇUES. » Compte rendu : score, ce qui revient
  dans la to-do, un mot pour le décideur, « [ FIN DE SERVICE ] » (ascenseur
  vers le soir). Notifications : le matin « Ta journée t'attend », en fin
  de journée « Fin de service », le soir « Et demain, tu fais quoi ? ».
  Logo : le « rond dissocié » (ambre en haut à gauche, bleu-vert en bas
  à droite). Réglages : section « Les deux toi ». 89 tests.


## Après l'APK n° 14 : l'intro raconte le pourquoi (26/10/2026)

- Paul : retirer « Ils ne se croisent jamais. Ils se laissent des
  mots. », ajouter un petit contexte (tu voulais prendre ta vie en main,
  ça ne marchait pas, tu t'es séparé en deux), et une animation du logo
  (un rond entier qui se sépare en deux couleurs). Maquette
  (https://claude.ai/artifact/6uwN74rtwMFmdVsCiuppJ7) avec trois textes ;
  comparaison avec la série. Paul choisit le texte B (« le même toi
  décidait et faisait »), sans être convaincu par la formulation : à
  retravailler plus tard.
- Codé : page 1 de l'intro en deux temps (environ 12 secondes, toucher
  l'écran ou le bouton passe à la fin) : le pourquoi s'écrit ligne par
  ligne sous un rond blanc ; sur « Alors tu as séparé les deux. », le
  rond se fend de haut en bas, ses moitiés s'écartent et prennent leurs
  couleurs ; puis « Il y a deux toi », « Le soir, l'un décide », « Le
  jour, l'autre exécute » et le bouton « Faire connaissance ». Deux
  captures de plus (au moment de la coupe, petit téléphone).

## APK n° 15 (1.0.0+15) : le parcours de première ouverture (26/10/2026)

- Maquette refaite avec Paul en plusieurs tours
  (https://claude.ai/artifact/6uwN74rtwMFmdVsCiuppJ7).
- Intro : « Tu **savais** quoi faire, mais tu ne le faisais pas. Le même
  **TOI** décidait et faisait… » (les mots tombent en gros avec leur
  phrase) ; long silence, le rond tremble, se fend, onde de choc, flash,
  l'écran secoue, puis les moitiés s'éloignent lentement (3 fois plus
  lent qu'avant). « Il y a **deux** toi » (« deux » aux deux couleurs).
  « Le soir, le décideur planifie. Le jour, l'exécutant… s'exécute. »
  Bouton « Je décide ».
- Ascenseur refait : portes par-dessus l'écran, afficheur DÉCIDEUR /
  EXÉCUTANT qui défile dans le sens de la flèche. Portes ouvertes, le
  « Bonjour » seul, puis le reste. Après l'intro, il monte chez le
  Décideur, sur sa to-do.
- To-do : ajout en haut avec Important et Urgent, « Ma to-do » en 4
  cases toujours visibles (chaque case défile seule), « Bonjour,
  Décideur. ». Appui long sur une chose : faite.
- Écran de l'Exécutant beaucoup plus calme (Paul : « trop vert, trop
  informatique ancien ») : style habituel, accent bleu-vert, une seule
  touche de terminal (le mot du Décideur), la chose en cours en grand,
  la journée en calendrier. Le compte rendu reste en terminal.
- « Préparer demain » finit par « Transmis à l'Exécutant » (plus
  d'ascenseur à ce moment-là).
- Après l'APK n° 15 : maquette des questions liées (piste B), mise de
  côté (`docs/idees.md`) ; vidéo de l'intro faite depuis la maquette ;
  autre nom envisagé (Binôme, Tandem, Moitiés…), Paul garde « Ouinon »
  pour l'instant.
- Changer de toi à la main (Paul) : toucher « DÉCIDEUR » / « EXÉCUTANT »
  en haut à gauche, l'ascenseur fait le passage. Horaires de base de la
  journée : 8 h – 20 h (au lieu de 9 h – 19 h), réglables dès l'intro
  (page « Qui est là, et quand ? ») et dans les Réglages. Envoyé dans
  l'APK n° 16 (1.0.0+16, 26/10/2026).
- Intro, page 3 refaite (Paul : moins de terminal) : « Les deux TOI ne
  se parlent pas. » (TOI aux deux couleurs), « Le Décideur planifie.
  Chaque matin, l'Exécutant reçoit ses ordres », puis les notifications
  qui font le lien, chacune à son heure. Maquette de l'anneau des
  plages à glisser, sans repos, et noms pour le bouton de fin d'intro :
  https://claude.ai/artifact/RCSH1LPmay7wUhQSqPLGZs (en attente de Paul).
- Style revu avec Paul (26/10/2026) : « trop rond ». Maquettes
  (https://claude.ai/artifact/XGcBHpYKyiyNqGoHAdsPE6) : Paul refuse les
  styles trop carrés pour le Décideur (plan, pupitre ambre, carnet) et
  choisit **D · Le tableau** : la to-do dessinée comme sur son tableau
  blanc (une croix, sans cases), arrondis doux (14), Important / Urgent
  en petits ronds. L'Exécutant passe en **terminal sobre** (il aime le
  mélange texte rond et touches d'ordinateur) : noir bleuté, étiquettes
  et heures en police de terminal, chose en cours en gros caractères de
  vieil écran, touches carrées. Onglets dans l'ordre To-do · Aujourd'hui
  · Stats (on liste, on fait, on regarde), en bas, sans pilule ; une
  petite phrase sous chaque titre.
- Envoyé dans l'APK n° 17 (1.0.0+17, 26/10/2026) : nouveau style,
  ordre des onglets, phrases, page 3 de l'intro.
- Bouton de fin d'intro : « Répartir les rôles » (choix de Paul, à la
  place de « Je décide »).
- L'anneau des rôles (maquette validée par Paul) : toujours plein, plus
  de « repos » ; la journée à l'Exécutant, le reste au Décideur ; on
  glisse les deux ronds. Dans l'intro et dans les Réglages (« Répartir
  les rôles »). La « fin du soir » disparaît ; « Heure du rappel du
  soir » reste réglable.
- Paul : « à quoi sert l'anneau ? » Répartition des fonctions refaite
  avec lui : le Décideur planifie et regarde (To-do, Préparer demain,
  créneaux, questions, Stats, compte rendu remonté) ; l'Exécutant fait
  et répond (Aujourd'hui, questions du jour, compte rendu de fin de
  journée). Décision : **le toi suit l'onglet**, ascenseur au premier
  passage de la journée dans chaque sens ; plus d'anneau ni de bouton
  ⇅ ; « Modifier » chez l'Exécutant monte chez le Décideur ; intro en
  2 pages (bouton « Qui fait quoi ? ») ; Réglages : début et fin de la
  journée. Envoyé dans l'APK n° 18 (1.0.0+18).
- Retours de Paul sur l'APK n° 18 : plus de barre d'ajout, un bouton
  « Ajouter » qui ouvre un formulaire d'une page (titre, durée,
  Important / Urgent, heure imposée ; base v5, colonne `heure`) ;
  « Planifier » devient un onglet (toute la liste, glisser sur la
  journée de demain, blocs orange translucides) ; deux rôles séparés
  avec leurs onglets (Décideur : To-do · Planifier · Stats ; Exécutant :
  Ma journée) et un bouton Ascenseur bien visible ; l'Exécutant peut
  ajouter une chose ou changer une heure. Barrières entre les rôles :
  plus tard.
- Envoyé dans l'APK n° 19 (1.0.0+19, 26/10/2026).

- 26/10/2026 (après l'APK n° 19) : intitulés des cases de la To-do en étiquettes (majuscules espacées, soulignées à leur couleur) pour bien les séparer du contenu (retour de Paul).
- 26/10/2026 : noms des choses de la To-do en écriture normale (seuls les intitulés des cases restent en gras). APK n° 20 (1.0.0+20).
- 26/10/2026 : barre de l'Exécutant sans onglet « Ma journée » (seul l'ascenseur reste) ; questions gérées dans Stats chez le Décideur (« Tes questions » en haut, « + Ajouter »), retirées des Réglages (retours de Paul).
- 26/10/2026 : APK n° 21 (1.0.0+21).
- 27/10/2026 : refonte complète avec Paul (« l'appli c'est le bordel ») :
  maquette « Ouinon, le rituel du soir » validée, puis appliquée. Plus
  d'onglets ni de rôles : accueil « Bonsoir. » avec l'anneau du jour,
  « Préparer demain » (ascenseur) en 2 étapes (aimants dans la matrice
  d'Eisenhower, puis la journée entière dans l'écran, glisser sans appui
  long), « Demain est prêt. », « Mon suivi » pour les questions et les
  stats. APK n° 22 (1.0.0+22).
- 27/10/2026 : Paul a l'impression d'avoir perdu le contrôle. On repart
  de zéro, écran par écran, dans `docs/cahier.md`. Écran 1 « Mes
  questions » validé puis codé seul, avec un thème clair « pas IA ».
  L'ancienne appli est rangée dans `ancien/`. APK n° 23 (1.0.0+23) à
  fabriquer avec l'accord de Paul.
- 27/10/2026 : Paul veut l'appli complète tout de suite, au style Orbite
  (sombre, orange translucide, Michroma + IBM Plex Sans Condensed). Retour
  au code complet de l'APK n° 21 (sans rôles ni ascenseur), bandeau en bas :
  To-do · Aujourd'hui · Suivi · Demain ; page Demain sans défilement ni
  appui long ; une notification ratée reste jusqu'à la suivante. APK n° 24.
- 27/10/2026 : logo aux couleurs d'origine (vert citron, corail) ; familles
  de questions (Sport = Cardio + Muscu, additionnées dans le Suivi, base
  version 6) ; Aujourd'hui : la journée en haut, les questions en bas ;
  to-do : doublons signalés en tapant (mots-clés sans accents) et micro
  pour dicter (« me couper les ongles et ça prendra environ 15 minutes »).
  Version 1.0.0+25. Gamification « deux toi » à concevoir avec Paul.
- 27/10/2026 : « Famille » devient « Groupe » (questions évaluées
  ensemble) ; toucher un groupe dans Suivi ouvre son analyse (moyenne,
  courbe, les deux courbes superposées, puis le détail de chaque question).
  To-do : on tire une chose vers la languette « Aujourd'hui » au milieu à
  droite, elle est casée aujourd'hui (plus d'appui long pour « fait »).
  Version 1.0.0+26.

## APK n° 27 (1.0.0+27) : le jeu « Synchro », étape 1, puis retiré

- 27/10/2026 : points, bandeau du jeu en haut, niveaux, pages Réserve,
  Missions, Analyse, Plan de vol (`docs/jeu.md`). APK n° 27 envoyé.
- 28/10/2026 : Paul retire tout le jeu (« c'était pas une bonne idée »).
  Le code revient à 1.0.0+26 (noms To-do, Aujourd'hui, Suivi, Demain).
- 28/10/2026 : nouvelle demande : trois onglets seulement, dans l'ordre
  To-do (matrice d'Eisenhower, glisser vers la droite dans un bandeau
  « Aujourd'hui »), Aujourd'hui (la liste et le planning de la journée),
  Questions (celles du jour, « + » et formulaire). Stats et le reste dans
  les réglages. Style futuriste, mini-animations à chaque action.
  Maquette : https://claude.ai/artifact/RZnQ8gh7CKAG8RZALSa8AQ (à valider).

## APK n° 28 (1.0.0+28) : trois onglets, deux couleurs, Oxanium

- Maquette validée par Paul (28/10/2026) : To-do, Aujourd'hui, Questions ;
  stats et le reste dans les Réglages. Couleurs ramenées à deux,
  translucides : orange et vert d'eau (meilleure réponse vert d'eau,
  moins bonne orange, milieu gris). Police des titres : Chakra Petch.
- Les 7 améliorations validées : « Annuler » 4 s après chaque action ;
  vibration légère ; déplacer un bloc en le glissant ; pastille animée
  sur l'onglet Aujourd'hui ; questions pas encore arrivées plus pâles ;
  nombre et temps total sous chaque case ; micro et doublons gardés.
- Animations : arrivée des pages avec un trait qui balaie, choses qui se
  dessinent en apparaissant, traînée vers le bandeau « Aujourd'hui »,
  blocs qui tombent à leur place, coche qui rebondit, réponse verrouillée
  avec une onde, anneau qui se remplit.
- Retirés : l'ancien écran Aujourd'hui (pages par jour), « Préparer
  demain » et l'intro des deux toi. APK n° 28 envoyé le 28/10/2026.
- Police : une seule partout, **Oxanium** (Paul a choisi la n° 2 parmi
  six propositions, 28/10/2026). Les anciennes polices (Chakra Petch,
  IBM Plex, Michroma, VT323, Unbounded, Figtree) sont retirées.
- Logo passé aux deux couleurs de l'appli (vert d'eau à gauche, orange
  à droite, fond noir de l'appli) ; texte un peu plus petit dans les
  cases de la to-do (28/10/2026).

## Après l'APK n° 28 : retours de Paul

- 28/10/2026 : dans le planning d'Aujourd'hui, glisser un bloc le déplace
  sans jamais changer sa durée (la poignée de durée, qui se déclenchait
  sur les petits blocs, est retirée). Toucher un bloc ouvre sa fiche
  (heure, durée, texte) ; un rond à gauche du bloc sert à cocher « fait ».
- 28/10/2026 : toucher un créneau fixe (« Enfants ») dans le planning
  ouvre sa fiche pour le modifier.
- 28/10/2026 : dans l'onglet Questions, toucher une question (pas ses
  réponses) ouvre sa fiche : en haut l'heure, les jours, les réponses,
  le groupe et « Modifier la question » ; en dessous ses stats (séries,
  anneau, courbe, jours de la semaine, 6 mois, calendrier).
- 28/10/2026 : animation des réponses refaite (« pas hyper fluide ») :
  la réponse s'affiche tout de suite (sans attendre la base), la choisie
  « claque », les autres s'effacent, puis elle se transforme elle-même en
  pastille en glissant à gauche, « Changer » apparaît et l'onde part ; la
  hauteur ne bouge plus. Changement d'onglet allégé (fondu sans
  reconstruire les pages).
- 28/10/2026 : le petit encadré du bas (avec « Annuler ») disparaît
  bien après 4 secondes. Dans Aujourd'hui, le rond d'un bloc : fait
  (coche vert d'eau), puis pas fait (croix orange), puis sans réponse.
  Notifications du planning : une seule par chose, à son heure, avec
  « Pas fait · Fait » (plus de notification de fin ni de « Reporter » ;
  le réglage « début et fin » est retiré).
- APK n° 29 (1.0.0+29) envoyé le 28/10/2026 avec toutes ces corrections.
- 28/10/2026 : to-do, second bandeau à droite, « Fait », sous
  « Aujourd'hui » : une chose qu'on y tire est faite aujourd'hui (posée
  dans la journée de « maintenant moins sa durée » à maintenant, au
  quart d'heure le plus proche, cochée, comptée dans les stats)
  et sort de la to-do ; « Annuler » la remet.
- 28/10/2026 : nouvelle question : réponses « Fait » (meilleure) et
  « Pas fait » écrites par défaut, modifiables.
- 28/10/2026 : une chose prévue restée sans réponse compte « pas fait »
  le lendemain (pas de réponse = reportée) et revient dans la to-do ; à
  l'ouverture de l'appli et au retour dedans. Les questions ne changent
  pas.
- 28/10/2026 : Questions : toucher la réponse déjà donnée l'efface et
  rouvre les boutons, prêts pour une autre (un seul toucher au lieu de
  deux).
- 28/10/2026 : « Redemander le lendemain si pas fait » : une question qui
  ne revient pas tous les jours, sans réponse ou avec la moins bonne,
  revient le lendemain (notification « Me raser ? (de lundi) », ligne
  « de lundi » dans Questions), jusqu'à « fait » ou son prochain jour.
  Interrupteur dans le formulaire (automatique). Base version 7.
- APK n° 30 (1.0.0+30).
- 28/10/2026 : ménage des Réglages (sans doublon avec les onglets) :
  Suivi (Statistiques, qui listent toutes les questions ; plus de
  « Toutes les questions » ni de bouton « Ajouter » en double), Ma
  journée (début, fin, créneaux fixes), Notifications (rappel du soir en
  une ligne : interrupteur et heure ; bilan du dimanche ; essayer),
  Données de test. Retirés : « Prochaine question », l'ancienne liste
  « Mes questions ».
- 28/10/2026 : tous les formulaires tiennent sur un écran sans défiler
  (question : intitulés en petit, heure et raccourcis des jours sur une
  ligne, pause et suppression en haut ; champs plus serrés partout ;
  textes d'aide permanents retirés). « Impératif » devient
  « Rendez-vous ».
- 28/10/2026 : « Redemander le lendemain » éteint par défaut pour une
  nouvelle question (modifiable).
- APK n° 31 (1.0.0+31) : réglages rangés, formulaires sur un écran.
- 28/10/2026 : Réglages, « Ta journée : 8 h – 20 h » en une seule ligne
  (on choisit le début puis la fin).
- APK n° 32 (1.0.0+32).
- 28/10/2026 : to-do, les 4 cases présentées pareil (plus de case
  orange ni de case grisée). Appui long sur une chose, puis glisser dans
  une autre case : elle change de case, Important et Urgent suivent
  (avec « Annuler »).

