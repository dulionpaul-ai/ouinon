# Fonctionnement de Ouinon

## En deux mots

Repartie de zéro le 27/10/2026 (`docs/cahier.md`). Pour l'instant, un
seul écran : « Mes questions ». Chaque question est programmée en
notification sur le téléphone, à son heure et ses jours ; la
notification porte ses 2 ou 3 réponses en boutons ; un appui enregistre
la réponse dans la base SQLite du téléphone, même appli fermée. Rien ne
part sur internet.

## Code (`lib/`)

Depuis l'APK n° 24, c'est de nouveau l'appli complète (reprise de
l'APK n° 21), au style Orbite. Mis à jour le 27/10/2026 (APK n° 27).

| Fichier | Contenu |
|---|---|
| `screens/accueil_screen.dart` | La coque : bandeau du jeu en haut, pages au milieu (gardées en mémoire, arrivée en glissant), barre du bas : Réserve (to-do), Missions (aujourd'hui), Analyse (questions et stats), Plan de vol (demain). Reprogramme les notifications. |
| `widgets/bandeau_jeu.dart` | Le jeu « Synchro », étape 1 : niveau, stade, barre de points en segments, anneau de synchro du jour, points du jour ; « +N » qui s'envole ; écran du niveau suivant (`NiveauSuivant`, une fois par niveau) ; détail des points au toucher. |
| `utils/jeu.dart` | Calcul pur des points (`bilanJeu`) : rien n'est stocké, tout se recalcule depuis l'historique (choses faites, réponses, plans validés). Niveaux, stades, synchro, séries. Règles dans `docs/jeu.md`. |
| `data/preferences.dart` | Réglages ; `PrefsJeu` : soirs où le plan de vol a été validé, dernier niveau fêté. |
| `screens/todo_screen.dart` | La réserve en 4 cases ; tirer une chose vers la languette de droite la case aujourd'hui. |
| `screens/aujourdhui_screen.dart` | Missions du jour (avec leurs points), puis les questions. |
| `screens/stats_screen.dart`, `groupe_screen.dart`, `fiche_question_screen.dart` | Analyse : questions, groupes, courbes, liens. |
| `screens/preparer_screen.dart` | Plan de vol : la journée de demain sans défilement ; « Valider demain » compte pour le jeu. |
| `screens/edition_a_faire_screen.dart` | Nouvelle chose : doublons signalés, micro pour dicter. |
| `data/base.dart` | Base `ouinon.sqlite` (version 6) : questions (avec groupe), réponses, planning, liste, créneaux. |
| `data/notifications.dart` | Questions et planning ; réponse par bouton, même appli fermée. |
| `utils/` | Planification, familles (groupes), recherche, dictée, courbes, stats, dates. |

`ancien/` : l'appli à l'APK n° 22, mise de côté.

## Vérifications et compilation

Voir `docs/reprendre_le_projet.md` : `dart format`, `flutter analyze`,
`flutter test`, captures (`flutter test tool/captures_test.dart
--update-goldens`, police Roboto chargée depuis Flutter), puis l'APK.
