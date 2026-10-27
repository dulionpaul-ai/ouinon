import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/a_faire.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/screens/creneaux_screen.dart';
import 'package:ouinon/screens/edition_creneau_screen.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/choisir_screen.dart';
import 'package:ouinon/screens/placer_screen.dart';
import 'package:ouinon/screens/pret_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/edition_tache_screen.dart';
import 'package:ouinon/screens/passage_screen.dart';
import 'package:ouinon/screens/reglages_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
import 'package:ouinon/widgets/graphiques.dart';
import 'package:ouinon/widgets/grille_journee.dart';
import 'package:ouinon/widgets/retro.dart';
import 'package:ouinon/widgets/rond.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils.dart';

void main() {
  late Base base;
  late FaussesNotifications notifs;
  // Jeudi 22 octobre 2026, 12 h.
  DateTime midi() => DateTime(2026, 10, 22, 12);
  // Le même jour, 20 h : ni le jour (8 h – 20 h) ni le soir (21 h 30 –
  // 23 h) : repos, style habituel.
  DateTime soir20h() => DateTime(2026, 10, 22, 20);
  const deuxMoiVus = {'bienvenue_vue': true, 'intro_deux_moi_vue': true};

  setUp(() async {
    Curseur.clignote = false;
    SharedPreferences.setMockInitialValues({});
    base = await ouvreBase();
    Base.remplace(base);
    notifs = FaussesNotifications();
    Notifications.instance = notifs;
  });

  Future<void> ouvre(WidgetTester tester, Widget ecran) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(OuinonApp(accueil: ecran));
    await attends(tester);
  }

  testWidgets('modifier : passer de 3 à 2 réponses avec confirmation', (
    tester,
  ) async {
    final forme = (await tester.runAsync(() => base.question(2)))!;
    await tester.runAsync(() async {
      await base.repond(2, DateTime(2026, 10, 20), 1);
      await base.repond(2, DateTime(2026, 10, 21), 2);
    });
    await ouvre(tester, EditionQuestionScreen(base: base, question: forme));
    await tester.tap(find.text('2 réponses'));
    await tester.pump();
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await attends(tester);
    await tester.pumpAndSettle();
    expect(find.text('Passer à 2 réponses ?'), findsOneWidget);
    expect(
      find.textContaining('1 réponse « Moyen » sera effacée'),
      findsOneWidget,
    );
    await tester.tap(find.text('Changer'));
    await attends(tester);
    await tester.pumpAndSettle();
    final apres = (await tester.runAsync(() => base.question(2)))!;
    expect(apres.nbReponses, 2);
    expect(await tester.runAsync(() => base.reponsesDe(2)), {'2026-10-21': 1});
  });

  testWidgets('nouvelle question à 3 réponses, en semaine', (tester) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    await tester.enterText(find.byType(TextField).first, 'Stressé ?');
    await tester.tap(find.text('3 réponses'));
    await tester.pump();
    expect(find.text('Moyen'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reponse0')),
      'Pas du tout',
    );
    await tester.enterText(find.byKey(const ValueKey('reponse1')), 'Un peu');
    await tester.enterText(find.byKey(const ValueKey('reponse2')), 'Beaucoup');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('jour6')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('jour5')));
    await tester.tap(find.byKey(const ValueKey('jour6')));
    await tester.pump();
    expect(
      tester
          .widget<PiluleChoix>(find.widgetWithText(PiluleChoix, 'Semaine'))
          .choisie,
      isTrue,
    );
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await attends(tester);
    final q = (await tester.runAsync(base.questions))!.last;
    expect(q.texte, 'Stressé ?');
    expect(q.reponses, ['Pas du tout', 'Un peu', 'Beaucoup']);
    expect(q.jours, 0x1F);
  });

  testWidgets('suggestions : créer « 1 / 2 / 3 », puis la supprimer', (
    tester,
  ) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    await tester.tap(find.text('3 réponses'));
    await attends(tester);
    expect(find.text('Bien / Moyen / Pas bien'), findsOneWidget);
    expect(find.text('Oui / Non'), findsNothing);

    await tester.tap(find.text('+ Autre'));
    await tester.pumpAndSettle();
    final champs = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(champs.at(0), '3');
    await tester.enterText(champs.at(1), '2');
    await tester.enterText(champs.at(2), '1');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Enregistrer'),
      ),
    );
    await attends(tester);
    await tester.pumpAndSettle();
    // Gardée, et appliquée aux réponses.
    expect(find.text('3 / 2 / 1'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('reponse0')))
          .controller!
          .text,
      '3',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('suggestions_reponses'), contains('"3","2","1"'));

    await tester.longPress(find.text('3 / 2 / 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await attends(tester);
    await tester.pumpAndSettle();
    expect(find.text('3 / 2 / 1'), findsNothing);
  });

  testWidgets('heure : cadran sans clavier, Enregistrer caché', (tester) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    expect(find.text('Enregistrer'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('21 h'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('21 h'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
    expect(find.byIcon(Icons.keyboard_outlined), findsNothing);
    // La police des tests, très large, pousse « OK » hors de l'écran
    // simulé : on ferme le cadran avec une heure, comme « OK ».
    Navigator.of(tester.element(find.byType(TimePickerDialog)))
        .pop(const TimeOfDay(hour: 22, minute: 30));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('22 h 30'), findsOneWidget);
  });

  testWidgets('question sans texte refusée', (tester) async {
    await ouvre(tester, EditionQuestionScreen(base: base));
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await attends(tester);
    await tester.scrollUntilVisible(
      find.text('Écris la question.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Écris la question.'), findsOneWidget);
    expect(await tester.runAsync(base.questions), hasLength(4));
  });

  testWidgets('Stats : sans réponse, explication', (tester) async {
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    // Les questions d'abord, avec « Ajouter » (Décideur).
    expect(find.byKey(const ValueKey('ajouter-question')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pas encore assez de jours en commun (14 au moins).'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Les premières découvertes arrivent'),
      findsOneWidget,
    );
    expect(
      find.text('Pas encore assez de jours en commun (14 au moins).'),
      findsOneWidget,
    );
  });

  testWidgets('Stats : découvertes et comparateur avec 6 mois de test', (
    tester,
  ) async {
    await tester.runAsync(
      () => ajouteDonneesTest(base, maintenant: DateTime(2026, 10, 22)),
    );
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    await tester.pumpAndSettle();
    // Des découvertes trouvées toutes seules, avec leurs courbes.
    expect(find.textContaining('Même courbe'), findsWidgets);
    expect(find.byType(Courbes), findsWidgets);
    // Comparateur : ressemblance chiffrée, curseur de décalage.
    await tester.scrollUntilVisible(
      find.byType(Slider),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('de ressemblance'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('a-1')));
    await tester.tap(find.byKey(const ValueKey('b-2')));
    await tester.pumpAndSettle();
    final curseur = tester.widget<Slider>(find.byType(Slider));
    curseur.onChanged!(1);
    await tester.pumpAndSettle();
    expect(find.text('Courbe 2 décalée de 1 jour'), findsOneWidget);
    // Le nuage de points et la carte de chaleur sont là.
    expect(find.byType(Nuage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(CarteChaleur),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(CarteChaleur), findsOneWidget);
  });

  testWidgets('premier lancement : l\'intro des deux toi, puis notifications', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await ouvre(
      tester,
      AccueilScreen(maintenant: () => DateTime(2026, 10, 22, 20)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Il y a ', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Qui fait quoi ?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('répond d\'un geste', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Autoriser les notifications'));
    await attends(tester);
    await tester.pumpAndSettle();
    // Puis l'accueil du soir.
    expect(find.textContaining('Il y a ', findRichText: true), findsNothing);
    expect(notifs.replanifications, greaterThan(0));
    expect(find.text('Bonsoir.'), findsOneWidget);
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getBool('intro_deux_moi_vue'), isTrue);
  });

  testWidgets('heure précise non autorisée : demandée une seule fois', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(deuxMoiVus);
    notifs.precise = false;
    await ouvre(tester, AccueilScreen(maintenant: soir20h));
    expect(find.text('Questions à l\'heure pile'), findsOneWidget);
    await tester.tap(find.text('Autoriser'));
    await attends(tester);
    expect(notifs.demandesHeurePrecise, 1);

    // Deuxième ouverture : plus de fenêtre.
    await tester.pumpWidget(const SizedBox());
    await ouvre(tester, AccueilScreen(maintenant: soir20h));
    expect(find.text('Questions à l\'heure pile'), findsNothing);
  });

  testWidgets('Réglages : heure précise et prochaine question', (tester) async {
    notifs.precise = false;
    await ouvre(tester, ReglagesScreen(base: base));
    expect(find.textContaining('Heure précise non autorisée'), findsOneWidget);
    expect(find.text('Autoriser l\'heure précise'), findsOneWidget);
    expect(find.textContaining('Prochaine question :'), findsOneWidget);
    expect(
      find.text('27 notifications programmées sur le téléphone.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Autoriser l\'heure précise'));
    await attends(tester);
    expect(notifs.demandesHeurePrecise, 1);
  });

  testWidgets('Réglages : couper le bilan du dimanche', (tester) async {
    await ouvre(tester, ReglagesScreen(base: base));
    final interrupteur = find.byKey(const ValueKey('interrupteur-bilan'));
    await tester.scrollUntilVisible(
      interrupteur,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(interrupteur);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(interrupteur).value, isTrue);
    await tester.tap(interrupteur);
    await attends(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('bilan_dimanche'), isFalse);
  });

  group('to-do et journée', () {
    final vendredi = DateTime(2026, 10, 23);

    testWidgets('créneaux fixes : ajouter depuis les Réglages', (tester) async {
      await ouvre(tester, CreneauxScreen(base: base));
      await tester.tap(find.byTooltip('Ajouter un créneau'));
      await tester.pumpAndSettle();
      expect(find.byType(EditionCreneauScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Enfants');
      await tester.tap(find.text('Enregistrer'));
      await attends(tester);
      await tester.pumpAndSettle();
      final creneaux = (await tester.runAsync(base.creneaux))!;
      expect(creneaux.single.texte, 'Enfants');
      expect(find.text('Enfants'), findsOneWidget);
    });

    testWidgets('horaires qui se croisent : signalés', (tester) async {
      await tester.runAsync(
        () => base.enregistreTache(
          Tache(jour: vendredi, debut: 9 * 60, texte: 'Courses'),
        ),
      );
      await ouvre(
        tester,
        EditionTacheScreen(base: base, jour: vendredi, maintenant: midi),
      );
      // Après Courses (9 h – 10 h) : 10 h proposé.
      expect(find.text('10 h'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Garage');
      await tester.ensureVisible(find.byKey(const ValueKey('duree-180')));
      await tester.tap(find.byKey(const ValueKey('duree-180')));
      await tester.pump();
      expect(find.textContaining('Croise'), findsNothing);
      // Raccourci : ce qu'on a déjà prévu revient.
      expect(find.widgetWithText(PiluleChoix, 'Courses'), findsOneWidget);
    });

    testWidgets('Stats : le planning et sa courbe', (tester) async {
      await tester.runAsync(
        () => ajouteDonneesTest(base, maintenant: DateTime(2026, 10, 22)),
      );
      await ouvre(tester, StatsScreen(base: base, maintenant: midi));
      await tester.pumpAndSettle();
      // Le planning se compare comme une question.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('a--1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Ton planning'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ton planning'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Selon le moment'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Selon le moment'), findsOneWidget);
    });
  });

  group('le soir, préparer demain', () {
    final jeudi = DateTime(2026, 10, 22);
    final vendredi = DateTime(2026, 10, 23);
    DateTime vingtEtUne() => DateTime(2026, 10, 22, 21);

    Future<AFaire> chose(
      WidgetTester tester,
      String texte, {
      int duree = 30,
      bool important = false,
      bool urgent = false,
      int? heure,
      DateTime? pour,
    }) async => (await tester.runAsync(
      () => base.enregistreAFaire(
        AFaire(
          texte: texte,
          duree: duree,
          important: important,
          urgent: urgent,
          heure: heure,
          creeLe: jeudi,
          choisiePour: pour,
        ),
      ),
    ))!;

    testWidgets('l\'accueil : Bonsoir, l\'anneau, puis Préparer demain', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(deuxMoiVus);
      final garage = (await tester.runAsync(
        () => base.enregistreTache(
          Tache(jour: jeudi, debut: 9 * 60, texte: 'Garage'),
        ),
      ))!;
      await tester.runAsync(() => base.repondTache(garage.id!, Tache.fait));
      await tester.runAsync(
        () => base.enregistreTache(
          Tache(jour: jeudi, debut: 15 * 60, texte: 'Recyclage'),
        ),
      );
      await ouvre(tester, AccueilScreen(maintenant: vingtEtUne));
      await tester.pumpAndSettle();
      expect(find.text('Bonsoir.'), findsOneWidget);
      expect(find.text('1 faite'), findsOneWidget);
      expect(find.text('1 sans réponse'), findsOneWidget);
      expect(find.byKey(ValueKey('journee-${garage.id}')), findsOneWidget);
      // Les questions sans réponse se rattrapent ici.
      await tester.tap(find.text('8 h et +'));
      await attends(tester);
      expect(
        (await tester.runAsync(() => base.reponsesDuJour(jeudi)))!.values,
        contains(0),
      );
      await tester.tap(find.byKey(const ValueKey('preparer-demain')));
      await tester.pump();
      expect(find.byType(PassageScreen), findsOneWidget);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await attends(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ChoisirScreen), findsOneWidget);
      expect(find.text('Qu\'est-ce qui traîne ?'), findsOneWidget);
    });

    testWidgets('le jour : la chose en cours, Fait', (tester) async {
      SharedPreferences.setMockInitialValues(deuxMoiVus);
      final impots = (await tester.runAsync(
        () => base.enregistreTache(
          Tache(jour: jeudi, debut: 11 * 60, duree: 90, texte: 'Impôts'),
        ),
      ))!;
      await ouvre(tester, AccueilScreen(maintenant: midi));
      await tester.pumpAndSettle();
      expect(find.text('Bonjour.'), findsOneWidget);
      expect(find.textContaining('MAINTENANT'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fait')));
      await attends(tester);
      final t = (await tester.runAsync(() => base.tache(impots.id!)))!;
      expect(t.etat, Tache.fait);
      expect(notifs.retireesTaches, [impots.id]);
    });

    testWidgets('le rappel du soir ouvre l\'étape 1', (tester) async {
      SharedPreferences.setMockInitialValues(deuxMoiVus);
      await ouvre(tester, AccueilScreen(maintenant: vingtEtUne));
      notifs.ouverture.value = Notifications.preparer;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await attends(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ChoisirScreen), findsOneWidget);
    });

    testWidgets('étape 1 : un toucher choisit, les réglages en bas', (
      tester,
    ) async {
      final papiers = await chose(tester, 'Papiers', duree: 60);
      await chose(tester, 'Garage', important: true, urgent: true);
      await ouvre(
        tester,
        ChoisirScreen(base: base, jour: vendredi, maintenant: vingtEtUne),
      );
      await tester.pumpAndSettle();
      for (final c in Case.values) {
        expect(find.byKey(ValueKey('case-${c.name}')), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('case-peutEtreJamais')),
          matching: find.byKey(ValueKey('aimant-${papiers.id}')),
        ),
        findsOneWidget,
      );
      // Un toucher : choisie pour demain, ses réglages s'ouvrent.
      await tester.tap(find.byKey(ValueKey('aimant-${papiers.id}')));
      await attends(tester);
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => base.aFaire(papiers.id!)))!.choisiePour,
        vendredi,
      );
      expect(find.byKey(ValueKey('fiche-${papiers.id}')), findsOneWidget);
      expect(find.text('1 h'), findsWidgets);
      // Urgent et Important : elle part dans « D'abord ».
      await tester.tap(find.byKey(const ValueKey('urgent')));
      await attends(tester);
      await tester.tap(find.byKey(const ValueKey('important')));
      await attends(tester);
      await tester.tap(find.byKey(const ValueKey('duree-30')));
      await attends(tester);
      await tester.pumpAndSettle();
      final p = (await tester.runAsync(() => base.aFaire(papiers.id!)))!;
      expect((p.important, p.urgent, p.duree), (true, true, 30));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('case-dabord')),
          matching: find.byKey(ValueKey('aimant-${papiers.id}')),
        ),
        findsOneWidget,
      );
      // Un second toucher : retirée.
      await tester.tap(find.byKey(ValueKey('aimant-${papiers.id}')));
      await attends(tester);
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => base.aFaire(papiers.id!)))!.choisiePour,
        isNull,
      );
      expect(find.byKey(ValueKey('fiche-${papiers.id}')), findsNothing);
      // Écrire en vrac : « Banque 45 min », choisie pour demain.
      await tester.enterText(
        find.byKey(const ValueKey('vrac')),
        'Banque 45 min',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await attends(tester);
      await tester.pumpAndSettle();
      final banque = (await tester.runAsync(base.liste))!
          .firstWhere((a) => a.texte == 'Banque');
      expect((banque.duree, banque.choisiePour), (45, vendredi));
      expect(find.byKey(ValueKey('fiche-${banque.id}')), findsOneWidget);
    });

    testWidgets('étape 1 : une case trop pleine se replie', (tester) async {
      for (var i = 1; i <= 12; i++) {
        await chose(tester, 'Chose $i');
      }
      await ouvre(
        tester,
        ChoisirScreen(base: base, jour: vendredi, maintenant: vingtEtUne),
      );
      await tester.pumpAndSettle();
      final plus = find.byKey(const ValueKey('autres-peutEtreJamais'));
      expect(plus, findsOneWidget);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(find.text('Replier'), findsOneWidget);
      expect(find.byKey(const ValueKey('case-dabord')), findsNothing);
    });

    testWidgets('étape 2 : glisser sans appui long, sur une heure', (
      tester,
    ) async {
      final papiers = await chose(tester, 'Papiers', duree: 60, pour: vendredi);
      await ouvre(
        tester,
        PlacerScreen(base: base, jour: vendredi, maintenant: vingtEtUne),
      );
      await tester.pumpAndSettle();
      // Toute la journée (8 h – 20 h) tient dans l'écran.
      expect(
        find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
        findsNothing,
      );
      final puce = find.byKey(ValueKey('acaser-${papiers.id}'));
      final grille = tester.getRect(find.byType(GrilleJournee));
      final heure = grille.height / 12;
      final depart = tester.getCenter(puce);
      final hautPuce = tester.getTopLeft(puce).dy;
      // Le haut de la puce glissée tombe sur 14 h.
      final cible = Offset(
        grille.left + 200,
        grille.top + 6 * heure + (depart.dy - hautPuce),
      );
      final geste = await tester.startGesture(depart);
      for (var i = 1; i <= 10; i++) {
        await geste.moveTo(Offset.lerp(depart, cible, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await geste.up();
      await attends(tester);
      final prevues = (await tester.runAsync(() => base.tachesDu(vendredi)))!;
      expect(prevues.single.texte, 'Papiers');
      expect(prevues.single.debut, 14 * 60);
    });

    testWidgets('étape 2 : l\'heure imposée, C\'est prêt, Bonne nuit', (
      tester,
    ) async {
      await chose(
        tester,
        'Dentiste',
        duree: 60,
        heure: 14 * 60,
        important: true,
        pour: vendredi,
      );
      await chose(tester, 'Lessives', pour: vendredi);
      await ouvre(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlacerScreen(
                    base: base,
                    jour: vendredi,
                    maintenant: vingtEtUne,
                  ),
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      await attends(tester);
      expect(find.textContaining('à 14 h'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pret')));
      await attends(tester);
      await tester.pumpAndSettle();
      final demain = (await tester.runAsync(() => base.tachesDu(vendredi)))!;
      expect([
        for (final t in demain) t.texte,
      ], containsAll(['Dentiste', 'Lessives']));
      expect(demain.firstWhere((t) => t.texte == 'Dentiste').debut, 14 * 60);
      expect(find.byType(PretScreen), findsOneWidget);
      expect(find.text('Demain est prêt.'), findsOneWidget);
      expect(find.text('Dentiste'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bonne-nuit')));
      await tester.pumpAndSettle();
      expect(find.text('ouvrir'), findsOneWidget);
    });
  });
}
