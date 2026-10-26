import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/base.dart';
import 'package:ouinon/data/donnees_test.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/main.dart';
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
import 'package:ouinon/screens/passage_screen.dart';
import 'package:ouinon/screens/preparer_screen.dart';
import 'package:ouinon/screens/rapport_screen.dart';
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
    expect(find.text('Aujourd\'hui'), findsOneWidget);
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
    expect(find.text('Aujourd\'hui'), findsOneWidget);
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
    await tester.tap(find.text('Je décide'));
    await tester.pumpAndSettle();
    expect(find.text('Qui est là, et quand ?'), findsOneWidget);
    expect(find.text('21:30 – 23:00'), findsOneWidget);
    expect(find.text('08:00 – 20:00'), findsOneWidget);
    await tester.tap(find.text('C\'est ça'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autoriser les notifications'));
    await attends(tester);
    // Puis l'ascenseur monte chez le Décideur, sur sa to-do.
    await tester.pump();
    expect(find.byType(PassageScreen), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.byType(PassageScreen), findsNothing);
    expect(find.textContaining('Il y a ', findRichText: true), findsNothing);
    expect(notifs.replanifications, greaterThan(0));
    expect(find.text('Bonjour, Décideur.'), findsOneWidget);
    expect(find.text('DÉCIDEUR'), findsWidgets);
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
    final jeudi = DateTime(2026, 10, 22);
    final vendredi = DateTime(2026, 10, 23);

    testWidgets('to-do : ajouter vite dans sa case, fait, annuler', (
      tester,
    ) async {
      await ouvre(tester, TodoScreen(base: base, maintenant: midi));
      expect(find.text('To-do'), findsOneWidget);
      expect(find.text('Préparer demain'), findsNothing);
      for (final c in Case.values) {
        expect(find.byKey(ValueKey('case-${c.name}')), findsOneWidget);
      }
      await tester.enterText(
        find.byKey(const ValueKey('ajout')),
        'Papiers 1 h',
      );
      await tester.tap(find.text('Important'));
      await tester.tap(find.text('Urgent'));
      await tester.tap(find.byTooltip('Ajouter'));
      await attends(tester);
      final liste = (await tester.runAsync(base.liste))!;
      expect(liste.single.texte, 'Papiers');
      expect(liste.single.duree, 60);
      expect(liste.single.important, isTrue);
      expect(liste.single.urgent, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('case-dabord')),
          matching: find.text('Papiers'),
        ),
        findsOneWidget,
      );
      expect(find.text('Préparer demain'), findsOneWidget);
      // Appui long : fait.
      await tester.longPress(find.byKey(ValueKey('todo-${liste.single.id}')));
      await attends(tester);
      expect((await tester.runAsync(base.liste))!, isEmpty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await attends(tester);
      expect((await tester.runAsync(base.liste))!, hasLength(1));
    });

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
      await tester.enterText(find.byKey(const ValueKey('ajout')), 'Banque');
      await tester.tap(find.byTooltip('Ajouter'));
      await attends(tester);
      expect(find.text('Bonjour, Décideur.'), findsNothing);
      expect(find.text('To-do'), findsOneWidget);
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

    testWidgets('le rappel du soir ouvre « Préparer demain »', (tester) async {
      SharedPreferences.setMockInitialValues(deuxMoiVus);
      await ouvre(tester, AccueilScreen(maintenant: soir20h));
      notifs.ouverture.value = Notifications.preparer;
      await tester.pumpAndSettle();
      await attends(tester);
      expect(find.byType(PreparerScreen), findsOneWidget);
      expect(find.text('Demain, je fais…'), findsOneWidget);
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

  group('les deux toi', () {
    final jeudi = DateTime(2026, 10, 22);
    final vendredi = DateTime(2026, 10, 23);
    DateTime dixHeures() => DateTime(2026, 10, 22, 10, 30);
    DateTime vingtDeux() => DateTime(2026, 10, 22, 22);

    /// Laisse l'ascenseur aller au bout, image par image.
    Future<void> ascenseur(WidgetTester tester) async {
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

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

    testWidgets('le jour : l\'Exécutant, la chose en cours, Fait', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        ...deuxMoiVus,
        'reveil_vu': '2026-10-22',
        'mot_2026-10-22': 'Les impôts d\'abord',
      });
      final tache = await impots(tester);
      await ouvre(tester, AccueilScreen(maintenant: dixHeures));
      await attends(tester);
      expect(find.text('Bonjour, Exécutant.'), findsOneWidget);
      expect(find.text('EXÉCUTANT'), findsOneWidget);
      expect(
        find.textContaining('Les impôts d\'abord', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Maintenant'), findsOneWidget);
      expect(find.text('Déclarer les impôts'), findsWidgets);
      expect(find.text('Jusqu\'à 11 h 30 · encore 1 h'), findsOneWidget);
      expect(find.byKey(ValueKey('calendrier-${tache.id}')), findsOneWidget);
      await tester.tap(find.text('Fait'));
      await attends(tester);
      final apres = (await tester.runAsync(() => base.tache(tache.id!)))!;
      expect(apres.etat, Tache.fait);
      expect(find.text('Plus rien à faire aujourd\'hui.'), findsOneWidget);
      // L'onglet To-do n'est pas l'écran de l'Exécutant.
      await tester.tap(find.text('To-do'));
      await tester.pumpAndSettle();
      expect(find.text('Bonjour, Exécutant.'), findsNothing);
    });

    testWidgets('changer de toi à la main : ascenseur vers le Décideur', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        ...deuxMoiVus,
        'reveil_vu': '2026-10-22',
      });
      await ouvre(tester, AccueilScreen(maintenant: dixHeures));
      await attends(tester);
      expect(find.text('Bonjour, Exécutant.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bascule')));
      await tester.pump();
      expect(find.byType(PassageScreen), findsOneWidget);
      await ascenseur(tester);
      await tester.pumpAndSettle();
      expect(find.text('Bonjour, Décideur.'), findsOneWidget);
      // Et retour.
      await tester.tap(find.byKey(const ValueKey('bascule')).first);
      await tester.pump();
      await ascenseur(tester);
      await tester.pumpAndSettle();
      expect(find.text('Bonjour, Exécutant.'), findsOneWidget);
    });

    testWidgets('le matin : l\'ascenseur, une fois par jour', (tester) async {
      SharedPreferences.setMockInitialValues(deuxMoiVus);
      await impots(tester);
      await ouvre(tester, AccueilScreen(maintenant: dixHeures));
      await attends(tester);
      expect(find.byType(PassageScreen), findsOneWidget);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('EXÉCUTANT'), findsWidgets);
      await ascenseur(tester);
      await tester.pumpAndSettle();
      expect(find.byType(PassageScreen), findsNothing);
      expect(find.text('Bonjour, Exécutant.'), findsOneWidget);
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      expect(prefs.getString('reveil_vu'), '2026-10-22');
    });

    testWidgets('le soir : le compte rendu, un mot, fin de service', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(deuxMoiVus);
      await impots(tester);
      await ouvre(tester, AccueilScreen(maintenant: vingtDeux));
      await attends(tester);
      expect(find.text('Ce que ton toi du jour te remonte'), findsOneWidget);
      expect(find.text('Préparer demain'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('remonte')));
      await tester.pumpAndSettle();
      await attends(tester);
      expect(find.byType(RapportScreen), findsOneWidget);
      expect(find.text('0 SUR 1'), findsOneWidget);
      expect(find.textContaining('REVIENT DANS LA TO-DO'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('mot-soir')),
        'Trop de papiers',
      );
      await tester.ensureVisible(find.text('[ FIN DE SERVICE ]'));
      await tester.tap(find.text('[ FIN DE SERVICE ]'));
      await attends(tester);
      expect(find.byType(PassageScreen), findsOneWidget);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('DÉCIDEUR'), findsWidgets);
      await ascenseur(tester);
      await tester.pumpAndSettle();
      expect(find.byType(PassageScreen), findsNothing);
      expect(find.byType(RapportScreen), findsNothing);
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      expect(prefs.getString('mot_soir_2026-10-22'), 'Trop de papiers');
    });

    testWidgets('préparer demain : un mot pour demain, transmis', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(deuxMoiVus);
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
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PreparerScreen(
                    base: base,
                    jour: vendredi,
                    maintenant: vingtDeux,
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
      await tester.tap(find.text('Suivant : caser dans la journée'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer'));
      await attends(tester);
      await tester.pumpAndSettle();
      expect(find.text('Un mot pour toi, demain ?'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('mot-demain')),
        'Les papiers d\'abord',
      );
      await tester.tap(find.text('Transmettre'));
      await attends(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Transmis à l\'Exécutant'), findsOneWidget);
      expect(find.text('ouvrir'), findsOneWidget);
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      expect(prefs.getString('mot_2026-10-23'), 'Les papiers d\'abord');
    });
  });
}
