import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
import 'package:ouinon/models/question.dart';
import 'package:ouinon/screens/groupe_screen.dart';
import 'package:ouinon/models/a_faire.dart';
import 'package:ouinon/models/tache.dart';
import 'package:ouinon/models/creneau.dart';
import 'package:ouinon/screens/edition_a_faire_screen.dart';
import 'package:ouinon/screens/creneaux_screen.dart';
import 'package:ouinon/screens/edition_creneau_screen.dart';
import 'package:ouinon/screens/accueil_screen.dart';
import 'package:ouinon/screens/aujourdhui_screen.dart';
import 'package:ouinon/screens/edition_question_screen.dart';
import 'package:ouinon/screens/edition_tache_screen.dart';
import 'package:ouinon/screens/preparer_screen.dart';
import 'package:ouinon/screens/todo_screen.dart';
import 'package:ouinon/screens/reglages_screen.dart';
import 'package:ouinon/screens/stats_screen.dart';
import 'package:ouinon/utils/deux_moi.dart';
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

  testWidgets('Aujourd\'hui : répondre, changer, effacer', (tester) async {
    final semantique = tester.ensureSemantics();
    await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
    expect(find.text('Missions'), findsOneWidget);
    expect(find.text('Jeu. 22 oct.'), findsOneWidget);
    expect(find.text('Sommeil ?'), findsOneWidget);
    expect(find.bySemanticsLabel('0 sur 4 répondue'), findsOneWidget);

    await tester.tap(find.text('6 à 8 h'));
    await attends(tester);
    final jour = DateTime(2026, 10, 22);
    expect(await tester.runAsync(() => base.reponsesDuJour(jour)), {1: 1});
    expect(find.bySemanticsLabel('1 sur 4 répondue'), findsOneWidget);
    expect(notifs.retirees, hasLength(1));

    // Répondue, la question tient sur une ligne ; toucher la réponse
    // rouvre les boutons, et toucher à nouveau la réponse choisie l'efface.
    expect(find.text('Moins de 6 h'), findsNothing);
    await tester.tap(find.text('6 à 8 h'));
    await tester.pump();
    expect(find.text('Moins de 6 h'), findsOneWidget);
    await tester.tap(find.text('6 à 8 h'));
    await attends(tester);
    expect(await tester.runAsync(() => base.reponsesDuJour(jour)), isEmpty);
    semantique.dispose();
  });

  testWidgets('Aujourd\'hui : revenir sur hier', (tester) async {
    final semantique = tester.ensureSemantics();
    await tester.runAsync(() => base.repond(3, DateTime(2026, 10, 21), 0));
    await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    await attends(tester);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('Mer. 21 oct.'), findsOneWidget);
    expect(find.bySemanticsLabel('1 sur 4 répondue'), findsOneWidget);
    semantique.dispose();
  });

  testWidgets('Aujourd\'hui : glisser vers la droite montre la veille', (
    tester,
  ) async {
    await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
    // Vers la gauche : rien après aujourd'hui.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await attends(tester);
    expect(find.text('Missions'), findsOneWidget);
    // Vers la droite : hier, puis avant-hier.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    await attends(tester);
    expect(find.text('Hier'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    await attends(tester);
    expect(find.text('Mardi'), findsOneWidget);
    expect(find.text('Mar. 20 oct.'), findsOneWidget);
  });

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
    // Pas de modèle : trois champs à remplir soi-même.
    expect(find.byKey(const ValueKey('reponse2')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reponse0')),
      'Pas du tout',
    );
    await tester.enterText(find.byKey(const ValueKey('reponse1')), 'Un peu');
    await tester.enterText(find.byKey(const ValueKey('reponse2')), 'Beaucoup');
    await tester.scrollUntilVisible(
      find.widgetWithText(PiluleChoix, 'Semaine'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Aucun jour par défaut ; le raccourci « Semaine ».
    await tester.tap(find.widgetWithText(PiluleChoix, 'Semaine'));
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

  testWidgets('le bandeau du bas : To-do, Aujourd\'hui, Suivi, Demain', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'notifs_demandees': true,
      'heure_precise_demandee': true,
    });
    await ouvre(tester, AccueilScreen(maintenant: midi));
    await tester.pumpAndSettle();
    // On arrive sur Aujourd'hui.
    expect(find.byType(AujourdhuiScreen), findsOneWidget);
    for (final (i, ecran) in [
      (0, TodoScreen),
      (2, StatsScreen),
      (3, PreparerScreen),
      (1, AujourdhuiScreen),
    ]) {
      await tester.tap(find.byKey(ValueKey('onglet-$i')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Offstage).hitTestable(),
          matching: find.byType(ecran),
        ),
        findsWidgets,
      );
    }
    expect(find.text('RÉSERVE'), findsOneWidget);
    expect(find.text('PLAN DE VOL'), findsOneWidget);
  });

  testWidgets('le jeu : bandeau en haut, niveau passé fêté une fois', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'notifs_demandees': true,
      'heure_precise_demandee': true,
      'jeu_niveau_vu': 1,
    });
    // Quatre choses de 1 h 30 faites : 4 × 35 + synchro parfaite 50.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => base.enregistreTache(
          Tache(
            jour: DateTime(2026, 10, 22),
            debut: 8 * 60 + 90 * i,
            duree: 90,
            texte: 'Chose $i',
            etat: Tache.fait,
          ),
        ),
      );
    }
    await ouvre(tester, AccueilScreen(maintenant: midi));
    await attends(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('niveau-suivant')), findsOneWidget);
    expect(find.text('NIVEAU'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('niveau-suivant')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('niveau-suivant')), findsNothing);
    final niveau = tester.widget<Text>(
      find.byKey(const ValueKey('niveau-jeu')),
    );
    expect(niveau.data, '2');
    final duJour = tester.widget<Text>(
      find.byKey(const ValueKey('points-du-jour')),
    );
    expect(duJour.data, '+190');
    expect((await SharedPreferences.getInstance()).getInt('jeu_niveau_vu'), 2);
    // Les points de chaque mission.
    expect(find.text('+35'), findsWidgets);
    // Le détail des points du jour.
    await tester.tap(find.byKey(const ValueKey('bandeau-jeu')));
    await tester.pumpAndSettle();
    expect(find.text('Synchro parfaite'), findsOneWidget);
  });

  testWidgets('ajouter : ce qui existe déjà s\'affiche en tapant', (
    tester,
  ) async {
    final ongles = (await tester.runAsync(
      () => base.enregistreAFaire(
        AFaire(texte: 'Couper les ongles', creeLe: DateTime(2026, 10, 22)),
      ),
    ))!;
    await ouvre(tester, EditionAFaireScreen(base: base, maintenant: midi));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('micro')), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Me couper les ongl');
    await tester.pump();
    expect(find.text('Déjà dans ta liste :'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('existante-${ongles.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Modifier'), findsWidgets);
  });

  testWidgets('to-do : tirer une chose vers « Aujourd\'hui »', (tester) async {
    final papiers = (await tester.runAsync(
      () => base.enregistreAFaire(
        AFaire(
          texte: 'Papiers',
          duree: 60,
          important: true,
          urgent: true,
          creeLe: DateTime(2026, 10, 22),
        ),
      ),
    ))!;
    await ouvre(tester, TodoScreen(base: base, maintenant: midi));
    await tester.pumpAndSettle();
    final chose = find.byKey(ValueKey('todo-${papiers.id}'));
    final depart = tester.getCenter(chose);
    final cible = tester.getCenter(
      find.byKey(const ValueKey('cible-aujourdhui')),
    );
    final geste = await tester.startGesture(depart);
    for (var k = 1; k <= 12; k++) {
      await geste.moveTo(Offset.lerp(depart, cible, k / 12)!);
      await tester.pump(const Duration(milliseconds: 30));
    }
    // La cible s'est élargie : on vise son nouveau centre.
    await geste.moveTo(
      tester.getCenter(find.byKey(const ValueKey('cible-aujourdhui'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await geste.up();
    await attends(tester);
    final jeudi = (await tester.runAsync(
      () => base.tachesDu(DateTime(2026, 10, 22)),
    ))!;
    expect(jeudi.single.texte, 'Papiers');
    expect(jeudi.single.listeId, papiers.id);
    expect(jeudi.single.debut, greaterThanOrEqualTo(12 * 60));
  });

  testWidgets('Suivi : un groupe s\'ouvre sur son analyse et son détail', (
    tester,
  ) async {
    final ids = <int>[];
    for (final texte in ['Cardio ?', 'Muscu ?']) {
      final q = (await tester.runAsync(
        () => base.enregistre(
          Question(
            texte: texte,
            reponses: const ['Oui', 'Non'],
            heure: 1260,
            famille: 'Sport',
          ),
        ),
      ))!;
      ids.add(q.id!);
    }
    await tester.runAsync(() async {
      await base.repond(ids[0], DateTime(2026, 10, 21), 0);
      await base.repond(ids[1], DateTime(2026, 10, 21), 0);
      await base.repond(ids[0], DateTime(2026, 10, 22), 0);
      await base.repond(ids[1], DateTime(2026, 10, 22), 1);
    });
    await ouvre(tester, StatsScreen(base: base, maintenant: midi));
    await tester.pumpAndSettle();
    final carte = find.byKey(const ValueKey('famille-Sport'));
    await tester.scrollUntilVisible(
      carte,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(carte);
    await tester.pumpAndSettle();
    expect(find.byType(GroupeScreen), findsOneWidget);
    // 2 puis 1 : 1,5 sur 2 en moyenne.
    expect(find.text('1,5 sur 2'), findsOneWidget);
    for (final id in ids) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('membre-$id')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(ValueKey('membre-$id')), findsOneWidget);
    }
  });

  group('to-do et journée', () {
    final jeudi = DateTime(2026, 10, 22);
    final vendredi = DateTime(2026, 10, 23);

    testWidgets(
      'to-do : Ajouter ouvre le formulaire, la chose va dans sa case',
      (tester) async {
        await ouvre(tester, TodoScreen(base: base, maintenant: midi));
        expect(find.text('Réserve'), findsOneWidget);
        for (final c in Case.values) {
          expect(find.byKey(ValueKey('case-${c.name}')), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('ajouter')));
        await tester.pumpAndSettle();
        expect(find.byType(EditionAFaireScreen), findsOneWidget);
        expect(find.text('Heure imposée'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, 'Papiers');
        await tester.tap(find.byKey(const ValueKey('duree-60')));
        await tester.tap(find.byKey(const ValueKey('important')));
        await tester.tap(find.byKey(const ValueKey('urgent')));
        await tester.pump();
        await tester.tap(find.text('Enregistrer'));
        await attends(tester);
        await tester.pumpAndSettle();
        final liste = (await tester.runAsync(base.liste))!;
        expect(liste.single.texte, 'Papiers');
        expect(liste.single.duree, 60);
        expect(liste.single.important, isTrue);
        expect(liste.single.urgent, isTrue);
        expect(liste.single.heure, isNull);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('case-dabord')),
            matching: find.textContaining('Papiers', findRichText: true),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('le Décideur : « Bonjour, Décideur. » tant que c\'est vide', (
      tester,
    ) async {
      await ouvre(
        tester,
        TodoScreen(base: base, moi: Moi.decideur, maintenant: midi),
      );
      expect(find.text('Bonjour, Décideur.'), findsOneWidget);
      expect(
        find.textContaining('l\'exécutant le fera', findRichText: true),
        findsOneWidget,
      );
      await tester.runAsync(
        () => base.enregistreAFaire(
          AFaire(texte: 'Banque', creeLe: DateTime(2026, 10, 22)),
        ),
      );
      await attends(tester);
      expect(find.text('Bonjour, Décideur.'), findsNothing);
      expect(find.text('Réserve'), findsOneWidget);
    });

    testWidgets('une chose : Important et Urgent sur une ligne', (
      tester,
    ) async {
      final a = (await tester.runAsync(
        () => base.enregistreAFaire(AFaire(texte: 'Papiers', creeLe: jeudi)),
      ))!;
      await ouvre(
        tester,
        EditionAFaireScreen(base: base, aFaire: a, maintenant: midi),
      );
      final important = tester.getCenter(
        find.byKey(const ValueKey('important')),
      );
      final urgent = tester.getCenter(find.byKey(const ValueKey('urgent')));
      expect(important.dy, urgent.dy);
      await tester.tap(find.byKey(const ValueKey('important')));
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await attends(tester);
      final apres = (await tester.runAsync(() => base.aFaire(a.id!)))!;
      expect(apres.important, isTrue);
      expect(apres.urgent, isFalse);
    });

    Future<void> prepareDemain(WidgetTester tester) =>
        tester.runAsync(() async {
          await base.enregistreTache(
            Tache(jour: vendredi, debut: 9 * 60, texte: 'Garage C3'),
          );
          await base.enregistreCreneau(
            const Creneau(texte: 'Enfants', debut: 17 * 60, fin: 23 * 60),
          );
          await base.enregistreAFaire(
            AFaire(texte: 'Papiers', duree: 60, important: true, creeLe: jeudi),
          );
          await base.enregistreAFaire(
            AFaire(
              texte: 'Plombier',
              duree: 30,
              important: true,
              urgent: true,
              creeLe: jeudi,
            ),
          );
          await base.enregistreAFaire(
            AFaire(texte: 'Déménagement', duree: 8 * 60, creeLe: jeudi),
          );
        });

    testWidgets('préparer demain : choisir, la jauge, terminer', (
      tester,
    ) async {
      await prepareDemain(tester);
      await ouvre(
        tester,
        PreparerScreen(base: base, jour: vendredi, maintenant: midi),
      );
      expect(find.text('Demain, je fais…'), findsOneWidget);
      expect(find.textContaining('Garage C3 à 9 h'), findsOneWidget);
      // 8 h – 20 h, moins le garage et les enfants (17 h – 20 h) : 8 h.
      expect(find.text('sur 8 h de libre'), findsOneWidget);
      await tester.tap(find.text('Papiers'));
      await attends(tester);
      await tester.tap(find.text('Plombier'));
      await attends(tester);
      expect(find.text('Choisi : 1 h 30'), findsOneWidget);
      expect(find.text('Ça rentre, il reste 6 h 30.'), findsOneWidget);
      await tester.tap(find.text('Déménagement'));
      await attends(tester);
      expect(find.text('Trop plein : 1 h 30 de trop.'), findsOneWidget);
      await tester.tap(find.text('Déménagement'));
      await attends(tester);
      await tester.tap(find.text('Suivant : caser dans la journée'));
      await attends(tester);
      expect(find.text('Quand ?'), findsOneWidget);
      expect(find.byKey(const ValueKey('acaser-1')), findsOneWidget);
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
      await attends(tester);
      final demain = (await tester.runAsync(() => base.tachesDu(vendredi)))!;
      // Dès 8 h, le plombier (urgent et important) tient avant le garage ;
      // les papiers après le garage et sa marge.
      expect(
        [for (final t in demain) (t.texte, t.debut)],
        [
          ('Plombier', 8 * 60),
          ('Garage C3', 9 * 60),
          ('Papiers', 10 * 60 + 15),
        ],
      );
    });

    testWidgets('préparer demain : glisser une chose sur une heure', (
      tester,
    ) async {
      await tester.runAsync(
        () => base.enregistreAFaire(
          AFaire(
            texte: 'Papiers',
            duree: 60,
            creeLe: jeudi,
            choisiePour: vendredi,
          ),
        ),
      );
      await ouvre(
        tester,
        PreparerScreen(base: base, jour: vendredi, maintenant: midi),
      );
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      await tester.tap(find.text('Suivant : caser dans la journée'));
      await tester.pumpAndSettle();
      final puce = find.byKey(const ValueKey('acaser-1'));
      expect(puce, findsOneWidget);
      final grille = tester.getTopLeft(find.byType(GrilleJournee));
      final depart = tester.getCenter(puce);
      final hautPuce = tester.getTopLeft(puce).dy;
      // Le haut de la puce glissée tombe sur 14 h (40 px par heure).
      final cible = Offset(
        grille.dx + 200,
        grille.dy + 6 * 40 + (depart.dy - hautPuce),
      );
      final geste = await tester.startGesture(depart);
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 1; i <= 10; i++) {
        await geste.moveTo(Offset.lerp(depart, cible, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await geste.up();
      await attends(tester);
      final prevues = (await tester.runAsync(() => base.tachesDu(vendredi)))!;
      expect(prevues.single.texte, 'Papiers');
      expect(prevues.single.debut, 14 * 60);
      expect(prevues.single.listeId, 1);
    });

    testWidgets('aujourd\'hui : ma journée, cocher fait', (tester) async {
      final papiers = (await tester.runAsync(
        () => base.enregistreAFaire(
          AFaire(texte: 'Papiers', duree: 60, creeLe: jeudi),
        ),
      ))!;
      final casee = (await tester.runAsync(
        () => base.enregistreTache(
          Tache(
            jour: jeudi,
            debut: 14 * 60,
            texte: 'Papiers',
            listeId: papiers.id,
          ),
        ),
      ))!;
      await tester.runAsync(
        () => base.enregistreCreneau(
          const Creneau(texte: 'Enfants', debut: 17 * 60, fin: 23 * 60),
        ),
      );
      await ouvre(tester, AujourdhuiScreen(base: base, maintenant: midi));
      await tester.scrollUntilVisible(
        find.text('Enfants'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Ma journée'), findsOneWidget);
      expect(find.text('Papiers'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byKey(ValueKey('journee-${casee.id}')),
              matching: find.byType(InkResponse),
            )
            .last,
      );
      await attends(tester);
      expect(
        (await tester.runAsync(() => base.tache(casee.id!)))!.etat,
        Tache.fait,
      );
      expect((await tester.runAsync(base.liste))!, isEmpty);
      expect(notifs.retireesTaches, [casee.id]);
    });

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

    testWidgets('le rappel du soir ouvre « Planifier demain »', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...deuxMoiVus,
        'role_actif': 'executant',
      });
      await ouvre(tester, AccueilScreen(maintenant: soir20h));
      notifs.ouverture.value = Notifications.preparer;
      await tester.pumpAndSettle();
      await attends(tester);
      // L'onglet « Demain » est choisi.
      final demain = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('onglet-3')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(demain.properties.selected, isTrue);
    });

    testWidgets('Planifier : l\'heure imposée est respectée', (tester) async {
      SharedPreferences.setMockInitialValues(deuxMoiVus);
      await tester.runAsync(
        () => base.enregistreAFaire(
          AFaire(
            texte: 'Dentiste',
            duree: 60,
            heure: 14 * 60,
            creeLe: jeudi,
            important: true,
          ),
        ),
      );
      await ouvre(tester, AccueilScreen(maintenant: midi));
      await attends(tester);
      await tester.tap(find.byKey(const ValueKey('onglet-3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('acaser-1')), findsOneWidget);
      expect(find.textContaining('à 14 h'), findsOneWidget);
      await tester.tap(find.text('Caser pour moi'));
      await attends(tester);
      final demain = (await tester.runAsync(() => base.tachesDu(vendredi)))!;
      expect(
        [for (final t in demain) (t.texte, t.debut)],
        [('Dentiste', 14 * 60)],
      );
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

  group('Aujourd\'hui', () {
    final jeudi = DateTime(2026, 10, 22);
    DateTime dixHeures() => DateTime(2026, 10, 22, 10, 30);

    Future<Tache> impots(WidgetTester tester) async => (await tester.runAsync(
      () => base.enregistreTache(
        Tache(
          jour: jeudi,
          debut: 10 * 60,
          duree: 90,
          texte: 'Déclarer les impôts',
        ),
      ),
    ))!;

    testWidgets('l\'Exécutant ajoute une chose à sa journée', (tester) async {
      SharedPreferences.setMockInitialValues({
        ...deuxMoiVus,
        'role_actif': 'executant',
      });
      await impots(tester);
      await ouvre(tester, AccueilScreen(maintenant: dixHeures));
      await attends(tester);
      final ajouter = find.byKey(const ValueKey('ajouter-journee'));
      await tester.scrollUntilVisible(
        ajouter,
        300,
        scrollable: find
            .descendant(
              of: find.byType(AujourdhuiScreen),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      Scrollable.ensureVisible(tester.element(ajouter), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(ajouter);
      await tester.pumpAndSettle();
      expect(find.byType(EditionTacheScreen), findsOneWidget);
      // Laisse finir les minuteries de l'écran (10 s).
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
