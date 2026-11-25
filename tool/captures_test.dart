// Captures d'écran de l'appli, avec les vraies polices, à regarder avant
// chaque APK. Lancement : flutter test tool/captures_test.dart --update-goldens
// Images écrites dans tool/captures/ (non commitées).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/screens/question_screen.dart';
import 'package:ouinon/screens/questions_screen.dart';

import '../test/outils.dart';

Future<void> _police(String famille, List<String> fichiers) async {
  final chargeur = FontLoader(famille);
  for (final f in fichiers) {
    final octets = File(f).readAsBytesSync();
    chargeur.addFont(Future.value(ByteData.view(octets.buffer)));
  }
  await chargeur.load();
}

const _questions = [
  Question(
    texte: 'Écrans coupés à minuit ?',
    reponses: ['Oui', 'Non'],
    heure: 7 * 60 + 45,
    jours: 0x7F,
  ),
  Question(
    texte: 'Assez dormi ?',
    reponses: ['Oui', 'Bof', 'Non'],
    heure: 7 * 60 + 45,
    jours: 0x7F,
  ),
  Question(
    texte: 'Bloc recherche d\'emploi ?',
    reponses: ['Fait', 'Pas fait'],
    heure: 16 * 60 + 30,
    jours: 0x1F,
  ),
  Question(
    texte: 'Ultimate ?',
    reponses: ['Fait', 'Pas fait'],
    heure: 23 * 60,
    jours: 0x0A,
  ),
  Question(
    texte: 'Hyrox ?',
    reponses: ['Fait', 'Pas fait'],
    heure: 12 * 60,
    jours: 0x01,
  ),
  Question(texte: 'Sorti dehors ?', reponses: ['Oui', 'Non'], heure: 21 * 60),
];

void main() {
  setUpAll(() async {
    await _police('Oxanium', [
      for (final g in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'assets/fonts/Oxanium-$g.ttf',
    ]);
    final sdk = File(Platform.resolvedExecutable).parent.parent.parent.path;
    await _police('MaterialIcons', [
      '$sdk/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  // Mardi 24/11/2026.
  final mardi = DateTime(2026, 11, 24, 18);
  late Base base;

  setUp(() async {
    base = await ouvreBase();
    Base.remplace(base);
    Notifications.instance = FaussesNotifications();
  });

  for (final (nom, taille, texte) in [
    ('telephone', const Size(393, 852), 1.0),
    ('petit_gros_texte', const Size(360, 700), 1.3),
  ]) {
    Future<void> lance(WidgetTester tester, Widget ecran) async {
      tester.view.physicalSize = taille * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = texte;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(OuinonApp(accueil: ecran));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('questions $nom', (tester) async {
      final ids = await tester.runAsync(() async {
        return [for (final q in _questions) (await base.enregistre(q)).id!];
      });
      await tester.runAsync(() async {
        await base.repond(ids![0], mardi, 1);
        await base.repond(ids[1], mardi, 0);
      });
      await lance(tester, QuestionsScreen(maintenant: () => mardi));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/questions_$nom.png'),
      );
    });

    testWidgets('nouvelle $nom', (tester) async {
      await lance(tester, QuestionScreen(base: base));
      await tester.enterText(find.byType(TextField).first, 'En forme ?');
      await tester.tap(find.text('Réponse du milieu'));
      await tester.tap(find.text('Semaine'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/nouvelle_$nom.png'),
      );
    });
  }
}
