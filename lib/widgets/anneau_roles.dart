import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/planning.dart';

/// L'anneau des 24 heures (maquette validée par Paul le 26/10/2026) :
/// toujours plein, bleu-vert pour l'Exécutant (la journée, de [debut] à
/// [fin]), ambre pour le Décideur (le reste). On glisse les deux ronds
/// blancs autour de l'anneau, par quarts d'heure ; minuit est en haut.
/// La journée ne passe pas minuit, et chaque toi garde au moins une heure.
class AnneauRoles extends StatefulWidget {
  final int debut;
  final int fin;
  final void Function(int debut, int fin) onChange;

  const AnneauRoles({
    super.key,
    required this.debut,
    required this.fin,
    required this.onChange,
  });

  /// Pas des poignées, en minutes.
  static const pas = 15;

  /// Durée minimale de chaque toi, en minutes.
  static const minimum = 60;

  /// La nouvelle journée quand on pose la poignée [debutBouge] (sinon la
  /// fin) sur [minute] ; nulle si ce n'est pas permis.
  static ({int debut, int fin})? place({
    required int debut,
    required int fin,
    required bool debutBouge,
    required int minute,
  }) {
    var m = (minute / pas).round() * pas % (24 * 60);
    final d = debutBouge ? m : debut;
    // La fin peut aller jusqu'à minuit (24 h, en haut de l'anneau).
    if (!debutBouge && m == 0) m = 24 * 60;
    final f = debutBouge ? fin : m;
    if (f - d < minimum || 24 * 60 - (f - d) < minimum) return null;
    return (debut: d, fin: f);
  }

  @override
  State<AnneauRoles> createState() => _AnneauRolesState();
}

class _AnneauRolesState extends State<AnneauRoles> {
  /// La poignée qu'on tient : début, fin, ou aucune.
  bool? _debutTenu;

  static const _epaisseur = 28.0;
  static const _poignee = 19.0;

  /// Minute sous le doigt (minuit en haut, sens des aiguilles).
  int _minute(Offset p, Size taille) {
    final c = taille.center(Offset.zero);
    final a = math.atan2(p.dy - c.dy, p.dx - c.dx) + math.pi / 2;
    final tour = (a / (2 * math.pi)) % 1;
    return (tour * 24 * 60).round();
  }

  static Offset _point(int minute, Size taille, double rayon) {
    final a = minute / (24 * 60) * 2 * math.pi - math.pi / 2;
    return taille.center(Offset.zero) +
        Offset(math.cos(a), math.sin(a)) * rayon;
  }

  double _rayon(Size taille) => taille.shortestSide / 2 - _poignee - 4;

  void _prend(Offset p, Size taille) {
    final r = _rayon(taille);
    final dDebut = (p - _point(widget.debut, taille, r)).distance;
    final dFin = (p - _point(widget.fin, taille, r)).distance;
    final proche = math.min(dDebut, dFin);
    _debutTenu = proche > 48 ? null : dDebut <= dFin;
  }

