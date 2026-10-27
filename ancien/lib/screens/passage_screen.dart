import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/arrivee.dart';

/// Le passage d'un toi à l'autre, en ascenseur (idée de Paul du
/// 26/10/2026, revue le même jour) : les portes se ferment sur l'écran du
/// moment, l'afficheur du haut montre l'étage de départ puis défile vers
/// l'autre (DÉCIDEUR ou EXÉCUTANT) dans le sens de la flèche, et les
/// portes s'ouvrent sur le nouvel écran. Environ 3 secondes.
///
/// L'ascenseur se pose par-dessus l'écran : portes fermées, [auMilieu]
/// change ce qu'il y a derrière (onglet, toi), puis [arriveeAscenseur] prévient
/// les écrans, qui montrent leur « Bonjour » d'abord et le reste ensuite.
class PassageScreen extends StatefulWidget {
  /// Vers le Décideur (▲) ou vers l'Exécutant (▼).
  final bool versLeSoir;

  /// Portes fermées : ce qui change derrière.
  final VoidCallback? auMilieu;

  /// Portes fermées : retire aussi l'écran d'où l'on part (compte rendu).
  final bool retireDessous;

  /// Un écran sur lequel les portes s'ouvrent (« Modifier ma journée »
  /// chez l'Exécutant ouvre Préparer chez le Décideur). L'ascenseur reste
  /// alors à sa place sous cet écran : en revenir ramène d'où l'on vient.
  final Widget? destination;

  const PassageScreen({
    super.key,
    required this.versLeSoir,
    this.auMilieu,
    this.retireDessous = false,
    this.destination,
  });

  /// Durée totale du passage.
  static const duree = Duration(milliseconds: 3200);

  /// Joue l'ascenseur par-dessus l'écran actuel.
  static Future<void> joue(
    BuildContext context, {
    required bool versLeSoir,
    VoidCallback? auMilieu,
    bool retireDessous = false,
    Widget? destination,
  }) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => PassageScreen(
        versLeSoir: versLeSoir,
        auMilieu: auMilieu,
        retireDessous: retireDessous,
        destination: destination,
      ),
    ),
  );

  @override
  State<PassageScreen> createState() => _PassageScreenState();
}

