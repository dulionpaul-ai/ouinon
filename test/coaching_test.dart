import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/coaching.dart';

/// Le coaching : la cible du coucher avance de 30 minutes chaque lundi,
/// de 0 h 30 (semaine du 2/11/2026) jusqu'à 23 h.
void main() {
  test('cible du coucher, semaine après semaine', () {
    expect(cibleCoucher(DateTime(2026, 11, 5)), 24 * 60 + 30);
    expect(cibleCoucher(DateTime(2026, 11, 9)), 24 * 60);
    expect(cibleCoucher(DateTime(2026, 11, 16)), 23 * 60 + 30);
    expect(cibleCoucher(DateTime(2026, 11, 23)), 23 * 60);
    expect(cibleCoucher(DateTime(2027, 1, 4)), 23 * 60);
    expect(cibleCoucher(DateTime(2026, 10, 22)), 24 * 60 + 30);
  });

  test('la notification du coucher rappelle la cible de la veille', () {
    final coucher = questionsCoaching.firstWhere(
      (q) => q.texte == texteCoucher,
    );
    // Lundi 9/11 au matin : la nuit de dimanche, cible encore 0 h 30.
    expect(detailNotification(coucher, DateTime(2026, 11, 9)), contains('30'));
    expect(
      detailNotification(questionsCoaching.first, DateTime(2026, 11, 9)),
      isNull,
    );
  });
}
