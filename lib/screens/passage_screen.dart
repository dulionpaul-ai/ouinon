import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/retro.dart';

/// Le passage d'un toi à l'autre, en ascenseur (idée de Paul du
/// 26/10/2026) : les portes se ferment sur l'un, l'étage change (SOIR ↓
/// JOUR), elles s'ouvrent sur l'autre. Un peu plus de 2 secondes, puis
/// l'écran se ferme tout seul ; un appui le passe.
///
/// Vers le jour : du soir ambre à l'écran rétro, dont les lignes
/// s'écrivent une à une. Vers le soir : l'inverse.
class PassageScreen extends StatefulWidget {
  final bool versJour;

  /// Côté soir : un titre (« Transmis. ») et une ligne dessous.
  final String titreSoir;
  final String? sousTitreSoir;

  /// Côté jour : les lignes du terminal.
  final List<String> lignesJour;

  const PassageScreen({
    super.key,
    required this.versJour,
    required this.titreSoir,
    this.sousTitreSoir,
    required this.lignesJour,
  });

  /// Le passage, sans glissement d'écran (il fait son propre effet).
  static Route<void> route(PassageScreen ecran) => PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => ecran,
    transitionsBuilder: (_, anim, _, enfant) =>
        FadeTransition(opacity: anim, child: enfant),
  );

  @override
  State<PassageScreen> createState() => _PassageScreenState();
}

class _PassageScreenState extends State<PassageScreen>
    with SingleTickerProviderStateMixin {
  static const _duree = Duration(milliseconds: 2400);

  late final _anim = AnimationController(vsync: this, duration: _duree);
  Timer? _fin;
  bool _ferme = false;
  bool _clac = false;
  bool _ding = false;

  @override
  void initState() {
    super.initState();
    _anim
      ..addListener(_vibre)
      ..addStatusListener((etat) {
        if (etat == AnimationStatus.completed) {
          _fin = Timer(const Duration(milliseconds: 700), _quitte);
        }
      })
      ..forward();
  }

  /// Un petit choc quand les portes se ferment, un autre à l'ouverture.
  void _vibre() {
    final v = _anim.value;
    if (!_clac && v >= 0.3) {
      _clac = true;
      HapticFeedback.lightImpact();
    }
    if (!_ding && v >= 0.58) {
      _ding = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _quitte() {
    if (_ferme || !mounted) return;
    _ferme = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _fin?.cancel();
    _anim.dispose();
    super.dispose();
  }

  /// Part de `v` entre `a` et `b`, de 0 à 1.
  static double _entre(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Teintes.retro.fond,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _quitte,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final v = _anim.value;
            // Portes : fermées de 0,12 à 0,3 ; rouvertes de 0,58 à 0,8.
            final fermeture =
                Curves.easeInOut.transform(_entre(v, 0.12, 0.3)) -
                Curves.easeInOut.transform(_entre(v, 0.58, 0.8));
            final arrivee = v >= 0.44;
            final soirVisible = widget.versJour ? !arrivee : arrivee;
            final ecriture = _entre(v, 0.72, 1);
            return LayoutBuilder(
              builder: (context, taille) {
                final largeur = taille.maxWidth / 2;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (soirVisible) _soir() else _jour(ecriture),
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
                      child: Center(
                        child: _Etage(
                          versJour: widget.versJour,
                          avancee: _entre(v, 0.32, 0.56),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _soir() => ColoredBox(
    color: Teintes.soir.fond,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.titreSoir,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.policeTitre,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.ambre,
              ),
            ),
            if (widget.sousTitreSoir != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.sousTitreSoir!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.policeTexte,
                  fontSize: 16,
                  height: 1.4,
                  color: Teintes.soir.doux,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  /// Le terminal : les lignes s'écrivent une à une (`ecriture` de 0 à 1).
  Widget _jour(double ecriture) {
    final lignes = widget.lignesJour;
    final total = lignes.fold(0, (s, l) => s + l.length);
    var reste = widget.versJour ? (ecriture * total).round() : total;
    return FondRetro(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 140, 30, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, l) in lignes.indexed)
              if (reste > 0 || i == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(
                      text: () {
                        final n = reste.clamp(0, l.length);
                        reste -= l.length;
                        return l.substring(0, n);
                      }(),
                      children: [
                        if (reste <= 0)
                          const WidgetSpan(
                            child: Curseur(
                              hauteur: 24,
                              couleur: AppTheme.bleuVert,
                            ),
                          ),
                      ],
                    ),
                    style: styleRetro(28),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Un battant de porte d'ascenseur, en métal brossé.
class _Porte extends StatelessWidget {
  final bool gauche;

  const _Porte({required this.gauche});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: gauche ? Alignment.centerLeft : Alignment.centerRight,
        end: gauche ? Alignment.centerRight : Alignment.centerLeft,
        colors: const [Color(0xFF262B2F), Color(0xFF3C4348)],
      ),
      border: Border(
        right: gauche
            ? const BorderSide(color: Color(0xFF14181A), width: 1.5)
            : BorderSide.none,
        left: gauche
            ? BorderSide.none
            : const BorderSide(color: Color(0xFF14181A), width: 1.5),
      ),
    ),
  );
}

/// L'indicateur d'étage : SOIR ↓ JOUR (ou ↑ vers le soir).
class _Etage extends StatelessWidget {
  final bool versJour;

  /// De 0 (départ) à 1 (arrivée).
  final double avancee;

  const _Etage({required this.versJour, required this.avancee});

  @override
  Widget build(BuildContext context) {
    final soirAllume = versJour ? avancee < 0.5 : avancee >= 0.5;
    TextStyle style(Color c, bool allume) =>
        styleRetro(24, couleur: allume ? c : c.withValues(alpha: 0.25));
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: ShapeDecoration(
        color: Colors.black,
        shape: StadiumBorder(side: BorderSide(color: Teintes.retro.puce)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SOIR', style: style(AppTheme.ambre, soirAllume)),
          const SizedBox(width: 12),
          Opacity(
            opacity: avancee > 0 && avancee < 1 ? 1 : 0.4,
            child: Icon(
              versJour
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text('JOUR', style: style(AppTheme.bleuVert, !soirAllume)),
        ],
      ),
    );
  }
}