class _PassageScreenState extends State<PassageScreen>
    with SingleTickerProviderStateMixin {
  // Moments, en part de la durée totale.
  static const _fermees = 0.22;
  static const _defile = (0.4, 0.68);
  static const _milieu = 0.78;
  static const _ouvertes = 0.98;

  late final _anim = AnimationController(
    vsync: this,
    duration: PassageScreen.duree,
  );
  bool _clac = false;
  bool _change = false;
  bool _fini = false;

  @override
  void initState() {
    super.initState();
    _anim
      ..addListener(_avance)
      ..addStatusListener((etat) {
        if (etat == AnimationStatus.completed && widget.destination == null) {
          _quitte();
        }
      })
      ..forward();
  }

  /// Un petit choc quand les portes se ferment ; portes fermées, on
  /// change ce qu'il y a derrière.
  void _avance() {
    final v = _anim.value;
    if (!_clac && v >= _fermees) {
      _clac = true;
      HapticFeedback.lightImpact();
    }
    if (!_change && v >= _milieu) {
      if (widget.destination != null) setState(() {});
      _change = true;
      HapticFeedback.mediumImpact();
      if (widget.retireDessous) {
        final route = ModalRoute.of(context);
        if (route != null) Navigator.of(context).removeRouteBelow(route);
      }
      widget.auMilieu?.call();
      final a = arriveeAscenseur.value;
      arriveeAscenseur.value = (
        numero: a.numero + 1,
        versLeSoir: widget.versLeSoir,
      );
    }
  }

  void _quitte() {
    if (_fini || !mounted) return;
    _fini = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Part de `v` entre `a` et `b`, de 0 à 1.
  static double _entre(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    return AnimatedBuilder(
      animation: _anim,
      // Construit dès le début (ses données se chargent pendant le
      // trajet), montré portes fermées.
      child: destination == null
          ? null
          : Offstage(offstage: !_change, child: destination),
      builder: (context, dessous) {
        final v = _anim.value;
        final fermeture =
            Curves.easeInOut.transform(_entre(v, 0, _fermees)) -
            Curves.easeInOut.transform(_entre(v, 0.8, _ouvertes));
        final afficheur =
            _entre(v, _fermees - 0.04, _fermees + 0.03) - _entre(v, 0.8, 0.86);
        return LayoutBuilder(
          builder: (context, taille) {
            final largeur = taille.maxWidth / 2;
            return Material(
              type: MaterialType.transparency,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Rien ne passe à travers pendant le trajet.
                  const ModalBarrier(dismissible: false),
                  ?dessous,
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: -largeur * (1 - fermeture),
                    width: largeur,
                    child: const _Porte(gauche: true),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: -largeur * (1 - fermeture),
                    width: largeur,
                    child: const _Porte(gauche: false),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 24,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: afficheur.clamp(0.0, 1.0),
                          child: Afficheur(
                            versLeSoir: widget.versLeSoir,
                            avancee: Curves.easeInOutCubic.transform(
                              _entre(v, _defile.$1, _defile.$2),
                            ),
                            bouge: v > _fermees + 0.04 && v < _defile.$2 + 0.02,
                            clignote: (v * 16).floor().isEven,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Un battant de porte d'ascenseur, en métal sombre.
class _Porte extends StatelessWidget {
  final bool gauche;

  const _Porte({required this.gauche});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF16161B), Color(0xFF1D1D23), Color(0xFF16161B)],
      ),
      border: Border(
        right: gauche
            ? const BorderSide(color: Color(0xFF2C2C33))
            : BorderSide.none,
        left: gauche
            ? BorderSide.none
            : const BorderSide(color: Color(0xFF2C2C33)),
      ),
    ),
  );
}

/// L'afficheur d'étage : la flèche, et le nom de l'étage qui défile (le
/// nouveau arrive du côté de la flèche : d'en haut quand on monte vers le
/// Décideur, d'en bas quand on descend vers l'Exécutant).
class Afficheur extends StatelessWidget {
  final bool versLeSoir;

  /// De 0 (étage de départ) à 1 (étage d'arrivée).
  final double avancee;

  /// En mouvement : la flèche clignote.
  final bool bouge;
  final bool clignote;

  const Afficheur({
    super.key,
    required this.versLeSoir,
    required this.avancee,
    this.bouge = false,
    this.clignote = true,
  });

  static const _hauteur = 24.0;

  static TextStyle _style(Color c) => TextStyle(
    fontFamily: AppTheme.policeMono,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 3,
    height: 1,
    color: c,
    shadows: [Shadow(color: c.withValues(alpha: 0.6), blurRadius: 10)],
  );

  @override
  Widget build(BuildContext context) {
    final soir = Text('DÉCIDEUR', style: _style(AppTheme.ambre));
    final jour = Text('EXÉCUTANT', style: _style(AppTheme.bleuVert));
    final (depart, arrivee) = versLeSoir ? (jour, soir) : (soir, jour);
    // Sens du défilement : vers le bas en montant, vers le haut en
    // descendant.
    final sens = versLeSoir ? 1.0 : -1.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF050506),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C33)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            versLeSoir
                ? Icons.arrow_drop_up_rounded
                : Icons.arrow_drop_down_rounded,
            size: 26,
            color: bouge && clignote
                ? Teintes.sombre.texte
                : const Color(0xFF55555D),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 128,
            height: _hauteur,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, sens * _hauteur * avancee),
                    child: depart,
                  ),
                  Transform.translate(
                    offset: Offset(0, -sens * _hauteur * (1 - avancee)),
                    child: arrivee,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