  void _bouge(Offset p, Size taille) {
    final tenu = _debutTenu;
    if (tenu == null) return;
    final nouveau = AnneauRoles.place(
      debut: widget.debut,
      fin: widget.fin,
      debutBouge: tenu,
      minute: _minute(p, taille),
    );
    if (nouveau == null ||
        (nouveau.debut == widget.debut && nouveau.fin == widget.fin)) {
      return;
    }
    HapticFeedback.selectionClick();
    widget.onChange(nouveau.debut, nouveau.fin);
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final jour = widget.fin - widget.debut;
    return LayoutBuilder(
      builder: (context, contraintes) {
        final cote = math.min(contraintes.maxWidth, 300.0);
        final taille = Size.square(cote);
        return Center(
          child: GestureDetector(
            key: const ValueKey('anneau'),
            onPanStart: (d) => _prend(d.localPosition, taille),
            onPanUpdate: (d) => _bouge(d.localPosition, taille),
            onPanEnd: (_) => _debutTenu = null,
            child: CustomPaint(
              size: taille,
              painter: _Anneau(
                debut: widget.debut,
                fin: widget.fin,
                rayon: _rayon(taille),
                epaisseur: _epaisseur,
                poignee: _poignee,
                doux: t.doux,
                blanc: t.texte,
                fond: t.fond,
              ),
              child: SizedBox.fromSize(
                size: taille,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Exécutant · ${dureeFr(jour)}',
                        style: const TextStyle(
                          color: AppTheme.bleuVert,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Décideur · ${dureeFr(24 * 60 - jour)}',
                        style: const TextStyle(
                          color: AppTheme.ambre,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Anneau extends CustomPainter {
  final int debut;
  final int fin;
  final double rayon;
  final double epaisseur;
  final double poignee;
  final Color doux;
  final Color blanc;
  final Color fond;

  const _Anneau({
    required this.debut,
    required this.fin,
    required this.rayon,
    required this.epaisseur,
    required this.poignee,
    required this.doux,
    required this.blanc,
    required this.fond,
  });

  static double _angle(int minute) =>
      minute / (24 * 60) * 2 * math.pi - math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: rayon);
    Paint trait(Color couleur) => Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;
    final jour = (fin - debut) / (24 * 60) * 2 * math.pi;
    // Le Décideur d'abord (tout l'anneau), l'Exécutant par-dessus.
    canvas.drawCircle(c, rayon, trait(AppTheme.ambre));
    canvas.drawArc(rect, _angle(debut), jour, false, trait(AppTheme.bleuVert));

    // Les heures : un trait par heure, des repères à 0, 6, 12 et 18 h.
    final graduation = Paint()
      ..color = doux.withValues(alpha: 0.5)
      ..strokeCap = StrokeCap.round;
    for (var h = 0; h < 24; h++) {
      final a = _angle(h * 60);
      final dir = Offset(math.cos(a), math.sin(a));
      final dedans = rayon - epaisseur / 2 - 6;
      graduation.strokeWidth = h % 6 == 0 ? 2 : 1;
      canvas.drawLine(
        c + dir * dedans,
        c + dir * (dedans - (h % 6 == 0 ? 8 : 4)),
        graduation,
      );
      if (h % 6 == 0) {
        final texte = TextPainter(
          text: TextSpan(
            text: '$h h',
            style: TextStyle(
              fontFamily: AppTheme.policeTexte,
              color: doux,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final p = c + dir * (dedans - 22);
        texte.paint(canvas, p - Offset(texte.width / 2, texte.height / 2));
      }
    }

    // Les deux poignées, avec leur heure.
    for (final m in [debut, fin]) {
      final a = _angle(m);
      final p = c + Offset(math.cos(a), math.sin(a)) * rayon;
      canvas.drawCircle(
        p,
        poignee,
        Paint()..color = fond.withValues(alpha: 0.6),
      );
      canvas.drawCircle(p, poignee - 1, Paint()..color = blanc);
      final texte = TextPainter(
        text: TextSpan(
          text: heureFr(m % (24 * 60)).replaceAll(' ', ''),
          style: TextStyle(
            fontFamily: AppTheme.policeTexte,
            color: fond,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: poignee * 2);
      texte.paint(canvas, p - Offset(texte.width / 2, texte.height / 2));
    }
  }

  @override
  bool shouldRepaint(_Anneau ancien) =>
      ancien.debut != debut ||
      ancien.fin != fin ||
      ancien.rayon != rayon ||
      ancien.blanc != blanc;
}

/// L'anneau et, dessous, les deux toi avec leurs heures (intro, page 2,
/// et Réglages). Toucher une ligne ouvre le cadran d'heure, pour régler à
/// la minute.
class RepartitionRoles extends StatelessWidget {
  final ({int debut, int fin}) journee;
  final ValueChanged<({int debut, int fin})> onChange;

  const RepartitionRoles({
    super.key,
    required this.journee,
    required this.onChange,
  });

  /// Cadran d'heure (sans clavier, 24 h) ; nul si annulé.
  static Future<int?> _heure(
    BuildContext context,
    int depart,
    String aide,
  ) async {
    final choisie = await showTimePicker(
      context: context,
      helpText: aide,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: TimeOfDay(hour: (depart ~/ 60) % 24, minute: depart % 60),
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    return choisie == null ? null : choisie.hour * 60 + choisie.minute;
  }

  /// [decideur] : on règle la plage du Décideur (sa fin est le début de la
  /// journée, et l'inverse).
  Future<void> _regle(BuildContext context, {required bool decideur}) async {
    final premier = await _heure(
      context,
      decideur ? journee.fin : journee.debut,
      decideur ? 'Tu décides à partir de' : 'Tu commences à',
    );
    if (premier == null || !context.mounted) return;
    final second = await _heure(
      context,
      decideur ? journee.debut : journee.fin,
      decideur ? 'Jusqu\'à' : 'Tu finis à',
    );
    if (second == null || !context.mounted) return;
    var debut = decideur ? second : premier;
    var fin = decideur ? premier : second;
    if (fin == 0) fin = 24 * 60;
    if (fin - debut < AnneauRoles.minimum ||
        24 * 60 - (fin - debut) < AnneauRoles.minimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La journée commence et finit le même jour, et chaque toi '
            'garde au moins une heure.',
          ),
        ),
      );
      return;
    }
    onChange((debut: debut, fin: fin));
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    String hhmm(int m) =>
        '${((m ~/ 60) % 24).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
    Widget ligne({
      required Key cle,
      required Color couleur,
      required String titre,
      required String sousTitre,
      required String heures,
      required VoidCallback onTap,
    }) => InkWell(
      key: cle,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.puce)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    sousTitre,
                    style: TextStyle(color: t.doux, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              heures,
              style: TextStyle(
                fontFamily: AppTheme.policeMono,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: couleur,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnneauRoles(
          debut: journee.debut,
          fin: journee.fin,
          onChange: (debut, fin) => onChange((debut: debut, fin: fin)),
        ),
        const SizedBox(height: 20),
        ligne(
          cle: const ValueKey('roles-decideur'),
          couleur: AppTheme.ambre,
          titre: 'Toi qui décides',
          sousTitre: 'le soir et la nuit, tu prépares demain',
          heures: '${hhmm(journee.fin)} – ${hhmm(journee.debut)}',
          onTap: () => _regle(context, decideur: true),
        ),
        ligne(
          cle: const ValueKey('roles-executant'),
          couleur: AppTheme.bleuVert,
          titre: 'Toi qui exécutes',
          sousTitre: 'le jour, tu fais',
          heures: '${hhmm(journee.debut)} – ${hhmm(journee.fin)}',
          onTap: () => _regle(context, decideur: false),
        ),
      ],
    );
  }
}
