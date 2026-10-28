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
import 'package:ouinon/models/a_faire.dart';
import 'package:ouinon/models/creneau.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/edition_a_faire_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/fiche_question_screen.dart';
import 'package:ouinon/screens/reglages_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
import 'package:ouinon/widgets/retro.dart';
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
    await _police('Oxanium', [
      for (final g in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'assets/fonts/Oxanium-$g.ttf',
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
      'retour_vu': '2026-10-22',
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
    // Arrivé de la to-do, à placer aujourd'hui.
    for (final (texte, duree) in [
      ('Couper les ongles', 15),
      ('Acheter un cadeau pour Léa', 45),
    ]) {
      await base.enregistreAFaire(
        AFaire(texte: texte, duree: duree, creeLe: jeudi, choisiePour: jeudi),
      );
    }
  });

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

  Widget page(int onglet) => AccueilScreen(
    maintenant: () => DateTime(2026, 10, 22, 12, 35),
    ongletDeDepart: onglet,
  );

  for (final (nom, onglet) in [
    ('1-todo', 0),
    ('2-aujourdhui', 1),
    ('3-questions', 2),
  ]) {
    testWidgets('page $nom', (tester) async {
      await remplit(tester);
      await capture(tester, nom, page(onglet), ThemeMode.dark);
    });
  }

  testWidgets('suivi en entier', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '5-suivi-long',
      StatsScreen(base: base, maintenant: () => maintenant),
      ThemeMode.dark,
      hauteur: 5000,
    );
  });

  testWidgets('une question', (tester) async {
    await remplit(tester);
    final q = (await tester.runAsync(() => base.question(2)))!;
    await capture(
      tester,
      '6-fiche',
      FicheQuestionScreen(
        base: base,
        question: q,
        maintenant: () => maintenant,
      ),
      ThemeMode.dark,
      hauteur: 1600,
    );
  });

  testWidgets('nouvelle question', (tester) async {
    await capture(
      tester,
      '7-nouvelle-question',
      EditionQuestionScreen(base: base),
      ThemeMode.dark,
      hauteur: 1250,
    );
  });

  testWidgets('une chose à faire', (tester) async {
    await capture(
      tester,
      '8-chose',
      EditionAFaireScreen(base: base),
      ThemeMode.dark,
    );
  });

  testWidgets('réglages', (tester) async {
    await capture(
      tester,
      '9-reglages',
      ReglagesScreen(base: base),
      ThemeMode.dark,
      hauteur: 1100,
    );
  });

  testWidgets('petit téléphone, gros texte', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '10-petit-aujourdhui',
      page(1),
      ThemeMode.dark,
      largeur: 360,
      texte: 1.3,
    );
  });

  testWidgets('petit téléphone, gros texte, questions', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '12-petit-questions',
      page(2),
      ThemeMode.dark,
      largeur: 360,
      texte: 1.3,
    );
  });

  testWidgets('petit téléphone, gros texte, to-do', (tester) async {
    await remplit(tester);
    await capture(
      tester,
      '11-petit-todo',
      page(0),
      ThemeMode.dark,
      largeur: 360,
      texte: 1.3,
    );
  });
}
