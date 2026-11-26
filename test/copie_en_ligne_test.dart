import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/question.dart';

import 'outils.dart';

const _sport = Question(
  texte: 'Sport ?',
  reponses: ['Oui', 'Non'],
  heure: 21 * 60,
  jours: Question.tousLesJours,
);

void main() {
  final lundi = DateTime(2026, 11, 23);

  test('chaque changement part en ligne', () async {
    final miroir = FauxMiroir();
    final base = await ouvreBase(miroir: miroir);
    final q = await base.enregistre(_sport);
    await base.repond(q.id!, lundi, 1);
    await base.envoisTermines();
    expect(miroir.questions[q.id]!.texte, 'Sport ?');
    expect(miroir.reponses[q.id], {'2026-11-23': 1});

    await base.enregistreAvecNombre(
      q.copie(reponses: ['Oui', 'Un peu', 'Non']),
      2,
    );
    await base.envoisTermines();
    expect(miroir.reponses[q.id], {'2026-11-23': 2});

    await base.efface(q.id!, lundi);
    await base.envoisTermines();
    expect(miroir.reponses[q.id], isEmpty);

    await base.supprime(q.id!);
    await base.envoisTermines();
    expect(miroir.questions, isEmpty);
  });

  test(
    'sans réseau, rien ne bloque, tout part à l\'ouverture suivante',
    () async {
      final miroir = FauxMiroir()..horsLigne = true;
      final base = await ouvreBase(miroir: miroir);
      final q = await base.enregistre(_sport);
      await base.repond(q.id!, lundi, 0);
      await base.envoisTermines();
      expect(await base.synchronise(), isFalse);
      expect(miroir.questions, isEmpty);

      miroir.horsLigne = false;
      expect(await base.synchronise(), isFalse);
      expect(miroir.questions.keys, [q.id]);
      expect(miroir.reponses[q.id], {'2026-11-23': 0});
    },
  );

  test('nouveau téléphone : tout revient de la copie en ligne', () async {
    final miroir = FauxMiroir();
    final ancien = await ouvreBase(miroir: miroir);
    final q = await ancien.enregistre(
      _sport.copie(jours: 0x01, pourquoi: 'Pour tenir', intervalle: 3),
    );
    await ancien.repond(q.id!, lundi, 1);
    await ancien.changePhrase('se couche tôt');
    await ancien.envoisTermines();

    final nouveau = await ouvreBase(miroir: miroir);
    expect(await nouveau.synchronise(), isTrue);
    final questions = await nouveau.questions();
    expect(questions.single.texte, 'Sport ?');
    expect(questions.single.jours, 0x01);
    expect(questions.single.pourquoi, 'Pour tenir');
    expect(questions.single.intervalle, 3);
    expect(await nouveau.phrase(), 'se couche tôt');
    expect(await nouveau.toutesLesReponses(), {
      q.id: {'2026-11-23': 1},
    });
    // Une nouvelle question ne reprend pas un numéro déjà pris.
    final autre = await nouveau.enregistre(_sport.copie(texte: 'Muscu ?'));
    expect(autre.id, isNot(q.id));
  });
}
