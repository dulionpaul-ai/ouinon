import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/data/apparence_distante.dart';
import 'package:ouinon/data/images_notif.dart';
import 'package:ouinon/data/notifications.dart';
import 'package:ouinon/models/apparence.dart';
import 'package:ouinon/models/question.dart';

import 'outils.dart';

void main() {
  setUp(() => Apparence.actuelle = Apparence.defaut);

  test('le fichier de réglages : ce qui est lisible est pris', () {
    final a = Apparence.depuisJson('''
      {
        "couleurs": {"meilleure": "#00FF88", "fond": "pas une couleur"},
        "notification": {"symbole": "◆", "majuscules": false},
        "tailles": {"question": 30, "phrase": 500},
        "afficher": {"apercu": false},
        "textes": {"enregistrer": "VALIDER"},
        "grille": false
      }''')!;
    expect(a.meilleure, const Color(0xFF00FF88));
    expect(a.fond, Apparence.defaut.fond);
    expect(a.symbole, '◆');
    expect(a.majuscules, isFalse);
    expect(a.tailleQuestion, 30);
    expect(a.taillePhrase, Apparence.defaut.taillePhrase);
    expect(a.voirApercu, isFalse);
    expect(a.t('enregistrer'), 'VALIDER');
    expect(a.t('retour'), '‹ RETOUR');
    expect(a.grille, isFalse);
    expect(Apparence.depuisJson('pas du json'), isNull);
    expect(Apparence.depuisJson('[1, 2]'), isNull);
  });

  test('téléchargé, gardé, puis relu sans réseau', () async {
    final base = await ouvreBase();
    await ApparenceDistante.telecharge(
      base,
      lecteur: (_) async => '{"notification": {"symbole": "◆"}}',
    );
    expect(Apparence.actuelle.symbole, '◆');
    Apparence.actuelle = Apparence.defaut;
    // Sans réseau : rien ne change, la version gardée reste.
    await ApparenceDistante.telecharge(
      base,
      lecteur: (_) async => throw const SocketException('hors ligne'),
    );
    await ApparenceDistante.charge(base);
    expect(Apparence.actuelle.symbole, '◆');
  });

  test('le titre de la notification', () {
    const q = Question(texte: 'Sport ?', reponses: ['Oui', 'Non'], heure: 0);
    expect(titreNotif(q, Apparence.defaut), '▸ SPORT ?');
    expect(
      titreNotif(
        q,
        Apparence.depuisJson(
          '{"notification": {"symbole": "", "majuscules": false}}',
        )!,
      ),
      'Sport ?',
    );
  });

  testWidgets('les images de la notification sont écrites', (tester) async {
    final dossier = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('images'),
    ))!;
    final images = await tester.runAsync(
      () => ImagesNotif.ecris(
        q: const Question(
          id: 3,
          texte: 'Sport ?',
          reponses: ['Oui', 'Non'],
          heure: 0,
        ),
        serie: 4,
        jours: const [0, 1, null, -1, 0, 0, -1],
        a: Apparence.defaut,
        dossier: dossier.path,
      ),
    );
    expect(images, isNotNull);
    expect(File(images!.icone).lengthSync(), greaterThan(100));
    expect(File(images.grande).lengthSync(), greaterThan(100));
    await tester.runAsync(() => dossier.delete(recursive: true));
  });

  test('le fichier de référence donne le thème par défaut', () {
    final a = Apparence.depuisJson(
      File('reglages/reglages.json').readAsStringSync(),
    )!;
    final d = Apparence.defaut;
    expect(a.meilleure, d.meilleure);
    expect(a.fond, d.fond);
    expect(a.doux, d.doux);
    expect(a.symbole, d.symbole);
    expect(a.tailleQuestion, d.tailleQuestion);
    expect(a.textes, d.textes);
  });
}
