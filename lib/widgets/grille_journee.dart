import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/a_faire.dart';
import '../models/creneau.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';

/// Hauteur d'une heure dans la journée, par défaut.
const hauteurHeure = 52.0;

/// Largeur de la colonne des heures, à gauche.
const _largeurHeures = 46.0;

/// La journée heure par heure, comme la colonne des heures du tableau
/// blanc de Paul : chaque heure prend toujours la même place, les choses
/// prévues sont des blocs à leur vraie taille, les créneaux fixes sont
/// grisés.
///
/// On y dépose une chose du bac (glisser-déposer) ou on y déplace un bloc
/// (appui long, puis glisser) ; on change la durée en tirant le bas d'un
/// bloc. Tout tombe au quart d'heure.
class GrilleJournee extends StatefulWidget {
  final List<Tache> taches;
  final List<Creneau> creneaux;

  /// Première et dernière heure montrées (8 h et 23 h sur le tableau).
  final int heureDebut;
  final int heureFin;

  /// Minute actuelle si c'est aujourd'hui (trait « maintenant »).
  final int? maintenant;

  /// Hauteur d'une heure (plus petite pour voir toute la journée).
  final double heure;

  final void Function(AFaire a, int debut) onPoseAFaire;
  final void Function(Tache t, int debut) onDeplace;
  final void Function(Tache t, int duree) onDuree;
  final void Function(Tache t) onTapTache;
  final void Function(Creneau c) onTapCreneau;
  final void Function(int debut) onTapVide;

  /// Pendant un glisser (pour faire défiler la page près des bords).
  final void Function(Offset global)? onGlisse;
  final VoidCallback? onFinGlisse;

  const GrilleJournee({
    super.key,
    required this.taches,
    required this.creneaux,
    this.heureDebut = 8,
    this.heureFin = 23,
    this.maintenant,
    this.heure = hauteurHeure,
    required this.onPoseAFaire,
    required this.onDeplace,
    required this.onDuree,
    required this.onTapTache,
    required this.onTapCreneau,
    required this.onTapVide,
    this.onGlisse,
    this.onFinGlisse,
  });

  @override
  State<GrilleJournee> createState() => _GrilleJourneeState();
}

class _GrilleJourneeState extends State<GrilleJournee> {
  final _cle = GlobalKey();

  /// Aperçu de l'endroit où tombera ce qu'on glisse.
  ({int debut, int duree, String texte})? _apercu;

  /// Durée en train d'être tirée : id → minutes.
  final _durees = <int, int>{};

  double _y(int minute) =>
      (minute - widget.heureDebut * 60) / 60 * widget.heure;

  int _arrondi(double y) =>
      widget.heureDebut * 60 + ((y / widget.heure * 60) / 15).round() * 15;

  /// Début d'une chose déposée, d'après le haut de ce qu'on glisse.
  int _debutDepuis(Offset global, int duree) {
    final boite = _cle.currentContext!.findRenderObject() as RenderBox;
    final debut = _arrondi(boite.globalToLocal(global).dy);
    return debut.clamp(
      widget.heureDebut * 60,
      widget.heureFin * 60 + 60 - duree,
    );
  }

  ({int duree, String texte})? _infos(Object? data) => switch (data) {
    final AFaire a => (duree: a.duree, texte: a.texte),
    final Tache t => (duree: t.duree, texte: t.texte),
    _ => null,
  };

