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

  test('croisement libre : réponses de B selon chaque réponse de A', () {
    final rs = {j(0): 0, j(1): 0, j(2): 1, j(3): 1};
    final rf = {j(0): 0, j(1): 1, j(2): 2, j(4): 0};
    final c = croisement(sport, forme, 0, rs, rf);
    expect(c, hasLength(2));
    expect(c[0].comptes, [1, 1, 0]); // jours avec sport
    expect(c[1].comptes, [0, 0, 1]); // jours sans (j(3) sans réponse B)
    // Lendemain : sport j(3) → forme j(4).
    final l = croisement(sport, forme, 1, rs, rf);
    expect(l[0].comptes, [0, 1, 1]);
    expect(l[1].comptes, [1, 0, 0]);
  });

  group('séries', () {
    test('jours d\'affilée avec la meilleure réponse, et record', () {
      // lundi 5 → dimanche 11 : Oui Oui Non Oui Oui Oui (samedi) ; dimanche
      // (aujourd'hui) pas encore répondu.
      final r = {j(0): 0, j(1): 0, j(2): 1, j(3): 0, j(4): 0, j(5): 0};
      final s = serie(sport, r, ajouteJours(lundi, 6));
      expect(s.actuelle, 3);
      expect(s.record, 3);
    });

    test('un jour passé sans réponse casse la série', () {
      final r = {j(0): 0, j(1): 0, j(3): 0};
      expect(serie(sport, r, ajouteJours(lundi, 3)).actuelle, 1);
      expect(serie(sport, r, ajouteJours(lundi, 3)).record, 2);
    });

    test('les jours où la question ne revient pas ne comptent pas', () {
      final semaine = sport.copie(jours: 0x1F); // du lundi au vendredi
      // vendredi 9, puis lundi 12 : la série tient malgré le week-end.
      final r = {j(4): 0, j(7): 0};
      expect(serie(semaine, r, ajouteJours(lundi, 7)).actuelle, 2);
    });

    test('sans réponse : zéro', () {
      expect(serie(sport, {}, lundi).actuelle, 0);
    });
  });

  test('classement : ce qui va avec la question principale', () {
    final rs = <String, int>{};
    final rf = <String, int>{};
    final rz = <String, int>{};
    for (var n = 0; n < 10; n++) {
      rs[j(n)] = n.isEven ? 0 : 1; // sport un jour sur deux
      rf[j(n)] = n.isEven ? 0 : 2; // en forme les jours de sport
      rz[j(n)] = n < 2 ? 0 : 1; // sommeil sans rapport
    }
    final c = classement(forme, [sommeil, forme, sport], {1: rs, 2: rf, 3: rz});
    expect(c.map((l) => l.a), [sport, sommeil]);
    expect(c.first.net, isTrue);
    expect(c.first.avec, 1.0);
    expect(c.first.decalage, 0);
    // Sommeil : 2 jours « avec » seulement, il en manque 1 de ce côté.
    expect(c.last.net, isFalse);
    expect(c.last.joursManquants, 1);
  });

  test('bilan de la semaine', () {
    final rs = {j(0): 0, j(1): 1, j(2): 0, j(3): 0, j(4): 0, j(5): 0};
    final rf = {j(0): 0, j(6): 1};
    final lignes = bilanSemaine(
      [sport, forme],
      {1: rs, 2: rf},
      ajouteJours(lundi, 6),
    )!;
    expect(lignes[0], 'Sport ? Oui : 5 jours sur 6');
    expect(lignes[1], 'En forme ? Bien : 1 jour sur 2');
    expect(lignes[2], 'Série : Sport ? Oui, 4 jours d\'affilée');
    expect(bilanSemaine([sport], {}, ajouteJours(lundi, 6)), isNull);
  });
}
