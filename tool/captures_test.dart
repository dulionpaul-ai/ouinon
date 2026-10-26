// Captures d'écran de l'appli (polices réelles), pour montrer le style.
// Lancement : flutter test tool/captures_test.dart --update-goldens
// Images écrites dans tool/captures/ (non commitées).
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/creneau.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/aujourdhui_screen.dart';
import 'package:ouinon/screens/edition_a_faire_screen.dart';
import 'package:ouinon/screens/edition_tache_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/fiche_question_screen.dart';
import 'package:ouinon/screens/intro_screen.dart';
import 'package:ouinon/screens/passage_screen.dart';
import 'package:ouinon/screens/rapport_screen.dart';
import 'package:ouinon/screens/preparer_screen.dart';
import 'package:ouinon/screens/todo_screen.dart';
import 'package:ouinon/screens/questions_screen.dart';
import 'package:ouinon/screens/reglages_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
import 'package:ouinon/widgets/retro.dart';
import 'package:ouinon/widgets/rond.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/outils.dart';

Future<void> _police(String famille, List<String> fichiers) async {
  final chargeur = FontLoader(famille);
  for (final f in fichiers) {
    final octets = File(f).readAsBytesSync();
    chargeur.addFont(Future.value(ByteData.view(octets.buffer)));
  }
  await chargeur.load();
}

