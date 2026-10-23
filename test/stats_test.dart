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

  test('par jour de la semaine', () {
    final r = {j(0): 0, j(7): 1, j(5): 0};
    final s = parJourSemaine(sport, r);
    expect(s[0].comptes, [1, 1]);
    expect(s[5].comptes, [1, 0]);
    expect(s[2].total, 0);
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
