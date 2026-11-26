import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/apparence.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/screens/questions_screen.dart';

import 'outils.dart';

void main() {
  late Base base;
  late FaussesNotifications notifs;
  // Mercredi 25/11/2026.
  final mercredi = DateTime(2026, 11, 25, 12);

  setUp(() async {
    Apparence.actuelle = Apparence.defaut;
    base = await ouvreBase();
    Base.remplace(base);
    notifs = FaussesNotifications();
    Notifications.instance = notifs;
  });

  Future<void> lance(WidgetTester tester) async {
    // Un grand téléphone : tout le formulaire tient à l'écran.
    tester.view.physicalSize = const Size(400, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      OuinonApp(accueil: QuestionsScreen(maintenant: () => mercredi)),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> attends(WidgetTester tester) async {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sans habitude, on invite à en créer une', (tester) async {
    await lance(tester);
    expect(find.textContaining('Aucune habitude'), findsOneWidget);
  });

  testWidgets('la liste : la semaine, les habitudes, pas de réponses ici', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final sport = await base.enregistre(
        const Question(
          texte: 'Sport ?',
          reponses: ['Oui', 'Non'],
          heure: 21 * 60,
          jours: Question.tousLesJours,
        ),
      );
      await base.enregistre(
        const Question(
          texte: 'Hyrox ?',
          reponses: ['Fait', 'Pas fait'],
          heure: 12 * 60,
          jours: 0x01,
        ),
      );
      await base.enregistre(
        const Question(
          texte: 'Marche ?',
          reponses: ['Fait', 'Pas fait'],
          heure: 18 * 60,
        ),
      );
      await base.repond(sport.id!, DateTime(2026, 11, 25), 0);
    });
    await lance(tester);
    expect(find.text('Sport ?'), findsOneWidget);
    expect(find.text('Hyrox ?'), findsOneWidget);
    expect(find.text('Marche ?'), findsOneWidget);
    expect(find.text('21:00 · TOUS LES JOURS'), findsOneWidget);
    expect(find.text('18:00 · EN PAUSE'), findsOneWidget);
    // Semaine 48 : lundi et mardi sans réponse, mercredi oui ; Hyrox lundi.
    expect(find.text('SEM 48'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    // On ne répond que dans les notifications.
    expect(find.text('Oui'), findsNothing);

    await tester.tap(find.text('Hyrox ?'));
    await attends(tester);
    expect(find.text('HABITUDE'), findsOneWidget);
    expect(find.text('▸ HYROX ?'), findsOneWidget);
  });

  testWidgets('la phrase du haut, et quand revient une tâche', (tester) async {
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
    await attends(tester);
    expect(
      find.text('Je deviens quelqu\'un qui dort, bouge et tient parole.'),
      findsOneWidget,
    );
    expect(find.text('10:00 · TOUS LES 5 JOURS · DANS 3 J'), findsOneWidget);
  });

  testWidgets('créer une habitude à 3 réponses, avec son aperçu', (
    tester,
  ) async {
    await lance(tester);
    await tester.tap(find.text('+ NOUVELLE HABITUDE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'En forme ?');
    await tester.enterText(
      find.byKey(const ValueKey('pourquoi')),
      'Pour tenir la journée.',
    );
    await tester.pump();
    // L'aperçu de la notification suit la saisie.
    expect(find.text('▸ EN FORME ?'), findsOneWidget);
    expect(find.text('Pour tenir la journée.'), findsNWidgets(2));
    await tester.tap(find.text('+ RÉPONSE DU MILIEU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TOUS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENREGISTRER'));
    await attends(tester);

    final questions = (await tester.runAsync(base.questions))!;
    expect(questions.single.texte, 'En forme ?');
    expect(questions.single.pourquoi, 'Pour tenir la journée.');
    expect(questions.single.reponses, ['Fait', 'Moyen', 'Pas fait']);
    expect(questions.single.jours, Question.tousLesJours);
    expect(find.text('En forme ?'), findsOneWidget);
  });

  testWidgets('une tâche tous les 7 jours', (tester) async {
    await lance(tester);
    await tester.tap(find.text('+ NOUVELLE HABITUDE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Draps ?');
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Moins souvent'));
      await tester.pump();
    }
    expect(find.text('TOUS LES 7 J'), findsOneWidget);
    await tester.tap(find.text('ENREGISTRER'));
    await attends(tester);
    final q = (await tester.runAsync(base.questions))!.single;
    expect(q.intervalle, 7);
    // Choisir un intervalle sans jour coche tous les jours.
    expect(q.jours, Question.tousLesJours);
  });
}
