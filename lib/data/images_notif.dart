import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import '../models/apparence.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';

/// Les images des notifications, dessinées par l'appli au style HUD (26/11/2026) :
/// - l'icône à droite : la série en cours et les 7 derniers jours en
///   barres ;
/// - la grande image, quand on déplie : les 7 derniers jours, le score.
///
/// Écrites en PNG dans le dossier de la base, une paire par question,
/// refaites à chaque reprogrammation.
abstract final class ImagesNotif {
  /// Dessine et écrit les deux images ; nul si le dessin échoue (la
  /// notification part alors sans image).
  static Future<({String icone, String grande})?> ecris({
    required Question q,
    required int serie,
    required List<int?> jours,
    required Apparence a,
    required String dossier,
  }) async {
    try {
      final icone = p.join(dossier, 'notif_${q.id}_icone.png');
      final grande = p.join(dossier, 'notif_${q.id}_grande.png');
      await File(icone).writeAsBytes(
        await _png(192, 192, (c) {
          _icone(c, serie, jours, q.nbReponses, a);
        }),
      );
      await File(grande).writeAsBytes(
        await _png(1024, 440, (c) {
          _grande(c, jours, q.nbReponses, a);
        }),
      );
      return (icone: icone, grande: grande);
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> _png(
    int largeur,
    int hauteur,
    void Function(Canvas) dessin,
  ) async {
    final enregistreur = ui.PictureRecorder();
    dessin(Canvas(enregistreur));
    final image = await enregistreur.endRecording().toImage(largeur, hauteur);
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return octets!.buffer.asUint8List();
  }

  static Color _couleurJour(int? c, int nombre, Apparence a) => switch (c) {
    null => a.trait,
    -1 => a.trait,
    0 => a.meilleure,
    _ when c == nombre - 1 => a.moinsBonne,
    _ => a.milieu,
  };

  static void _texte(
    Canvas c,
    String texte,
    Offset position,
    double taille,
    Color couleur, {
    double largeur = 1000,
    TextAlign alignement = TextAlign.left,
    double espacement = 0,
  }) {
    final style = ui.ParagraphStyle(
      fontFamily: AppTheme.mono,
      fontSize: taille,
      fontWeight: FontWeight.w700,
      textAlign: alignement,
    );
    final b = ui.ParagraphBuilder(style)
      ..pushStyle(ui.TextStyle(color: couleur, letterSpacing: espacement))
      ..addText(texte);
    final paragraphe = b.build()
      ..layout(ui.ParagraphConstraints(width: largeur));
    c.drawParagraph(paragraphe, position);
  }

  /// Équerres aux coins, comme le HUD de l'appli.
  static void _equerres(Canvas c, Rect r, double longueur, Paint trait) {
    c
      ..drawLine(r.topLeft, r.topLeft.translate(longueur, 0), trait)
      ..drawLine(r.topLeft, r.topLeft.translate(0, longueur), trait)
      ..drawLine(r.bottomRight, r.bottomRight.translate(-longueur, 0), trait)
      ..drawLine(r.bottomRight, r.bottomRight.translate(0, -longueur), trait);
  }

  static void _icone(
    Canvas c,
    int serie,
    List<int?> jours,
    int nombre,
    Apparence a,
  ) {
    const cote = 192.0;
    c.drawRect(const Rect.fromLTWH(0, 0, cote, cote), Paint()..color = a.fond);
    _equerres(
      c,
      const Rect.fromLTWH(14, 14, cote - 28, cote - 28),
      26,
      Paint()
        ..color = a.meilleure
        ..strokeWidth = 5,
    );
    _texte(
      c,
      serie.toString().padLeft(2, '0'),
      const Offset(0, 34),
      72,
      serie > 0 ? a.meilleure : a.doux,
      largeur: cote,
      alignement: TextAlign.center,
    );
    const largeurBarre = 14.0, ecart = 6.0;
    const debut = (cote - 7 * largeurBarre - 6 * ecart) / 2;
    for (var i = 0; i < 7; i++) {
      c.drawRect(
        Rect.fromLTWH(
          debut + i * (largeurBarre + ecart),
          130,
          largeurBarre,
          28,
        ),
        Paint()..color = _couleurJour(jours[i], nombre, a),
      );
    }
  }

  static void _grande(Canvas c, List<int?> jours, int nombre, Apparence a) {
    const l = 1024.0, h = 440.0;
    c.drawRect(const Rect.fromLTWH(0, 0, l, h), Paint()..color = a.fond);
    if (a.grille) {
      final grille = Paint()
        ..color = a.trait.withValues(alpha: 0.55)
        ..strokeWidth = 1.5;
      for (var x = 0.0; x <= l; x += 48) {
        c.drawLine(Offset(x, 0), Offset(x, h), grille);
      }
      for (var y = 0.0; y <= h; y += 48) {
        c.drawLine(Offset(0, y), Offset(l, y), grille);
      }
    }
    _equerres(
      c,
      const Rect.fromLTWH(20, 20, l - 40, h - 40),
      40,
      Paint()
        ..color = a.meilleure
        ..strokeWidth = 6,
    );
    _texte(
      c,
      '7 DERNIERS JOURS',
      const Offset(64, 56),
      30,
      a.doux,
      espacement: 6,
    );
    final poses = jours.where((j) => j != null && j != -1).length;
    final oui = jours.where((j) => j == 0).length;
    _texte(
      c,
      '$oui/$poses',
      const Offset(0, 40),
      64,
      a.meilleure,
      largeur: l - 64,
      alignement: TextAlign.right,
    );
    const largeurBarre = 112.0, ecart = 18.0, haut = 160.0, bas = 360.0;
    for (var i = 0; i < 7; i++) {
      final x = 64 + i * (largeurBarre + ecart);
      final rect = Rect.fromLTRB(x, haut, x + largeurBarre, bas);
      if (jours[i] == -1) {
        c.drawRect(
          rect.deflate(2),
          Paint()
            ..color = a.doux
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      } else {
        c.drawRect(rect, Paint()..color = _couleurJour(jours[i], nombre, a));
      }
    }
  }
}
