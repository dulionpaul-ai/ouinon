import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Les petites pièces du style « espace » (maquette validée par Paul le
/// 28/10/2026) : une animation à chaque geste, pour que l'appli soit
/// vivante.

/// Ce qui apparaît (une chose ajoutée, une question créée) : dessiné de
/// gauche à droite, un trait de lumière à l'accent passe devant.
class Apparition extends StatefulWidget {
  final Widget child;

  const Apparition({super.key, required this.child});

  @override
  State<Apparition> createState() => _ApparitionState();
}

class _ApparitionState extends State<Apparition>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Teintes.de(context).accent;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, enfant) {
        final v = Curves.easeOutCubic.transform(_anim.value);
        if (v >= 1) return enfant!;
        return Stack(
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: Opacity(
                  opacity: (v * 1.6).clamp(0.0, 1.0),
                  child: enfant,
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 2,
                      color: accent.withValues(alpha: 1 - v),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Un trait qui balaie la page de haut en bas quand elle arrive.
class Balayage extends StatefulWidget {
  const Balayage({super.key});

  @override
  State<Balayage> createState() => _BalayageState();
}

class _BalayageState extends State<Balayage>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Teintes.de(context).accent;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final v = _anim.value;
          if (v >= 1) return const SizedBox.shrink();
          return LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: c.maxHeight * Curves.easeOut.transform(v),
                  child: Container(
                    height: 1,
                    color: accent.withValues(alpha: 0.9 * (1 - v)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// L'en-tête d'une page : la date (et un résumé) en petites capitales,
/// le grand titre, puis des boutons ronds à droite.
class EnTete extends StatelessWidget {
  final String date;
  final String titre;
  final List<Widget> actions;

  const EnTete({
    super.key,
    required this.date,
    required this.titre,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTheme.policeMono,
                  fontSize: 11,
                  letterSpacing: 1.8,
                  color: t.doux,
                ),
              ),
              const SizedBox(height: 2),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, v, enfant) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - v)),
                    child: enfant,
                  ),
                ),
                // Réduit plutôt que coupé (gros texte du téléphone).
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    titre,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTheme.policeTitre,
                      fontWeight: FontWeight.w600,
                      fontSize: 34,
                      height: 1.1,
                      color: t.texte,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ],
    );
  }
}

/// Un bouton rond (réglages, « + ») : il rentre un peu sous le doigt.
class BoutonRond extends StatefulWidget {
  final IconData icone;
  final String aide;
  final VoidCallback onTap;

  /// À l'accent (le « + »).
  final bool fort;

  const BoutonRond({
    super.key,
    required this.icone,
    required this.aide,
    required this.onTap,
    this.fort = false,
  });

  @override
  State<BoutonRond> createState() => _BoutonRondState();
}

class _BoutonRondState extends State<BoutonRond> {
  bool _appuye = false;

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final couleur = widget.fort ? t.accent : t.doux;
    return Semantics(
      button: true,
      label: widget.aide,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _appuye = true),
        onTapCancel: () => setState(() => _appuye = false),
        onTapUp: (_) => setState(() => _appuye = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _appuye ? 0.86 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.fort
                  ? t.accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              border: Border.all(color: widget.fort ? t.accent : t.barre),
            ),
            child: Icon(widget.icone, size: 22, color: couleur),
          ),
        ),
      ),
    );
  }
}

/// L'intitulé d'une partie : petites capitales espacées, souligné ; le
/// détail passe à la ligne plutôt que d'être coupé.
class Etiquette extends StatelessWidget {
  final String texte;
  final String? detail;
  final Color? couleur;

  const Etiquette(this.texte, {super.key, this.detail, this.couleur});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final c = couleur ?? t.texte;
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.withValues(alpha: 0.35))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Text(
            texte.toUpperCase(),
            style: TextStyle(
              fontFamily: AppTheme.policeTitre,
              fontWeight: FontWeight.w500,
              fontSize: 11,
              letterSpacing: 2,
              color: c,
            ),
          ),
          if (detail case final d? when d.isNotEmpty)
            Text(
              d,
              style: TextStyle(
                fontFamily: AppTheme.policeMono,
                fontSize: 11,
                color: t.doux,
              ),
            ),
        ],
      ),
    );
  }
}

