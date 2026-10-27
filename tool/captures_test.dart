// Captures d'écran de l'appli (polices réelles), pour vérifier avant un APK.
// Lancement : flutter test tool/captures_test.dart --update-goldens
// Images écrites dans tool/captures/ (non commitées).
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/screens/question_screen.dart';
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
    final sdk = File(Platform.resolvedExecutable).parent.parent.parent.path;
    // La police du téléphone (Android) : Roboto.
    await _police('Roboto', [
      for (final g in ['Regular', 'Medium', 'Bold'])
        '$sdk/material_fonts/Roboto-$g.ttf',
    ]);
    await _police('MaterialIcons', [
      '$sdk/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  late Base base;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'notifs_demandees': true});
    base = await ouvreBase(depart: false);
    Base.remplace(base);
    Notifications.instance = FaussesNotifications();
  });

  Future<void> remplit(WidgetTester tester) => tester.runAsync(() async {
    for (final q in const [
      Question(
        texte: 'Sommeil ?',
        reponses: ['8 h et +', '6 à 8 h', 'Moins de 6 h'],
        heure: 9 * 60,
      ),
      Question(
        texte: 'Sport ?',
        reponses: ['Oui', 'Non'],
        heure: 21 * 60,
        jours: 0x15,
      ),
      Question(
        texte: 'En forme ?',
        reponses: ['Bien', 'Moyen', 'Pas bien'],
        heure: 21 * 60,
        jours: 0x1F,
      ),
      Question(
        texte: 'Lecture ?',
        reponses: ['Oui', 'Non'],
        heure: 22 * 60 + 30,
        jours: 0,
      ),
    ]) {
      await base.enregistre(q);
    }
  });

  Future<void> capture(
    WidgetTester tester,
    String nom,
    Widget? ecran, {
    double hauteur = 844,
    double largeur = 390,
    double texte = 1,
    Future<void> Function(WidgetTester)? avant,
  }) async {
    tester.view.physicalSize = Size(largeur * 2, hauteur * 2);
    tester.platformDispatcher.textScaleFactorTestValue = texte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(OuinonApp(accueil: ecran));
    await attends(tester, 15);
    await tester.pumpAndSettle();
    if (avant != null) await avant(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/$nom.png'),
    );
  }

  testWidgets('mes questions', (tester) async {
    await remplit(tester);
    await capture(tester, '1-questions', null);
  });

  testWidgets('mes questions, vide', (tester) async {
    await capture(tester, '2-vide', null);
  });

  testWidgets('nouvelle question', (tester) async {
    await capture(
      tester,
      '3-nouvelle',
      QuestionScreen(base: base),
      avant: (tester) async {
        await tester.enterText(find.byKey(const ValueKey('texte')), 'Sport ?');
        await tester.enterText(
          find.byKey(const ValueKey('reponse-meilleure')),
          'Oui',
        );
        await tester.enterText(
          find.byKey(const ValueKey('reponse-moins-bonne')),
          'Non',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('modifier une question', (tester) async {
    await remplit(tester);
    final q = (await tester.runAsync(base.questions))!.first;
    await capture(
      tester,
      '4-modifier',
      QuestionScreen(base: base, question: q),
    );
  });

  testWidgets('petit téléphone, gros texte', (tester) async {
    await remplit(tester);
    await capture(tester, '5-petit', null, largeur: 360, texte: 1.3);
  });

  testWidgets('petit téléphone, gros texte, modifier', (tester) async {
    await remplit(tester);
    final q = (await tester.runAsync(base.questions))!.first;
    await capture(
      tester,
      '6-petit-modifier',
      QuestionScreen(base: base, question: q),
      largeur: 360,
      hauteur: 1000,
      texte: 1.3,
    );
  });
}
