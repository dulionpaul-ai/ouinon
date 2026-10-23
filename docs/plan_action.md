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
5. [ ] Stats : codées (bilan 7 j / 30 j / tout, semaine par semaine,
   selon le jour, calendrier modifiable, liens même jour et lendemain).
   Reste : les juger avec de vraies réponses.
6. [x] Style et logo : « Nuit ronde », toujours sombre, polices
   Unbounded + Figtree ; logo n° 3, icônes Android et iPhone.
7. [x] Retours de Paul sur l'APK n° 4 intégrés dans l'APK n° 5
   (22/10/2026) : cadran sans clavier, ordre des réponses inversé
   partout, nombre de réponses modifiable, « + Autre », page Jour qui
   glisse. APK n° 6 : logo réduit de 5 %. APK n° 7 : heure précise
   (notifications du soir pas reçues chez Paul), prochaine question dans
   les Réglages. APK n° 8 (23/10/2026) : moment envoyé à Android en
   temps universel (une question de 7 h 01 arrivait à 8 h 01) ;
   questions rangées par heure. Dans le code depuis : page Stats
   centrée sur les croisements, notification revue (sans date, sans
   couleur, nouveau logo blanc). Prochain APK : `version: 1.0.0+9`,
   **toujours demander à Paul avant de le fabriquer.**
8. [ ] Test longue durée par Paul (2 à 3 semaines de vraies réponses),
   corrections.
9. [ ] Plus tard, avec l'accord de Paul : iPhone (TestFlight), sauvegarde,
   fiches Play Store et App Store.

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
  dit sur combien de jours elle s'appuie.
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