  /// Colonnes des blocs qui se chevauchent : (colonne, nombre de colonnes).
  Map<Tache, (int, int)> _colonnes(List<Tache> taches) {
    final tries = [...taches]..sort((a, b) => a.debut.compareTo(b.debut));
    final resultat = <Tache, (int, int)>{};
    var groupe = <Tache>[];
    final finsColonnes = <int>[];
    var finGroupe = -1;
    void ferme() {
      for (final t in groupe) {
        resultat[t] = (resultat[t]!.$1, finsColonnes.length);
      }
      groupe = [];
      finsColonnes.clear();
    }

    for (final t in tries) {
      if (t.debut >= finGroupe && groupe.isNotEmpty) ferme();
      var col = finsColonnes.indexWhere((fin) => fin <= t.debut);
      if (col < 0) {
        col = finsColonnes.length;
        finsColonnes.add(t.fin);
      } else {
        finsColonnes[col] = t.fin;
      }
      resultat[t] = (col, 0);
      groupe.add(t);
      if (t.fin > finGroupe) finGroupe = t.fin;
    }
    if (groupe.isNotEmpty) ferme();
    return resultat;
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final heures = widget.heureFin - widget.heureDebut + 1;
    final hauteur = heures * widget.heure;
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) => d.data is AFaire || d.data is Tache,
      onMove: (d) {
        final infos = _infos(d.data);
        if (infos == null) return;
        final debut = _debutDepuis(d.offset, infos.duree);
        if (_apercu?.debut != debut) {
          setState(
            () => _apercu = (
              debut: debut,
              duree: infos.duree,
              texte: infos.texte,
            ),
          );
        }
      },
      onLeave: (_) => setState(() => _apercu = null),
      onAcceptWithDetails: (d) {
        setState(() => _apercu = null);
        HapticFeedback.mediumImpact();
        switch (d.data) {
          case final AFaire a:
            widget.onPoseAFaire(a, _debutDepuis(d.offset, a.duree));
          case final Tache tache:
            widget.onDeplace(tache, _debutDepuis(d.offset, tache.duree));
        }
      },
      builder: (context, _, _) => LayoutBuilder(
        builder: (context, contraintes) {
          final largeur = contraintes.maxWidth - _largeurHeures - 4;
          final colonnes = _colonnes(widget.taches);
          return SizedBox(
            key: _cle,
            height: hauteur,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Toucher une heure vide : un impératif à cette heure.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final minute =
                          widget.heureDebut * 60 +
                          (d.localPosition.dy / widget.heure * 2).floor() * 30;
                      widget.onTapVide(minute);
                    },
                  ),
                ),
                for (var i = 0; i < heures; i++)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: i * widget.heure,
                    child: IgnorePointer(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _largeurHeures - 8,
                            child: Transform.translate(
                              offset: const Offset(0, -8),
                              child: Text(
                                heureFr((widget.heureDebut + i) * 60),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                style: TextStyle(
                                  color: t.doux,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Container(height: 1, color: t.trait)),
                        ],
                      ),
                    ),
                  ),
                for (final c in widget.creneaux)
                  Positioned(
                    left: _largeurHeures,
                    width: largeur,
                    top: _y(c.debut),
                    height: (c.duree / 60 * widget.heure).clamp(
                      22.0,
                      double.infinity,
                    ),
                    child: _BlocCreneau(
                      creneau: c,
                      onTap: () => widget.onTapCreneau(c),
                    ),
                  ),
                for (final tache in widget.taches)
                  _positionne(tache, colonnes[tache]!, largeur),
                if (_apercu case final a?)
                  Positioned(
                    left: _largeurHeures,
                    width: largeur,
                    top: _y(a.debut),
                    height: a.duree / 60 * widget.heure,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.10),
                          border: Border.all(color: t.accent, width: 2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: ShapeDecoration(
                            color: t.texte,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            '${heureFr(a.debut)} – ${heureFr(a.debut + a.duree)}',
                            style: TextStyle(
                              color: t.fond,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.maintenant case final m?
                    when m >= widget.heureDebut * 60 &&
                        m <= (widget.heureFin + 1) * 60)
                  Positioned(
                    left: _largeurHeures - 6,
                    right: 0,
                    top: _y(m) - 1,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: t.moinsBonne,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(height: 2, color: t.moinsBonne),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _positionne(Tache tache, (int, int) colonne, double largeur) {
    final duree = _durees[tache.id] ?? tache.duree;
    final (col, nb) = colonne;
    final l = largeur / nb;
    final hauteur = (duree / 60 * widget.heure).clamp(26.0, double.infinity);
    final bloc = _BlocTacheGrille(tache: tache, duree: duree, hauteur: hauteur);
    return Positioned(
      left: _largeurHeures + col * l,
      width: l - (nb > 1 ? 3 : 0),
      top: _y(tache.debut),
      height: hauteur,
      child: LongPressDraggable<Object>(
        data: tache,
        hapticFeedbackOnStart: true,
        onDragUpdate: (d) => widget.onGlisse?.call(d.globalPosition),
        onDragEnd: (_) => widget.onFinGlisse?.call(),
        onDraggableCanceled: (_, _) => widget.onFinGlisse?.call(),
        feedback: Material(
          type: MaterialType.transparency,
          child: SizedBox(width: l, height: hauteur, child: bloc),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: bloc),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => widget.onTapTache(tache),
                child: bloc,
              ),
            ),
            // Tirer le bas : changer la durée.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 18,
              child: GestureDetector(
                key: ValueKey('duree-bloc-${tache.id}'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) => setState(() {
                  final actuelle =
                      (_durees[tache.id] ?? tache.duree) +
                      d.delta.dy / widget.heure * 60;
                  _durees[tache.id!] = actuelle.round().clamp(15, 12 * 60);
                }),
                onVerticalDragEnd: (_) {
                  final brute = _durees.remove(tache.id);
                  if (brute == null) return;
                  final arrondie = ((brute / 15).round() * 15).clamp(
                    15,
                    12 * 60,
                  );
                  setState(() {});
                  if (arrondie != tache.duree) widget.onDuree(tache, arrondie);
                },
                child: Center(
                  child: Container(
                    // Trait caché sur les blocs courts (il cacherait le
                    // texte) ; la poignée reste.
                    width: hauteur < 40 ? 0 : 34,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un bloc de la journée : citron (blanc pour un rendez-vous), texte,
/// horaire ; coché si fait, pâli si pas fait.
class _BlocTacheGrille extends StatelessWidget {
  final Tache tache;
  final int duree;
  final double hauteur;

  const _BlocTacheGrille({
    required this.tache,
    required this.duree,
    required this.hauteur,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    // Une seule couleur pour la to-do (citron), blanc pour un rendez-vous.
    final fond = tache.imperatif ? t.texte : t.accent;
    final texte = t.fond;
    final plage =
        '${heureFr(tache.debut)} – ${heureFr((tache.debut + duree) % (24 * 60))}';
    final serre = hauteur < 44;
    return Opacity(
      opacity: tache.etat == Tache.pasFait ? 0.4 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: EdgeInsets.fromLTRB(12, serre ? 2 : 7, 10, 2),
        child: Row(
          crossAxisAlignment: serre
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (tache.etat == Tache.fait) ...[
              Icon(Icons.check_circle_rounded, size: 16, color: texte),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                tache.texte,
                maxLines: serre ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: texte,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  decoration: tache.etat == Tache.pasFait
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              plage,
              maxLines: 1,
              style: TextStyle(
                color: texte.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un créneau fixe : hachuré, gris, sans couleur de case.
class _BlocCreneau extends StatelessWidget {
  final Creneau creneau;
  final VoidCallback onTap;

  const _BlocCreneau({required this.creneau, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _Hachures(t.trait),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.barre),
          ),
          padding: const EdgeInsets.fromLTRB(12, 7, 10, 4),
          alignment: Alignment.topLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  creneau.texte,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.texteBarre,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${heureFr(creneau.debut)} – ${heureFr(creneau.fin % (24 * 60))}',
                style: TextStyle(
                  color: t.doux,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
      const Radius.circular(14),
    );
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF16161A));
    final trait = Paint()
      ..color = couleur
      ..strokeWidth = 6;
    for (var x = -size.height; x < size.width; x += 16) {
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
