import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/a_faire.dart';
import 'package:ouinon/utils/dictee.dart';
import 'package:ouinon/utils/recherche.dart';

void main() {
  group('dictée', () {
    test('l\'exemple de Paul', () {
      final d = lisDictee(
        'me couper les ongles et ça prendra environ 15 minutes',
      );
      expect(d.texte, 'Me couper les ongles');
      expect(d.duree, 15);
    });

    test('durées en chiffres et en lettres', () {
      expect(lisDictee('appeler le garage 30 min'), (
        texte: 'Appeler le garage',
        duree: 30,
      ));
      expect(lisDictee('ranger la cave pendant 2 heures'), (
        texte: 'Ranger la cave',
        duree: 120,
      ));
      expect(lisDictee('papiers 1 h 30'), (texte: 'Papiers', duree: 90));
      expect(lisDictee('impôts, une heure et demie'), (
        texte: 'Impôts',
        duree: 90,
      ));
      expect(lisDictee('répondre à Marc un quart d\'heure'), (
        texte: 'Répondre à Marc',
        duree: 15,
      ));
      expect(lisDictee('lessive en une demi-heure'), (
        texte: 'Lessive',
        duree: 30,
      ));
      expect(lisDictee('courses trois quarts d\'heure'), (
        texte: 'Courses',
        duree: 45,
      ));
    });

    test('sans durée : tout est le titre', () {
      expect(lisDictee('acheter du pain'), (
        texte: 'Acheter du pain',
        duree: null,
      ));
    });
  });

  group('doublons', () {
    final jeudi = DateTime(2026, 10, 22);
    final liste = [
      AFaire(id: 1, texte: 'Couper les ongles', creeLe: jeudi),
      AFaire(id: 2, texte: 'Rappeler l\'électricien', creeLe: jeudi),
      AFaire(id: 3, texte: 'Déclarer les impôts', creeLe: jeudi),
    ];

    test('par mots, sans accents ni majuscules, même à moitié tapés', () {
      expect(ressemblantes('Me couper les ongles', liste).map((a) => a.id), [
        1,
      ]);
      expect(ressemblantes('electricien', liste).map((a) => a.id), [2]);
      expect(ressemblantes('impo', liste).map((a) => a.id), [3]);
      expect(ressemblantes('les de la', liste), isEmpty);
      expect(ressemblantes('ongles', liste, sauf: 1), isEmpty);
    });
  });
}
