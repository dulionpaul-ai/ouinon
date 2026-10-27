# Fonctionnement de Ouinon

## En deux mots

Repartie de zéro le 27/10/2026 (`docs/cahier.md`). Pour l'instant, un
seul écran : « Mes questions ». Chaque question est programmée en
notification sur le téléphone, à son heure et ses jours ; la
notification porte ses 2 ou 3 réponses en boutons ; un appui enregistre
la réponse dans la base SQLite du téléphone, même appli fermée. Rien ne
part sur internet.

## Code (`lib/`)

| Fichier | Contenu |
|---|---|
| `main.dart` | L'appli : thème, français, écran « Mes questions ». |
| `theme/theme.dart` | Thème clair « pas IA » : papier, encre, bleu d'encre (`Couleurs`). |
| `screens/questions_screen.dart` | Écran 1 : la liste (texte, heure · jours, réponses ; « En pause » sans jour), « + », bandeau si l'heure pile n'est pas autorisée, numéro de l'APK en bas. Demande les notifications à la première ouverture ; reprogramme à l'ouverture, au retour et à chaque changement. |
| `screens/question_screen.dart` | Créer ou modifier : texte, réponses (meilleure, « entre les deux » facultative, moins bonne), heure (cadran), jours (aucun par défaut, raccourcis), supprimer. De 3 à 2 réponses : confirmation, conversion de l'historique. |
| `data/base.dart` | Base `ouinon.sqlite` (version 5), gardée telle quelle : questions, réponses ; les tables du planning et de la liste restent mais ne servent plus. Créée vide au premier lancement. |
| `data/notifications.dart` | Notifications des questions seulement ; réponse par bouton (même appli fermée) ; une notification dure jusqu'à la suivante de la même question. |
| `utils/planification.dart` | Ce qu'il faut programmer (14 jours d'avance), `prochaineFois`, durée d'affichage. |
| `models/`, `utils/jour.dart`, `utils/date_fr.dart`, `utils/stats.dart`, `utils/version.dart` | Modèles, dates, textes français, version. |

`ancien/` : l'appli complète à l'APK n° 22, mise de côté.

## Vérifications et compilation

Voir `docs/reprendre_le_projet.md` : `dart format`, `flutter analyze`,
`flutter test`, captures (`flutter test tool/captures_test.dart
--update-goldens`, police Roboto chargée depuis Flutter), puis l'APK.
