import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/utils/jeu.dart';

/// Le jeu « Synchro », étape 1 (docs/jeu.md) : les points et les niveaux.
void main() {
  final lundi = DateTime(2026, 10, 26);
  final mardi = DateTime(2026, 10, 27);

  Tache chose(DateTime jour, int duree, {int? etat, int? quadrant}) => Tache(
    jour: jour,
    debut: 9 * 60,
    duree: duree,
    texte: 'Chose $duree',
    etat: etat,
    quadrant: quadrant,
  );

  test('points selon la durée, et bonus « D\'abord »', () {
    expect(pointsDuree(15), 10);
    expect(pointsDuree(30), 15);
    expect(pointsDuree(60), 25);
    expect(pointsDuree(90), 35);
    expect(pointsChose(chose(mardi, 60, quadrant: 0)), 30);
    expect(pointsChose(chose(mardi, 60, quadrant: 1)), 25);
  });

  test('niveaux : 100, puis 50 de plus à chaque niveau', () {
    expect(niveauPour(0), (niveau: 1, dans: 0, pour: 100));
    expect(niveauPour(99).niveau, 1);
    expect(niveauPour(100), (niveau: 2, dans: 0, pour: 150));
    expect(niveauPour(260), (niveau: 3, dans: 10, pour: 200));
    expect(stadePour(4), 'Humain');
    expect(stadePour(5), 'Augmenté');
    expect(stadePour(35), 'Machine parfaite');
  });

  test('une journée : choses faites, réponses, plan, synchro', () {
    final b = bilanJeu(
      taches: [
        chose(mardi, 60, etat: Tache.fait),
        chose(mardi, 15, etat: Tache.fait),
        // « Pas fait » : aucun point, jamais de points en moins.
        chose(mardi, 30, etat: Tache.pasFait),
        // Une chose de test ne compte pas.
        Tache(
          jour: mardi,
          debut: 600,
          texte: 'Essai',
          etat: Tache.fait,
          test: true,
        ),
      ],
      reponses: {
        1: {'2026-10-27': 0},
        2: {'2026-10-27': 2},
      },
      plans: {'2026-10-27'},
      aujourdhui: mardi.add(const Duration(hours: 22)),
    );
    // 25 + 10 + synchro 2/3 (10) + 2 réponses (6) + plan (15).
    expect(b.total, 66);
    expect(b.duJour, 66);
    expect(b.synchroDuJour, closeTo(2 / 3, 1e-9));
    expect(b.gainsDuJour.first, (texte: 'Chose 60', points: 25));
    expect(b.gainsDuJour.map((g) => g.texte), contains('Synchro 67 %'));
  });

  test('la synchro attend que toute la journée ait une réponse', () {
    final b = bilanJeu(
      taches: [
        chose(mardi, 60, etat: Tache.fait),
        chose(mardi, 60),
      ],
      reponses: const {},
      plans: const {},
      aujourdhui: mardi,
    );
    expect(b.total, 25);
    expect(b.synchroDuJour, 0.5);
  });

  test('série : deux jours d\'affilée avec une réponse et une chose faite', () {
    final b = bilanJeu(
      taches: [
        chose(lundi, 15, etat: Tache.fait),
        chose(mardi, 15, etat: Tache.fait),
      ],
      reponses: {
        1: {'2026-10-26': 0, '2026-10-27': 1},
      },
      plans: const {},
      aujourdhui: mardi,
    );
    expect(b.serie, 2);
    // Lundi : 10 + 50 (synchro) + 3. Mardi : 10 + 50 + 3 + série 10.
    expect(b.total, 136);
    expect(b.duJour, 73);
  });

  test('la série s\'arrête après un jour sans rien', () {
    final b = bilanJeu(
      taches: [chose(DateTime(2026, 10, 24), 15, etat: Tache.fait)],
      reponses: {
        1: {'2026-10-24': 0},
      },
      plans: const {},
      aujourdhui: mardi,
    );
    expect(b.serie, 0);
  });
}
