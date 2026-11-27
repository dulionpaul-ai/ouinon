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
    // Répondue : sa réponse en pastille, et les 7 points, la semaine.
    expect(find.text('Non'), findsNothing);
    expect(find.text('1 oui sur 4', findRichText: true), findsOneWidget);

    // Toucher la pastille rouvre les boutons ; toucher à nouveau la
    // réponse choisie l'enlève.
    await tester.tap(find.text('Oui'));
    await tester.pumpAndSettle();
    expect(find.text('Non'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Tous'));
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

  testWidgets('la phrase du haut, et les tâches pas posées aujourd\'hui', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final plantes = await base.enregistre(
        const Question(
          texte: 'Arroser les plantes ?',
          reponses: ['Fait', 'Pas fait'],
          heure: 10 * 60,
          jours: Question.tousLesJours,
          intervalle: 5,
        ),
      );
      // Arrosées lundi : reviennent samedi.
      await base.repond(plantes.id!, DateTime(2026, 11, 23), 0);
    });
    await lance(tester);
    expect(find.text('Je deviens quelqu\'un qui…'), findsOneWidget);
    await tester.tap(find.text('Je deviens quelqu\'un qui…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('phrase')),
      'dort, bouge et tient parole.',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Je deviens quelqu\'un qui dort, bouge et tient parole.'),
      findsOneWidget,
    );
    expect(find.text('Arroser les plantes ?'), findsNothing);
    await tester.tap(find.text('Pas aujourd\'hui (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Arroser les plantes ?'), findsOneWidget);
    expect(find.text('10 h · Tous les 5 jours · dans 3 jours'), findsOneWidget);

    // Arrosées aujourd'hui quand même : la suite se recale.
    await tester.tap(find.text('Fait'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final r = (await tester.runAsync(base.toutesLesReponses))!.values.single;
    expect(r['2026-11-25'], 0);
    expect(find.textContaining('AUJOURD\'HUI · 1 SUR 1'), findsOneWidget);
  });

  testWidgets('une tâche tous les 7 jours, avec son pourquoi', (tester) async {
    await lance(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Draps ?');
    await tester.enterText(
      find.byKey(const ValueKey('pourquoi')),
      'Bien dormir.',
    );
    await tester.ensureVisible(find.text('Tous les N jours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tous les N jours'));
    await tester.pumpAndSettle();
    // Les jours à cocher disparaissent : l'un ou l'autre.
    expect(find.text('Semaine'), findsNothing);
    expect(find.text('7 jours'), findsOneWidget);
    expect(find.text('Aujourd\'hui'), findsOneWidget);
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final q = (await tester.runAsync(base.questions))!.single;
    expect(q.intervalle, 7);
    expect(q.pourquoi, 'Bien dormir.');
    expect(q.jours, Question.tousLesJours);
    expect(q.depart, DateTime(2026, 11, 25));
  });
}
