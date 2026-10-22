import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/utils/jour.dart';
import 'package:ouinon/utils/stats.dart';

void main() {
  const sport = Question(
    id: 1,
    texte: 'Sport ?',
    reponses: ['Oui', 'Non'],
    heure: 21 * 60,
  );
  const forme = Question(
    id: 2,
    texte: 'En forme ?',
    reponses: ['Bien', 'Moyen', 'Pas bien'],
    heure: 21 * 60,
  );
  const sommeil = Question(
    id: 3,
    texte: 'Sommeil ?',
    reponses: ['8 h et +', '6 à 8 h', 'Moins de 6 h'],
    heure: 9 * 60,
  );
  final lundi = DateTime(2026, 10, 5);
  String j(int n) => cleJour(ajouteJours(lundi, n));

  test('bilan sur une période, part de la meilleure réponse', () {
    final r = {j(0): 0, j(1): 1, j(2): 2, j(3): 0, j(10): 0};
    final b = bilan(forme, r, debut: lundi, fin: ajouteJours(lundi, 6));
    expect(b.comptes, [2, 1, 1]);
    expect(b.total, 4);
    expect(b.partMeilleure, 0.5);
    expect(bilan(forme, r, fin: ajouteJours(lundi, 30)).total, 5);
    expect(bilan(forme, {}, fin: lundi).partMeilleure, isNull);
  });

  test('évolution semaine par semaine, la plus ancienne d\'abord', () {
    final r = {j(0): 0, j(1): 1, j(7): 0, j(8): 0};
    final e = evolution(
      sport,
      r,
      aujourdhui: ajouteJours(lundi, 9),
      nbSemaines: 3,
    );
    expect(e.map((b) => b.total), [0, 2, 2]);
    expect(e.map((b) => b.partMeilleure), [null, 0.5, 1.0]);
  });

  test('par jour de la semaine', () {
    final r = {j(0): 0, j(7): 1, j(5): 0};
    final s = parJourSemaine(sport, r);
    expect(s[0].comptes, [1, 1]);
    expect(s[5].comptes, [1, 0]);
    expect(s[2].total, 0);
  });

  test('croisement même jour : sport → forme', () {
    // 10 jours : sport les jours pairs ; en forme surtout ces jours-là.
    final rs = <String, int>{};
    final rf = <String, int>{};
    for (var n = 0; n < 10; n++) {
      rs[j(n)] = n.isEven ? 0 : 1;
      rf[j(n)] = n.isEven ? (n == 8 ? 1 : 0) : (n == 1 ? 0 : 2);
    }
    final l = liens([sport, forme], {1: rs, 2: rf});
    final memeJour = l.where((x) => x.decalage == 0).toList();
    expect(memeJour, hasLength(1));
    final lien = memeJour.single;
    expect(lien.jours, 10);
    expect(lien.avec, 0.8);
    expect(lien.sans, 0.2);
    expect(
      phraseLien(lien),
      anyOf(
        'Les jours avec « Sport ? Oui » : « En forme ? Bien » 8 fois sur 10, '
            'contre 2 fois sur 10 les autres jours.',
        'Les jours avec « En forme ? Bien » : « Sport ? Oui » 8 fois sur 10, '
            'contre 2 fois sur 10 les autres jours.',
      ),
    );
  });

  test('croisement au lendemain : sport → sommeil du jour suivant', () {
    final rs = <String, int>{};
    final rz = <String, int>{};
    for (var n = 0; n < 12; n++) {
      rs[j(n)] = n % 3 == 0 ? 0 : 1;
      // Bien dormi le lendemain de chaque sport.
      rz[j(n + 1)] = n % 3 == 0 ? 0 : 2;
    }
    final l = liens([sport, sommeil], {1: rs, 3: rz});
    final lendemain = l.firstWhere(
      (x) => x.decalage == 1 && x.a == sport && x.b == sommeil,
    );
    expect(lendemain.avec, 1.0);
    expect(lendemain.sans, 0.0);
    expect(
      phraseLien(lendemain),
      startsWith('Le lendemain de « Sport ? Oui »'),
    );
  });

  test('pas de croisement sans assez de jours ou sans écart net', () {
    final peu = {j(0): 0, j(1): 1, j(2): 0, j(3): 1, j(4): 0, j(5): 1};
    expect(liens([sport, forme], {1: peu, 2: peu}), isEmpty);

    // 7 jours mais un seul « Non » : pas assez de chaque côté.
    final presqueTout = {for (var n = 0; n < 7; n++) j(n): n == 0 ? 1 : 0};
    expect(liens([sport, forme], {1: presqueTout, 2: presqueTout}), isEmpty);

    // Même part de « Bien » avec ou sans sport : pas de lien.
    final rs = {for (var n = 0; n < 8; n++) j(n): n < 4 ? 0 : 1};
    final rf = {for (var n = 0; n < 8; n++) j(n): n.isEven ? 0 : 2};
    expect(
      liens([sport, forme], {1: rs, 2: rf}).where((x) => x.decalage == 0),
      isEmpty,
    );
  });

  test('fois sur 10', () {
    expect(foisSurDix(0.66), '7 fois sur 10');
    expect(foisSurDix(0), '0 fois sur 10');
  });
}
