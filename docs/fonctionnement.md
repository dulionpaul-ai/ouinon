# Fonctionnement de Ouinon

## En deux mots

Repartie de zéro le 27/10/2026 (`docs/cahier.md`). Pour l'instant, un
seul écran : « Mes questions ». Chaque question est programmée en
notification sur le téléphone, à son heure et ses jours ; la
notification porte ses 2 ou 3 réponses en boutons ; un appui enregistre
la réponse dans la base SQLite du téléphone, même appli fermée. Rien ne
part sur internet.

## Code (`lib/`)

Mis à jour le 28/10/2026 (version 1.0.0+28) : trois onglets.

| Fichier | Contenu |
|---|---|
| `screens/accueil_screen.dart` | La coque : 3 onglets (To-do orange, Aujourd'hui vert d'eau, Questions orange), pastille animée sur Aujourd'hui, arrivée des pages en glissant avec un trait qui balaie. Reprogramme les notifications ; le rappel du soir ouvre la to-do. |
| `screens/todo_screen.dart` | Onglet 1 : les 4 cases (nombre et temps total), une chose tirée vers la droite sur le bandeau « Aujourd'hui » est choisie pour aujourd'hui (`choisitPour`) ; tirée sur le bandeau « Fait », elle est posée faite dans la journée d'aujourd'hui. Appui long puis glisser : elle change de case (Important et Urgent suivent). Avec « Annuler ». |
| `screens/journee_screen.dart` | Onglet 2 : deux pages, aujourd'hui et demain (`PageView`). « À placer » (le même bac pour les deux jours : toucher = casé au premier moment libre de ce jour, ou glisser sur une heure), puis la journée jusqu'à minuit (`GrilleJournee`) ; toucher le rond d'un bloc = fait / pas fait / sans réponse, toucher le bloc = sa fiche ; glisser un bloc le déplace sans changer sa durée ; toucher un créneau fixe = sa fiche ; remonter un bloc sur « À placer » lui enlève son heure. |
| `screens/questions_du_jour_screen.dart` | Onglet 3 : les questions du jour par heure (pas encore l'heure = plus pâle), réponse verrouillée avec une onde, « Changer », anneau, « + » ; toucher la question ouvre sa fiche (`fiche_question_screen.dart` : réglages en haut avec « Modifier la question », puis ses stats). |
| `widgets/vivant.dart` | Les pièces animées : `Apparition`, `Balayage`, `EnTete`, `BoutonRond`, `Etiquette`, `annonce` (message + vibration + Annuler), `BarreEspace`. |
| `screens/reglages_screen.dart` | Statistiques (toutes les questions), ma journée (heures, créneaux fixes), notifications (rappel du soir, bilan, essai), données de test. |
| `screens/stats_screen.dart`, `groupe_screen.dart`, `fiche_question_screen.dart` | Les stats (ouvertes depuis les Réglages). |
| `screens/edition_*_screen.dart` | Formulaires : question, chose (micro, doublons), rendez-vous, créneau. |
| `theme/app_theme.dart` | Le style « espace » : deux couleurs translucides (`AppTheme.orange`, `AppTheme.vertDeau`), `Teintes.avecAccent` ; une seule police, Oxanium. |
| `data/base.dart` | Base `ouinon.sqlite` (version 7) : questions (avec groupe, « redemander le lendemain »), réponses, planning, liste, créneaux. |
| `data/notifications.dart` | Questions et planning ; réponse par bouton, même appli fermée. |
| `utils/` | Planification, remplissage de la journée, familles (groupes), recherche, dictée, courbes, stats, dates. |

`ancien/` : l'appli à l'APK n° 22, mise de côté.

## Vérifications et compilation

Voir `docs/reprendre_le_projet.md` : `dart format`, `flutter analyze`,
`flutter test`, captures (`flutter test tool/captures_test.dart
--update-goldens`, police Roboto chargée depuis Flutter), puis l'APK.
