import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/utils/deux_moi.dart';

void main() {
  const jour = (debut: 9 * 60, fin: 19 * 60);
  final jeudi = DateTime(2026, 10, 22);

  test('dans la journée : bornes et plage qui passe minuit', () {
    expect(dansPlage(9 * 60, jour), isTrue);
    expect(dansPlage(19 * 60, jour), isFalse);
    expect(dansPlage(30, (debut: 22 * 60, fin: 60)), isTrue);
  });

  test('la chose en cours, sinon la prochaine sans réponse', () {
    final taches = [
      Tache(jour: jeudi, debut: 9 * 60, texte: 'Garage', etat: Tache.fait),
      Tache(jour: jeudi, debut: 10 * 60, duree: 90, texte: 'Impôts'),
      Tache(jour: jeudi, debut: 14 * 60, texte: 'Courses'),
    ];
    final a = enCours(taches, 10 * 60 + 30)!;
    expect((a.tache.texte, a.enCours), ('Impôts', true));
    final b = enCours(taches, 12 * 60)!;
    expect((b.tache.texte, b.enCours), ('Courses', false));
    expect(enCours(taches, 15 * 60), isNull);
  });

  test('textes du matin et du compte rendu', () {
    final taches = [
      Tache(jour: jeudi, debut: 10 * 60, duree: 90, texte: 'Impôts'),
      Tache(jour: jeudi, debut: 9 * 60, texte: 'Garage', etat: Tache.fait),
    ];
    expect(
      texteMatin(taches, 'Les impôts d\'abord'),
      'Prévu hier soir : 2 choses, 2 h 30. Première à 9 h.\n'
      '« Les impôts d\'abord »',
    );
    expect(texteMatin(const [], null), isNull);
    expect(
      texteRapport(taches),
      '1 sur 2 de ce que tu avais prévu. Un mot pour ton toi du soir ?',
    );
    expect(texteRapport(const []), isNull);
  });
}
