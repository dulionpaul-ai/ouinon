# Plan d'action

Ordre du risque : prouver d'abord que la réponse depuis la notification
marche, appli fermée, sur le téléphone de Paul. Détail de ce qui a été
fait, version par version : `docs/historique.md`.

1. [x] Cadrage : questions à Paul et choix enregistrés le 22/10/2026
   (`docs/revue_produit.md`).
2. [x] Socle : projet Flutter 3.47.7 (`fr.ouinon.app`, « Ouinon »),
   base SQLite, vérifications GitHub Actions, clé de test Android,
   Codemagic préparé.
3. [x] Notifications avec boutons : chaque question à son heure et ses
   jours, 2 ou 3 boutons, la moins bonne à gauche, réponse enregistrée
   appli fermée, 14 jours programmés, rappel « continuer », « Essayer
   une notification » dans les Réglages. **Confirmé par Paul sur son
   téléphone le 22/10/2026 (APK n° 5)** : la réponse donnée depuis la
   notification est bien enregistrée dans l'appli.
4. [x] Écrans : Jour (pages qui glissent), Questions, Nouvelle question
   / Modifier (suggestions modifiables, cadran d'heure, jours en
   ronds), Réglages, 4 questions de départ.
5. [ ] Stats : refaites en graphiques (23/10/2026, après l'APK n° 9) :
   découvertes trouvées seules (courbes qui se ressemblent, décalées de
   0 à 3 jours, ou à l'inverse), comparateur de deux courbes avec
   décalage, nuage de points, carte de tous les liens, anneaux, barres,
   grille de 6 mois ; animés quand on s'arrête dessus. Bouton « Ajouter
   6 mois de test » dans les Réglages pour les essayer. Reste : avis de
   Paul, puis vraies réponses.
6. [x] Style et logo : « Nuit ronde », toujours sombre, polices
   Unbounded + Figtree ; logo n° 3, icônes Android et iPhone.
7. [x] Retours de Paul sur l'APK n° 4 intégrés dans l'APK n° 5
   (22/10/2026) : cadran sans clavier, ordre des réponses inversé
   partout, nombre de réponses modifiable, « + Autre », page Jour qui
   glisse. APK n° 6 : logo réduit de 5 %. APK n° 7 : heure précise
   (notifications du soir pas reçues chez Paul), prochaine question dans
   les Réglages. APK n° 8 (23/10/2026) : moment envoyé à Android en
   temps universel (une question de 7 h 01 arrivait à 8 h 01) ;
   questions rangées par heure. APK n° 9 (23/10/2026) : notification
   revue (sans date, sans couleur, nouveau logo blanc), séries, question
   principale et stats en classement, bilan du dimanche. APK n° 10
   (23/10/2026) : stats en graphiques, données de test, numéro d'APK
   dans les Réglages.
8. [ ] Planning et liste « À faire » (demandes de Paul du 24/10/2026),
   dans l'APK n° 11 (fabriqué avec son accord). Liste en 4 cases
   d'Eisenhower, impératifs, « Remplir ma journée », deux notifications
   (début, fin). APK n° 12 : écran calqué sur son tableau blanc (En
   fond → bac « À placer » → journée heure par heure, glisser-déposer,
   créneaux fixes). Prochain APK : `version: 1.0.0+13`, **seulement avec
   l'accord de Paul**. Planning d'origine : onglet « Demain », choses prévues avec heure et
   durée, rappel à l'heure pile « Pas fait · Reporter · Fait » (reporter
   = une heure plus tard), rappel du soir pour préparer le lendemain,
   « Remettre demain », stats du planning (et liens avec les
   questions). Seulement aujourd'hui et demain pour l'instant ; un autre
   jour de la semaine viendra peut-être ensuite. Reste : avis de Paul.
8b. [ ] Les deux toi (26/10/2026, APK n° 14) : intro, mode exécutant
   rétro le jour, mode décideur ambre le soir, ascenseur, mots entre les
   deux, compte rendu, nouveau logo. Reste : avis de Paul après son test
   du 27/10. APK n° 15 (26/10/2026) : intro dramatique, ascenseur
   à afficheur, Décideur en 4 cases, Exécutant calme avec calendrier. Idées pour plus tard : `docs/idees.md` (intro qui raconte
   le pourquoi, notes échangées avec soi-même). En réserve : plan verrouillé le jour (appui long pour
   « remonter »), écran « Hors service » la nuit, stat « tu prévois
   20 % de trop » qui ajuste la jauge, numéro de journée dans le compte
   rendu. APK n° 16 : changer de toi à la main, journée 8 h – 20 h.
   APK n° 17 : style « tableau » et « terminal sobre », onglets
   To-do · Aujourd'hui · Stats.
   APK n° 18 : le toi suit l'onglet, intro en 2 pages.
   APK n° 19 : deux rôles séparés, Ascenseur, Ajouter, Planifier.
   APK n° 22 (27/10/2026) : refonte « rituel du soir » (plus d'onglets
   ni de rôles ; accueil, Préparer demain en 2 étapes, Demain est
   prêt, Mon suivi). Prochain APK : `version: 1.0.0+23`, seulement
   avec l'accord de Paul.
9. [ ] Plus tard (critique du 23/10/2026) : sauvegarde dans un
   fichier, mode « expérience » (tester une habitude 14 jours), objectifs
   tout prêts au démarrage (« Mieux dormir »…), planning sur toute la
   semaine.
10. [ ] Test longue durée par Paul (2 à 3 semaines de vraies réponses),
   corrections.
11. [ ] Plus tard, avec l'accord de Paul : iPhone (TestFlight), sauvegarde,
   fiches Play Store et App Store.
12. [ ] Le jeu « Synchro » (`docs/jeu.md`, validé le 27/10/2026) :
   [x] étape 1, les points, le bandeau et les niveaux (APK n° 27) ;
   [ ] étape 2, la page « Unité » (personnage, stade, jauges) ;
   [ ] étape 3, défis du jour et insignes ;
   [ ] étape 4, implants, cinématiques, prologue et chapitres.

## Relecture du plan (22/10/2026) : risques et corrections

- **Notification sans réponse le jour même.** Une notification qui se
  répète toute seule ne sait pas de quel jour elle parle, et on ne peut
  pas en sauter une si la question a déjà sa réponse. Correction :
  chaque notification est programmée une par une pour les 14 prochains
  jours, avec la question et le jour à l'intérieur. Les jours déjà
  répondus sont sautés. Tout est reprogrammé à chaque ouverture de
  l'appli et à chaque réponse (même depuis la notif).
- **Paul ne touche à rien pendant 14 jours.** Les notifications
  s'arrêteraient. Correction : la dernière notification programmée
  rappelle d'ouvrir l'appli ; une seule réponse suffit à repartir pour
  14 jours.
- **iPhone : 64 notifications programmées au maximum.** Correction :
  sur iPhone, le nombre de jours programmés est réduit selon le nombre
  de questions.
- **Heure exacte.** D'abord, heure approximative pour éviter une
  autorisation. Erreur : Android peut alors retarder une notification
  de plusieurs heures (soir du 22/10/2026, rien reçu chez Paul).
  Correction (APK n° 7) : heure précise avec l'autorisation « Alarmes et
  rappels », demandée une fois et dans les Réglages ; heure
  approximative seulement si elle est refusée.
- **Faux liens avec 7 jours.** Choix de Paul : croisements dès 7 jours
  communs. Correction : on demande en plus au moins 3 jours de chaque
  côté de la comparaison et un écart d'au moins 20 points, et la phrase
  dit sur combien de jours elle s'appuie. Depuis les graphiques
  (23/10/2026) : ressemblance des courbes dès 14 jours communs et 30 %,
  le nombre de jours toujours affiché.
- **Changer le nombre de réponses d'une question.** D'abord figé à la
  création ; Paul a demandé de pouvoir le changer. Décision : on
  convertit l'historique (de 2 à 3, la moins bonne reste la moins
  bonne ; de 3 à 2, les réponses du milieu sont effacées, après
  confirmation).
