import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/creneau.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/planning.dart';

/// La journée de l'Exécutant en calendrier (demande de Paul du
/// 26/10/2026) : les heures régulières sur le côté, les choses prévues en
/// cases transparentes à leur vraie taille (plus fortes pour celle en
/// cours, corail pour « pas fait », barrées une fois faites), les
/// créneaux fixes hachurés, un trait à l'heure qu'il est. En lecture :
/// toucher une chose l'ouvre.
class CalendrierJour extends StatelessWidget {
  final List<Tache> taches;
  final List<Creneau> creneaux;

  /// Minute actuelle si c'est aujourd'hui.
  final int? maintenant;
  final void Function(Tache) onTap;

  /// Hauteur d'une heure.
  final double heure;

  const CalendrierJour({
    super.key,
    required this.taches,
    required this.creneaux,
    required this.onTap,
    this.maintenant,
    this.heure = 52,
  });

  static const _colonne = 44.0;

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final debut = math.min(
      8,
      taches.fold(24, (m, x) => math.min(m, x.debut ~/ 60)),
    );
    final fin = math
        .max(23, taches.fold(0, (m, x) => math.max(m, (x.fin + 59) ~/ 60)))
        .clamp(debut + 1, 24);
    const haut = 8.0;
    double y(int minute) => haut + (minute - debut * 60) / 60 * heure;
    bool dansCreneau(Tache x) =>
        creneaux.any((c) => x.debut < c.fin && x.fin > c.debut);
    return SizedBox(
      height: y(fin * 60) + 4,
      child: Stack(
        children: [
          for (var h = debut; h <= fin; h++)
            Positioned(
              top: y(h * 60),
              left: 0,
              right: 0,
              child: Row(
                children: [
                  SizedBox(
                    width: _colonne,
                    child: Transform.translate(
                      offset: const Offset(0, -8),
                      child: Text(
                        '$h h',
                        style: TextStyle(
                          color: t.doux,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: t.puce)),
                ],
              ),
            ),
          for (final c in creneaux)
            Positioned(
              top: y(math.max(c.debut, debut * 60)),
              height:
                  y(math.min(c.fin, fin * 60)) -
                  y(math.max(c.debut, debut * 60)),
              left: _colonne,
              right: 0,
              child: _Creneau(creneau: c),
            ),
          for (final x in taches)
            Positioned(
              top: y(x.debut) + 1,
              height: math.max(26, x.duree / 60 * heure - 2),
              left: _colonne,
              right: dansCreneau(x) ? 88 : 0,
              child: _Bloc(
                key: ValueKey('calendrier-${x.id}'),
                tache: x,
                enCours:
                    maintenant != null &&
                    x.etat == null &&
                    x.debut <= maintenant! &&
                    maintenant! < x.fin,
                onTap: () => onTap(x),
              ),
            ),
          if (maintenant case final m? when m >= debut * 60 && m <= fin * 60)
            Positioned(
              top: y(m) - 4,
              left: _colonne - 6,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: Container(height: 2, color: t.accent)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une chose prévue, en case transparente.
class _Bloc extends StatelessWidget {
  final Tache tache;
  final bool enCours;
  final VoidCallback onTap;

  const _Bloc({
    super.key,
    required this.tache,
    required this.enCours,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final x = tache;
    final fait = x.etat == Tache.fait;
    final pasFait = x.etat == Tache.pasFait;
    final couleur = pasFait ? t.moinsBonne : t.accent;
    return Opacity(
      opacity: fait ? 0.55 : 1,
      child: Material(
        color: couleur.withValues(alpha: enCours ? 0.30 : 0.14),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: couleur.withValues(alpha: enCours ? 1 : 0.7),
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    x.texte,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.texte,
                      decoration: fait ? TextDecoration.lineThrough : null,
                      decorationColor: t.doux,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  dureeFr(x.duree),
                  style: TextStyle(color: t.doux, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un créneau fixe : hachuré, son nom et ses heures en haut à droite.
class _Creneau extends StatelessWidget {
  final Creneau creneau;

  const _Creneau({required this.creneau});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final c = creneau;
    return CustomPaint(
      painter: _Hachures(t.doux),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Align(
          alignment: Alignment.topRight,
          child: Text(
            '${c.texte} · ${heureFr(c.debut)} – ${heureFr(c.fin % (24 * 60))}',
            textAlign: TextAlign.end,
            style: TextStyle(color: t.doux, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _Hachures extends CustomPainter {
  final Color couleur;

  const _Hachures(this.couleur);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRRect(rect, Paint()..color = couleur.withValues(alpha: 0.04));
    final trait = Paint()
      ..color = couleur.withValues(alpha: 0.07)
      ..strokeWidth = 5;
    for (var x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        trait,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Hachures ancien) => ancien.couleur != couleur;
}
