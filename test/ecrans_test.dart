import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/screens/question_screen.dart';
import 'package:ouinon/screens/questions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils.dart';

/// Écran 1 du cahier : « Mes questions » (27/10/2026).
void main() {
  late Base base;
  late FaussesNotifications notifs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    base = await ouvreBase(depart: false);
    Base.remplace(base);
    notifs = FaussesNotifications();
    Notifications.instance = notifs;
  });

  Future<void> ouvre(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const OuinonApp());
    await attends(tester);
  }

  testWidgets('vide au départ : on demande les notifications une fois', (
    tester,
  ) async {
    await ouvre(tester);
    expect(find.text('Mes questions'), findsOneWidget);
    expect(find.textContaining('Aucune question'), findsOneWidget);
    expect(notifs.replanifications, greaterThan(0));
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getBool('notifs_demandees'), isTrue);
  });

  testWidgets('créer : aucun jour par défaut, raccourcis, 3 réponses', (
    tester,
  ) async {
    await ouvre(tester);
    await tester.tap(find.byKey(const ValueKey('nouvelle-question')));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionScreen), findsOneWidget);
    expect(find.textContaining('Aucun jour'), findsOneWidget);
    // Rien sans texte ni réponses.
    final enregistrer = find.byKey(const ValueKey('enregistrer'));
    expect(tester.widget<FilledButton>(enregistrer).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('texte')), 'Sport ?');
    await tester.enterText(
      find.byKey(const ValueKey('reponse-meilleure')),
      'Oui',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reponse-moins-bonne')),
      'Non',
    );
    await tester.tap(find.byKey(const ValueKey('troisieme')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('reponse-milieu')),
      'Un peu',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('raccourci-semaine')));
    await tester.tap(find.byKey(const ValueKey('raccourci-semaine')));
    await tester.pump();
    // Décocher le vendredi.
    await tester.tap(find.byKey(const ValueKey('jour-4')));
    await tester.pump();
    await tester.ensureVisible(enregistrer);
    await tester.tap(enregistrer);
    await attends(tester);
    await tester.pumpAndSettle();
    final q = (await tester.runAsync(base.questions))!.single;
    expect(q.texte, 'Sport ?');
    expect(q.reponses, ['Oui', 'Un peu', 'Non']);
    expect(q.jours, 0x0F);
    expect(q.heure, 21 * 60);
    expect(find.text('Sport ?'), findsOneWidget);
    expect(find.text('21 h · lun., mar., mer., jeu.'), findsOneWidget);
    expect(find.text('Oui / Un peu / Non'), findsOneWidget);
  });

  testWidgets('sans aucun jour : en pause', (tester) async {
    await tester.runAsync(
      () => base.enregistre(
        const Question(
          texte: 'Lecture ?',
          reponses: ['Oui', 'Non'],
          heure: 22 * 60,
          jours: 0,
        ),
      ),
    );
    await ouvre(tester);
    expect(find.text('En pause · aucun jour'), findsOneWidget);
  });

  testWidgets('modifier les réponses : de 3 à 2, avec confirmation', (
    tester,
  ) async {
    final q = (await tester.runAsync(
      () => base.enregistre(
        const Question(
          texte: 'En forme ?',
          reponses: ['Bien', 'Moyen', 'Pas bien'],
          heure: 21 * 60,
        ),
      ),
    ))!;
    await tester.runAsync(() => base.repond(q.id!, DateTime(2026, 10, 20), 1));
    await tester.runAsync(() => base.repond(q.id!, DateTime(2026, 10, 21), 2));
    await ouvre(tester);
    await tester.tap(find.text('En forme ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retirer cette réponse'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('reponse-moins-bonne')),
      'Mal',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('enregistrer')));
    await tester.tap(find.byKey(const ValueKey('enregistrer')));
    await tester.pumpAndSettle();
    expect(find.text('Passer à 2 réponses ?'), findsOneWidget);
    await tester.tap(find.text('Effacer'));
    await attends(tester);
    await tester.pumpAndSettle();
    final apres = (await tester.runAsync(() => base.question(q.id!)))!;
    expect(apres.reponses, ['Bien', 'Mal']);
    // « Moyen » effacé, « Pas bien » devenu la moins bonne (indice 1).
    expect((await tester.runAsync(() => base.reponsesDe(q.id!)))!.values, [1]);
  });

  testWidgets('supprimer une question', (tester) async {
    await tester.runAsync(
      () => base.enregistre(
        const Question(texte: 'Sport ?', reponses: ['Oui', 'Non'], heure: 1260),
      ),
    );
    await ouvre(tester);
    await tester.tap(find.text('Sport ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('supprimer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await attends(tester);
    await tester.pumpAndSettle();
    expect((await tester.runAsync(base.questions))!, isEmpty);
    expect(find.byType(QuestionsScreen), findsOneWidget);
    expect(find.textContaining('Aucune question'), findsOneWidget);
  });

  testWidgets('heure pile non autorisée : un bandeau', (tester) async {
    notifs.precise = false;
    await ouvre(tester);
    expect(find.byKey(const ValueKey('heure-pile')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('heure-pile')));
    await tester.pump();
    expect(notifs.demandesHeurePrecise, 1);
  });
}