- **Supprimer une question.** Proposer d'abord « Mettre en pause »
  (garde l'historique) ; la suppression efface aussi ses réponses,
  après confirmation.
- **Accès GitHub.** Bloqué au début ; réglé par Paul le 22/10/2026.

## À faire par Paul

- Répondre aux questions pendant quelques semaines, puis donner son avis
  sur les stats.

## Relecture du planning (24/10/2026) : ce qui a changé par rapport à la première idée

- **Aujourd'hui aussi, pas seulement demain.** Si on oublie de préparer
  la veille, ou qu'un rendez-vous tombe le matin, il faut pouvoir
  l'ajouter le jour même ; sinon la journée est perdue pour le planning.
  On reste sur aujourd'hui et demain (pas le reste de la semaine).
- **« Fait » à l'heure pile est souvent trop tôt.** La notification
  reste dans la barre ; on répond quand c'est fait, ou on reporte. Sans
  réponse, la chose reste « sans réponse » (comme une question) et ne
  compte pas dans le pourcentage, plutôt que d'être comptée « pas
  faite ».
- **Reporter : une heure après l'appui**, pas une heure après l'heure
  prévue (on reporte à 18 h 20, ça revient à 19 h 20). Jamais après
  minuit : la chose reste alors à remettre au lendemain.
- **Fin de journée : on propose, on n'impose pas.** Pas de report
  automatique au lendemain (le planning se remplirait de choses
  abandonnées) : dans « Demain », une liste « Pas fait aujourd'hui »
  avec « Remettre demain ».
- **Rappel du soir utile** : il dit où en est la journée (« 3 faits sur
  5 ») et ce qui est déjà prévu le lendemain, à 21 h 30 par défaut
  (après les questions de 21 h), réglable ou coupable.
- **Ajouter vite** : ce qu'on prévoit souvent revient en raccourci (avec
  sa durée) ; l'heure proposée suit la dernière chose prévue ; un
  horaire qui en croise un autre est signalé.
