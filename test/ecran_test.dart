import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/screens/questions_screen.dart';

import 'outils.dart';

void main() {
  late Base base;
  late FaussesNotifications notifs;
  // Mercredi 25/11/2026.
  final mercredi = DateTime(2026, 11, 25, 12);

  setUp(() async {
    base = await ouvreBase();
    Base.remplace(base);
    notifs = FaussesNotifications();
    Notifications.instance = notifs;
  });

  Future<void> lance(WidgetTester tester) async {
    await tester.pumpWidget(
      OuinonApp(accueil: QuestionsScreen(maintenant: () => mercredi)),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sans question, on invite à en créer une', (tester) async {
    await lance(tester);
    expect(find.textContaining('Aucune question'), findsOneWidget);
  });

  testWidgets('répondre dans l\'appli, puis enlever la réponse', (
    tester,
  ) async {
    final q = await tester.runAsync(
      () => base.enregistre(
        const Question(
          texte: 'Sport ?',
          reponses: ['Oui', 'Non'],
          heure: 21 * 60,
          jours: Question.tousLesJours,
        ),
      ),
    );
    await tester.runAsync(
      () => base.enregistre(
        const Question(
          texte: 'Hyrox ?',
          reponses: ['Fait', 'Pas fait'],
          heure: 12 * 60,
          jours: 0x01,
        ),
      ),
    );
    await lance(tester);
    expect(find.text('Sport ?'), findsOneWidget);
    // Hyrox n'est pas posée le mercredi : pas de boutons.
    expect(find.text('Fait'), findsNothing);

    await tester.tap(find.text('Oui'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect((await tester.runAsync(base.toutesLesReponses))![q!.id], {
      '2026-11-25': 0,
    });
    expect(notifs.retirees, hasLength(1));

    await tester.tap(find.text('Oui'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(await tester.runAsync(base.toutesLesReponses), isEmpty);
  });

  testWidgets('créer une question à 3 réponses', (tester) async {
    await lance(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'En forme ?');
    await tester.tap(find.text('Réponse du milieu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    final questions = (await tester.runAsync(base.questions))!;
    expect(questions.single.texte, 'En forme ?');
    expect(questions.single.reponses, ['Fait', 'Moyen', 'Pas fait']);
    expect(questions.single.jours, Question.tousLesJours);
    expect(find.text('En forme ?'), findsOneWidget);
    expect(find.text('Moyen'), findsOneWidget);
  });
}
