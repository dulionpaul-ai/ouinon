import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/utils/courbes.dart';
import 'package:ouinon/utils/jour.dart';

void main() {
  const sommeil = Question(
    id: 1,
    texte: 'Sommeil ?',
    reponses: ['8 h et +', '6 à 8 h', 'Moins de 6 h'],
    heure: 9 * 60,
  );
  const forme = Question(
    id: 2,
    texte: 'En forme ?',
    reponses: ['Bien', 'Moyen', 'Pas bien'],
    heure: 21 * 60,
  );
  const ecrans = Question(
    id: 3,
    texte: 'Écrans le soir ?',
    reponses: ['Non', 'Oui'],
    heure: 22 * 60,
  );
  final debut = DateTime(2026, 7, 1);
  String j(int n) => cleJour(ajouteJours(debut, n));
  // Suite irrégulière (sans motif qui se répète) de bons et mauvais jours.
  bool bon(int n) => (n * 7 + n * n * 3) % 11 < 5;

  test('notes : 1 pour la meilleure, 0,5 au milieu, 0 pour la moins bonne', () {
    expect(note(0, 3), 1);
    expect(note(1, 3), 0.5);
    expect(note(2, 3), 0);
    expect(note(1, 2), 0);
  });

  test('notes par jour et moyenne glissante', () {
    final notes = notesParJour(
      sommeil,
      {j(0): 0, j(2): 2},
      debut,
      ajouteJours(debut, 3),
    );
    expect(notes, [1, null, 0, null]);
    expect(moyenneGlissante(notes, fenetre: 2), [1, 1, 0, 0]);
    expect(moyenneGlissante([null, null]), [null, null]);
  });

  test('pearson', () {
    expect(pearson([1, 2, 3], [2, 4, 6]), closeTo(1, 1e-9));
    expect(pearson([1, 2, 3], [3, 2, 1]), closeTo(-1, 1e-9));
    expect(pearson([1, 1, 1], [1, 2, 3]), isNull);
  });

  test('découverte : la forme suit le sommeil avec 1 jour de décalage', () {
    final rs = <String, int>{}, rf = <String, int>{}, re = <String, int>{};
    for (var n = 0; n < 40; n++) {
      rs[j(n)] = bon(n) ? 0 : 2;
      rf[j(n + 1)] = bon(n) ? 0 : 2; // le lendemain
      re[j(n)] = (n * 13 + 5) % 17 < 8 ? 1 : 0; // sans rapport
    }
    final d = decouvertes([sommeil, forme, ecrans], {1: rs, 2: rf, 3: re});
    expect(d, isNotEmpty);
    expect(d.first.a, sommeil);
    expect(d.first.b, forme);
    expect(d.first.decalage, 1);
    expect(d.first.r, closeTo(1, 1e-9));
    expect(d.first.fort, isTrue);
    expect(phraseDecouverte(d.first), 'Même courbe, avec 1 jour de décalage');
    expect(d.where((x) => x.a == ecrans || x.b == ecrans), isEmpty);
  });

  test('découverte à l\'inverse, et ordre quand B précède A', () {
    final rs = <String, int>{}, re = <String, int>{};
    for (var n = 0; n < 30; n++) {
      re[j(n)] = bon(n) ? 1 : 0; // écrans le soir (« Oui » = moins bonne)
      rs[j(n + 1)] = bon(n) ? 2 : 0; // mauvais sommeil le lendemain
    }
    final d = decouvertes([sommeil, ecrans], {1: rs, 3: re});
    expect(d.single.a, ecrans);
    expect(d.single.b, sommeil);
    expect(d.single.decalage, 1);
    expect(d.single.inverse, isFalse); // écrans « Non » va avec bon sommeil
    expect(d.single.r, closeTo(1, 1e-9));
  });

  test('pas assez de jours : aucune découverte', () {
    final rs = {for (var n = 0; n < 10; n++) j(n): n % 2};
    final rf = {for (var n = 0; n < 10; n++) j(n): n % 2 * 2};
    expect(decouvertes([sommeil, forme], {1: rs, 2: rf}), isEmpty);
  });

  test('nuage par semaine et droite', () {
    final rs = {for (var n = 0; n < 14; n++) j(n): n < 7 ? 0 : 2};
    final rf = {for (var n = 0; n < 14; n++) j(n): n < 7 ? 0 : 1};
    final pts = pointsParSemaine(
      sommeil,
      rs,
      forme,
      rf,
      debut,
      ajouteJours(debut, 13),
    );
    expect(pts.length, greaterThanOrEqualTo(2));
    final d = droite([for (final p in pts) (x: p.x, y: p.y)])!;
    expect(d.pente, greaterThan(0));
  });
}