- **Stats** : la part faite chaque jour devient une courbe comme une
  question, donc l'appli cherche aussi ses liens avec les questions ;
  plus selon le moment, le jour, la charge de la journée, et ce qui est
  le plus reporté. Toujours des constats, jamais de conseil.

## Liste « À faire » et Eisenhower (24/10/2026) : choix et pistes

- **Noter vite, trier après** : texte et durée d'abord ; « Important ? »
  et « Urgent ? » en deux touchers plutôt qu'une grille à viser.
- **Urgent** : coché à la main, ou déduit d'une date limite à moins de
  2 jours (une chose change de case avec le temps).
- **Noms des cases** pour la vie perso : D'abord, À planifier, Vite
  fait, Peut-être jamais (« déléguer » est rarement possible).
- **Impératifs et liste** : les impératifs (heure fixe) se posent à la
  main ; la liste se place dans les trous.
- **« Remplir ma journée », version 1** (à améliorer avec Paul) : entre
  le début et la fin de journée des Réglages, un quart d'heure de marge
  entre deux choses, horaires au quart d'heure ; ordre : dernier jour
  d'une date limite, D'abord, À planifier, Vite fait (date limite la
  plus proche, puis la plus ancienne) ; « Peut-être jamais » jamais
  placé tout seul ; proposition à valider, ce qui ne rentre pas est dit.
  Pistes : remplir le plus long d'abord pour moins de trous, garder des
  pauses, tenir compte du taux habituel (« tu fais 63 % de ce que tu
  prévois ») pour moins charger, découper les longues choses, heures
  préférées (sport le matin…).
- **Deux notifications** (choix de Paul) : au début « C'est l'heure »
  avec « Reporter », à la fin « C'est fait ? » avec « Pas fait ·
  Reporter · Fait ». Réglable : une seule.
- **Rien ne se perd** : pas faite, une chose de la liste revient « à
  placer » d'elle-même ; faite, elle sort de la liste.

## Le tableau blanc de Paul (24/10/2026)

Trois colonnes : « en fond » (la matrice d'Eisenhower), ce qu'il fait
le lendemain (en rouge, sans heure), et les heures de 8 h à 23 h où il
trace des flèches ; plus des blocs de contrainte (« enfants » 17 h –
23 h). L'appli suit le même chemin : En fond → bac « À placer » →
journée heure par heure (glisser-déposer). Pistes : faire défiler plus
finement pendant un glisser, placer plusieurs choses dans un même
créneau (comme ses crochets), glisser d'un jour à l'autre.

## Simplification (25/10/2026)

Trois onglets : **Aujourd'hui** (questions compactes, ma journée),
**To-do** (une liste, ajout rapide, « Préparer demain »), **Stats**.
Préparer demain = choisir (jauge de temps libre) puis caser (glisser ou
« Caser pour moi »). Réglages en lignes simples, avec « Mes questions »
et « Créneaux fixes ». Important / Urgent gardés sur une ligne dans
l'écran d'une chose ; tri automatique. APK n° 13 envoyé le 26/10/2026.
Reste : avis de Paul. Prochain APK : `version: 1.0.0+14`, **seulement
avec son accord**. Pistes : alléger
aussi la page Stats (comparateur et carte des liens derrière un
toucher).