void main() {
  setUpAll(() async {
    await _police('Unbounded', [
      'assets/fonts/Unbounded-500.ttf',
      'assets/fonts/Unbounded-700.ttf',
    ]);
    await _police('Figtree', [
      for (final w in [500, 600, 700, 800]) 'assets/fonts/Figtree-$w.ttf',
    ]);
    await _police('VT323', ['assets/fonts/VT323-400.ttf']);
    await _police('IBMPlexMono', [
      'assets/fonts/IBMPlexMono-500.ttf',
      'assets/fonts/IBMPlexMono-700.ttf',
    ]);
    final sdk = File(Platform.resolvedExecutable).parent.parent.parent.path;
    await _police('MaterialIcons', [
      '$sdk/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  late Base base;
  final maintenant = DateTime(2026, 10, 22, 12);

  setUp(() async {
    Curseur.clignote = false;
    SharedPreferences.setMockInitialValues({
      'bienvenue_vue': true,
      'intro_deux_moi_vue': true,
      'reveil_vu': '2026-10-22',
      'mot_2026-10-22': 'Appelle maman avant le garage.',
      'mot_soir_2026-10-22': 'La banque était fermée.',
    });
    base = await ouvreBase();
    Base.remplace(base);
    Notifications.instance = FaussesNotifications();
  });

  Future<void> remplit(WidgetTester tester) => tester.runAsync(() async {
    // Six mois de réponses de test (comme le bouton des Réglages).
    await ajouteDonneesTest(base, maintenant: maintenant);
    await base.repond(1, DateTime(2026, 10, 22), 0);
    await base.repond(2, DateTime(2026, 10, 22), 1);
    // Le planning du jour et du lendemain.
    final jeudi = DateTime(2026, 10, 22), vendredi = DateTime(2026, 10, 23);
    for (final t in [
      Tache(jour: jeudi, debut: 540, duree: 30, texte: 'Mails', etat: 0),
      Tache(jour: jeudi, debut: 630, duree: 30, texte: 'Banque', etat: 1),
      Tache(jour: jeudi, debut: 750, duree: 15, texte: 'Appeler maman'),
      Tache(jour: jeudi, debut: 1080, texte: 'Garage', reports: 1),
      Tache(jour: jeudi, debut: 1290, duree: 30, texte: 'Lire'),
      Tache(jour: vendredi, debut: 540, texte: 'Garage C3'),
    ]) {
      await base.enregistreTache(t);
    }
    await base.enregistreCreneau(
      const Creneau(texte: 'Enfants', debut: 17 * 60, fin: 23 * 60),
    );
  });

  Widget avecOnglets(Widget ecran, int index) => Scaffold(
    body: ecran,
    extendBody: true,
    bottomNavigationBar: BarreOnglets(
      index: index,
      libelles: const ['Aujourd\'hui', 'To-do', 'Stats'],
      onChoix: (_) {},
    ),
  );

  Future<void> capture(
    WidgetTester tester,
    String nom,
    Widget ecran,
    ThemeMode mode, {
    double hauteur = 844,
    double largeur = 390,
    double texte = 1,
    Future<void> Function(WidgetTester)? avant,
    Duration? arret,
  }) async {
    tester.view.physicalSize = Size(largeur * 2, hauteur * 2);
    tester.platformDispatcher.textScaleFactorTestValue = texte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(OuinonApp(accueil: ecran));
    await attends(tester, 15);
    if (arret != null) {
      // Arrêt sur image au milieu d'une animation.
      for (var i = 0; i < arret.inMilliseconds ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } else {
      // Laisse les animations des graphiques aller au bout.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }
    if (avant != null) await avant(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/$nom.png'),
    );
  }

  for (final mode in [ThemeMode.dark]) {
    final suffixe = mode == ThemeMode.light ? 'clair' : 'sombre';

    testWidgets('jour $suffixe', (tester) async {
      await remplit(tester);
      await capture(tester, '1-jour-$suffixe', const AccueilScreen(), mode);
    });

    testWidgets('stats $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '2-stats-$suffixe',
        avecOnglets(StatsScreen(base: base, maintenant: () => maintenant), 2),
        mode,
        hauteur: 6200,
      );
    });

    testWidgets('fiche $suffixe', (tester) async {
      await remplit(tester);
      final q = (await tester.runAsync(() => base.question(2)))!;
      await capture(
        tester,
        '3-fiche-$suffixe',
        FicheQuestionScreen(
          base: base,
          question: q,
          maintenant: () => maintenant,
        ),
        mode,
        hauteur: 1700,
      );
    });

    testWidgets('nouvelle question $suffixe', (tester) async {
      await capture(
        tester,
        '5-nouvelle-$suffixe',
        EditionQuestionScreen(base: base),
        mode,
        hauteur: 1250,
      );
    });

    testWidgets('choix heure $suffixe', (tester) async {
      await capture(
        tester,
        '5b-heure-$suffixe',
        EditionQuestionScreen(base: base),
        mode,
        avant: (tester) async {
          await tester.scrollUntilVisible(
            find.text('21 h'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('21 h'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('modifier $suffixe', (tester) async {
      final q = (await tester.runAsync(() => base.question(1)))!;
      await capture(
        tester,
        '6-modifier-$suffixe',
        EditionQuestionScreen(base: base, question: q),
        mode,
        hauteur: 1400,
      );
    });

    testWidgets('réglages $suffixe', (tester) async {
      (Notifications.instance as FaussesNotifications).precise = false;
      await capture(
        tester,
        '11-reglages-$suffixe',
        ReglagesScreen(base: base),
        mode,
        hauteur: 1100,
      );
    });

    testWidgets('questions $suffixe', (tester) async {
      await capture(
        tester,
        '4-questions-$suffixe',
        QuestionsScreen(base: base),
        mode,
      );
    });

    testWidgets('to-do $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '12-todo-$suffixe',
        avecOnglets(TodoScreen(base: base, maintenant: () => maintenant), 1),
        mode,
      );
    });

    testWidgets('préparer, étape 1 $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '17-preparer-1-$suffixe',
        PreparerScreen(
          base: base,
          jour: DateTime(2026, 10, 23),
          maintenant: () => maintenant,
        ),
        mode,
      );
    });

    testWidgets('à faire $suffixe', (tester) async {
      await capture(
        tester,
        '18-a-faire-$suffixe',
        EditionAFaireScreen(base: base, maintenant: () => maintenant),
        mode,
        hauteur: 1250,
        avant: (tester) async {
          await tester.enterText(find.byType(TextField).first, 'Papiers');
          await tester.tap(find.byKey(const ValueKey('duree-60')));
          await tester.tap(find.byKey(const ValueKey('important')));
          await tester.tap(find.text('Cette semaine'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('préparer, étape 2 $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '19-preparer-2-$suffixe',
        PreparerScreen(
          base: base,
          jour: DateTime(2026, 10, 23),
          maintenant: () => maintenant,
        ),
        mode,
        hauteur: 1000,
        avant: (tester) async {
          await tester.tap(find.text('Suivant : caser dans la journée'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('prévoir $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '14-prevoir-$suffixe',
        EditionTacheScreen(
          base: base,
          jour: DateTime(2026, 10, 23),
          maintenant: () => maintenant,
        ),
        mode,
        hauteur: 1100,
        avant: (tester) async {
          await tester.enterText(find.byType(TextField).first, 'Garage');
          await tester.pump();
        },
      );
    });

    testWidgets('jour avec planning $suffixe', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        '16-jour-prevu-$suffixe',
        avecOnglets(
          AujourdhuiScreen(base: base, maintenant: () => maintenant),
          0,
        ),
        mode,
        hauteur: 1000,
      );
    });
  }

  // Petit téléphone (360 de large) et gros texte (1,3) : rien ne déborde.
  testWidgets('petit écran, gros texte', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '7-petit-jour',
      AccueilScreen(maintenant: () => maintenant),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 760,
      texte: 1.3,
    );
  });

  testWidgets('petit écran, gros texte, questions', (tester) async {
    await capture(
      tester,
      '8-petit-questions',
      Scaffold(body: QuestionsScreen(base: base)),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 760,
      texte: 1.3,
    );
  });

  testWidgets('petit écran, gros texte, nouvelle question', (tester) async {
    await capture(
      tester,
      '9-petit-nouvelle',
      EditionQuestionScreen(base: base),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 1400,
      texte: 1.3,
    );
  });

  testWidgets('petit écran, gros texte, fiche', (tester) async {
    await remplit(tester);
    final q = (await tester.runAsync(() => base.question(1)))!;
    await capture(
      tester,
      '10-petit-fiche',
      FicheQuestionScreen(
        base: base,
        question: q,
        maintenant: () => maintenant,
      ),
      ThemeMode.light,
      largeur: 360,
      hauteur: 1600,
      texte: 1.3,
    );
  });

  testWidgets('petit écran, gros texte, demain', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '15-petit-todo',
      avecOnglets(TodoScreen(base: base, maintenant: () => maintenant), 1),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 900,
      texte: 1.3,
    );
  });

  // Les deux toi (26/10/2026).
  testWidgets('intro, page 1', (tester) async {
    await capture(tester, '20-intro-1', const IntroScreen(), ThemeMode.dark);
  });

  testWidgets('intro, page 1 : le pourquoi, au moment de la coupe', (
    tester,
  ) async {
    await capture(
      tester,
      '20a-intro-pourquoi',
      const IntroScreen(),
      ThemeMode.dark,
      arret: const Duration(milliseconds: 7800),
    );
  });

  testWidgets('intro, page 1, petit téléphone', (tester) async {
    await capture(
      tester,
      '20b-petit-intro',
      const IntroScreen(),
      ThemeMode.dark,
      largeur: 360,
      hauteur: 760,
      texte: 1.3,
    );
  });

  testWidgets('intro, page 2', (tester) async {
    await capture(
      tester,
      '21-intro-2',
      const IntroScreen(),
      ThemeMode.dark,
      avant: (tester) async {
        await tester.tap(find.text('Faire connaissance'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('intro, page 3', (tester) async {
    await capture(
      tester,
      '22-intro-3',
      const IntroScreen(),
      ThemeMode.dark,
      avant: (tester) async {
        await tester.tap(find.text('Faire connaissance'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('C\'est ça'));
        await tester.pumpAndSettle();
      },
    );
  });

  for (final (nom, largeur, texte) in [
    ('23-executant', 390.0, 1.0),
    ('24-petit-executant', 360.0, 1.3),
  ]) {
    testWidgets('le jour, écran rétro ($nom)', (tester) async {
      await remplit(tester);
      await capture(
        tester,
        nom,
        AccueilScreen(maintenant: () => DateTime(2026, 10, 22, 12, 35)),
        ThemeMode.dark,
        largeur: largeur,
        hauteur: 1000,
        texte: texte,
      );
    });
  }

  testWidgets('l\'ascenseur, arrivée', (tester) async {
    await capture(
      tester,
      '25-ascenseur',
      const PassageScreen(
        versJour: true,
        titreSoir: 'Hier soir, tu as décidé.',
        lignesJour: [
          'BONJOUR.',
          '5 TÂCHES REÇUES.',
          'ENSUITE : 12:30 APPELER MAMAN',
        ],
      ),
      ThemeMode.dark,
    );
  });

  testWidgets('le compte rendu', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '26-compte-rendu',
      RapportScreen(base: base, jour: DateTime(2026, 10, 22)),
      ThemeMode.dark,
      hauteur: 1000,
    );
  });

  testWidgets('le soir', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '27-soir',
      AccueilScreen(maintenant: () => DateTime(2026, 10, 22, 21, 45)),
      ThemeMode.dark,
      hauteur: 1000,
    );
  });
}
