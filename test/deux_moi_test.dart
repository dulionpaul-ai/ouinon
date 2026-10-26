import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/utils/deux_moi.dart';
import 'package:ouinon/widgets/anneau_roles.dart';

void main() {
  const jour = (debut: 9 * 60, fin: 19 * 60);
  final jeudi = DateTime(2026, 10, 22);

  test('qui est là : la journée à l\'Exécutant, tout le reste au Décideur', () {
    Moi a(int h, [int m = 0]) => moiA(DateTime(2026, 10, 22, h, m), jour: jour);
    expect(a(9), Moi.executant);
    expect(a(18, 59), Moi.executant);
    expect(a(19), Moi.decideur);
    expect(a(21, 30), Moi.decideur);
    expect(a(0, 15), Moi.decideur);
    expect(a(7), Moi.decideur);
  });

  test('l\'anneau : quarts d\'heure, une heure au moins, pas après minuit', () {
    ({int debut, int fin})? place(bool debutBouge, int minute) =>
        AnneauRoles.place(
          debut: 8 * 60,
          fin: 20 * 60,
          debutBouge: debutBouge,
          minute: minute,
        );
    expect(place(true, 7 * 60 + 8), (debut: 7 * 60 + 15, fin: 20 * 60));
    expect(place(false, 0), (debut: 8 * 60, fin: 24 * 60));
    expect(place(false, 8 * 60 + 30), isNull);
    expect(place(true, 20 * 60), isNull);
    // Le début ne passe pas de l'autre côté de minuit.
    expect(place(true, 23 * 60 + 50), isNull);
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
