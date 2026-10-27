import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Le haut d'une étape du soir : retour à gauche, « ÉTAPE 1 SUR 2 » à
/// droite, en police de terminal.
class BarreEtape extends StatelessWidget {
  final String texte;

  const BarreEtape(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.doux),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              texte.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTheme.policeMono,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: t.doux,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grand titre d'écran, en Unbounded, réduit plutôt que coupé.
class TitreEcran extends StatelessWidget {
  final String texte;
  final double taille;

  const TitreEcran(this.texte, {super.key, this.taille = 28});

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      texte,
      maxLines: 1,
      style: TextStyle(
        fontFamily: AppTheme.policeTitre,
        fontSize: taille,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        height: 1.1,
        color: Teintes.de(context).texte,
      ),
    ),
  );
}

/// Le gros bouton du bas (« Préparer demain », « Placer sur demain »,
/// « C'est prêt ») : plein, l'accent, une flèche à droite. Avec [lueur],
/// il brille doucement quelques fois pour attirer l'œil.
class BoutonSuite extends StatefulWidget {
  final String texte;
  final IconData icone;
  final VoidCallback? onPressed;
  final bool lueur;

  const BoutonSuite({
    super.key,
    required this.texte,
    required this.onPressed,
    this.icone = Icons.arrow_forward_rounded,
    this.lueur = false,
  });

  @override
  State<BoutonSuite> createState() => _BoutonSuiteState();
}

class _BoutonSuiteState extends State<BoutonSuite>
    with SingleTickerProviderStateMixin {
  // Un temps d'attente, trois respirations, puis plus rien : une
  // animation sans fin fatiguerait.
  static const _attente = 0.9, _souffle = 2.6, _souffles = 3;
  late final _anim = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: ((_attente + _souffle * _souffles) * 1000).round(),
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.lueur) _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double get _eclat {
    final s = _anim.value * (_attente + _souffle * _souffles) - _attente;
    if (s <= 0 || s >= _souffle * _souffles) return 0;
    return 0.5 - 0.5 * math.cos(2 * math.pi * s / _souffle);
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, enfant) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: t.accent.withValues(alpha: 0.45 * _eclat),
              blurRadius: 30,
            ),
          ],
        ),
        child: enfant,
      ),
      child: SizedBox(
        height: 58,
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.surAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.texte,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.policeTitre,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(widget.icone, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le logo : un rond coupé en deux, ambre à gauche, bleu-vert à droite.
class LogoRond extends StatelessWidget {
  final double taille;

  /// Écart entre les deux moitiés (0 : collées).
  final double ecart;

  const LogoRond({super.key, this.taille = 18, this.ecart = 2});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Moitie(taille: taille, gauche: true),
      SizedBox(width: ecart),
      _Moitie(taille: taille, gauche: false),
    ],
  );
}

class _Moitie extends StatelessWidget {
  final double taille;
  final bool gauche;

  const _Moitie({required this.taille, required this.gauche});

  @override
  Widget build(BuildContext context) => Container(
    width: taille / 2,
    height: taille,
    decoration: BoxDecoration(
      color: gauche ? AppTheme.ambre : AppTheme.bleuVert,
      borderRadius: gauche
          ? BorderRadius.horizontal(left: Radius.circular(taille / 2))
          : BorderRadius.horizontal(right: Radius.circular(taille / 2)),
    ),
  );
}
