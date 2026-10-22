# Plan d'action

Ordre du risque : prouver d'abord que la réponse depuis la notification
marche, appli fermée, sur le téléphone de Paul.

1. [x] Cadrage : questions à Paul et choix enregistrés le 22/10/2026
   (`docs/revue_produit.md`).
2. [x] Socle : fait le 22/10/2026. Projet Flutter 3.47.7
   (`fr.ouinon.app`, « Ouinon »), structure Trousse à Pharma, base
   SQLite (questions, réponses), vérifications GitHub Actions (format,
   analyse, tests), clé de test Android stable, Codemagic préparé.
3. [ ] Notifications avec boutons : codé le 22/10/2026 (chaque question
   à son heure et ses jours, 2 ou 3 boutons, réponse enregistrée appli
   fermée, programmation 14 jours d'avance, rappel « continuer »,
   bienvenue + autorisation au premier lancement, bouton « Essayer une
   notification » dans les Réglages). **Premier APK à tester par Paul**
   (Android) : APK 1.0.0 (9 Mo) envoyé le 22/10/2026. Pas d'émulateur
   dans la session : le vrai test des boutons appli fermée se fait sur
   le téléphone de Paul.
4. [ ] Écrans : codés le 22/10/2026 : Aujourd'hui (avec les jours
   passés), Mes questions (ajout, modification, ordre, pause,
   suppression), 4 questions de départ. À tester par Paul.
5. [ ] Stats : codées le 22/10/2026 : fiche d'une question (bilan
   7 j / 30 j / tout, semaine par semaine, selon le jour, calendrier
   modifiable), liens entre questions (même jour et lendemain). À tester
   par Paul avec de vraies réponses.
6. [ ] Style : première série (A, B, C) jugée trop « appli d'IA » par
   Paul le 22/10/2026. Nouvelle série ronde et moderne sur la même page
   (https://claude.ai/artifact/8wYzPghoUihjK5CGqjZQSg : D Bulles,
   E Galets, F Nuit ronde). Appliqué dans l'appli : D en clair, F en
   sombre, polices Unbounded + Figtree (APK n° 2). Le nom devient
   « Ouinon » (tout attaché). Logo : 4 pistes proposées le 22/10/2026
   (https://claude.ai/artifact/8JC7nnJjfsTQoX79W3FXtW : Croisement,
   Interrupteur, Oui | Non, Trois réponses). Reste : choix de Paul,
   puis icône de l'appli (Android et iPhone).
7. [ ] Test longue durée par Paul (2 à 3 semaines de vraies réponses),
   corrections.
8. [ ] Plus tard, avec l'accord de Paul : iPhone (TestFlight), sauvegarde,
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
  de questions (à traiter avec l'étape iPhone).
- **Heure exacte.** Android demande une autorisation spéciale pour
  l'heure à la seconde près, que le Play Store réserve aux réveils.
  Correction : heure « à quelques minutes près », sans autorisation
  spéciale.
- **Faux liens avec 7 jours.** Choix de Paul : croisements dès 7 jours
  communs. Correction : on demande en plus au moins 3 jours de chaque
  côté de la comparaison et un écart d'au moins 20 points, et la phrase
  dit sur combien de jours elle s'appuie.
- **Changer le nombre de réponses d'une question.** Rendrait
  l'historique faux. Correction : nombre figé à la création ; pour en
  changer, on crée une nouvelle question.
- **Supprimer une question.** Proposer d'abord « Mettre en pause »
  (garde l'historique) ; la suppression efface aussi ses réponses,
  après confirmation.
- **Accès GitHub.** Bloqué au début ; réglé par Paul le 22/10/2026
  (appli Claude installée sur le dépôt). Code envoyé, vérifications
  GitHub au vert.

## À faire par Paul

- Choisir un des 3 styles proposés (étape 6).
- Installer l'APK, autoriser les notifications, essayer une notification
  depuis les Réglages, puis répondre quelques jours.