/// Le petit message du bas après une action, avec « Annuler » pendant
/// 4 secondes quand on peut revenir en arrière. Une vibration légère
/// accompagne l'action.
void annonce(BuildContext context, String texte, {VoidCallback? annuler}) {
  HapticFeedback.lightImpact();
  final messager = ScaffoldMessenger.of(context);
  messager.hideCurrentSnackBar();
  messager.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 4),
      content: Text(texte),
      action: annuler == null
          ? null
          : SnackBarAction(label: 'Annuler', onPressed: annuler),
    ),
  );
}

/// La barre du bas : trois onglets, chacun à sa couleur ; un trait glisse
/// au-dessus de l'onglet choisi ; une pastille peut compter ce qui
/// attend (elle saute quand le nombre grandit).
class BarreEspace extends StatelessWidget {
  final int index;
  final List<({String libelle, IconData icone, Color couleur})> onglets;
  final ValueChanged<int> onChoix;

  /// Un nombre par onglet (nul : pas de pastille).
  final List<int?> pastilles;

  const BarreEspace({
    super.key,
    required this.index,
    required this.onglets,
    required this.onChoix,
    this.pastilles = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final couleur = onglets[index].couleur;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.fond,
        border: Border(top: BorderSide(color: t.trait)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: LayoutBuilder(
            builder: (context, c) {
              final largeur = c.maxWidth / onglets.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    left: largeur * index,
                    top: 0,
                    width: largeur,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      height: 2,
                      color: couleur,
                    ),
                  ),
                  Row(
                    children: [
                      for (final (i, o) in onglets.indexed)
                        Expanded(
                          child: _Onglet(
                            key: ValueKey('onglet-$i'),
                            libelle: o.libelle,
                            icone: o.icone,
                            couleur: o.couleur,
                            choisi: i == index,
                            pastille: i < pastilles.length
                                ? pastilles[i]
                                : null,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onChoix(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  final String libelle;
  final IconData icone;
  final Color couleur;
  final bool choisi;
  final int? pastille;
  final VoidCallback onTap;

  const _Onglet({
    super.key,
    required this.libelle,
    required this.icone,
    required this.couleur,
    required this.choisi,
    required this.pastille,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final c = choisi ? couleur : t.doux;
    return Semantics(
      button: true,
      selected: choisi,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          decoration: BoxDecoration(
            color: choisi ? couleur.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(t.rayon),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSlide(
                    offset: Offset(0, choisi ? -0.08 : 0),
                    duration: const Duration(milliseconds: 300),
                    child: Icon(icone, size: 22, color: c),
                  ),
                  if (pastille case final n? when n > 0)
                    Positioned(
                      right: -14,
                      top: -6,
                      child: _Pastille(nombre: n, couleur: couleur),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  libelle.toUpperCase(),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTheme.policeTitre,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    letterSpacing: 1.8,
                    color: choisi ? couleur : t.doux,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La pastille d'un onglet : elle saute à chaque nouveau nombre.
class _Pastille extends StatelessWidget {
  final int nombre;
  final Color couleur;

  const _Pastille({required this.nombre, required this.couleur});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(nombre),
    tween: Tween(begin: 1.8, end: 1),
    duration: const Duration(milliseconds: 450),
    curve: Curves.elasticOut,
    builder: (context, v, enfant) => Transform.scale(scale: v, child: enfant),
    child: Container(
      key: const ValueKey('pastille'),
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.24),
        border: Border.all(color: couleur),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$nombre',
        style: TextStyle(
          fontFamily: AppTheme.policeMono,
          fontSize: 11,
          height: 1,
          color: couleur,
        ),
      ),
    ),
  );
}
