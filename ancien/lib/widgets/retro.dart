import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Petites pièces de l'écran rétro du toi qui exécute (vieux terminal,
/// idée de Paul du 26/10/2026).

/// « 09:05 » (minutes depuis minuit).
String hhmm(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// Style des grands textes rétro (VT323, lueur légère).
TextStyle styleRetro(double taille, {Color couleur = AppTheme.bleuVert}) =>
    TextStyle(
      fontFamily: AppTheme.policeRetro,
      fontSize: taille,
      height: 1.05,
      color: couleur,
      shadows: [Shadow(color: couleur.withValues(alpha: 0.45), blurRadius: 8)],
    );

/// Style du texte courant rétro (IBM Plex Mono).
TextStyle styleMono(
  double taille, {
  Color couleur = AppTheme.bleuVert,
  FontWeight poids = FontWeight.w500,
}) => TextStyle(
  fontFamily: AppTheme.policeMono,
  fontSize: taille,
  fontWeight: poids,
  color: couleur,
  height: 1.4,
);

/// Le fond noir de l'écran, avec de fines lignes de balayage par-dessus.
/// Inactif, il ne dessine rien (même arbre : rien n'est perdu en passant
/// d'un mode à l'autre).
class FondRetro extends StatelessWidget {
  final Widget child;
  final bool actif;

  const FondRetro({super.key, required this.child, this.actif = true});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      child,
      Positioned.fill(
        child: IgnorePointer(child: CustomPaint(painter: _Balayage(actif))),
      ),
    ],
  );
}

class _Balayage extends CustomPainter {
  final bool actif;

  const _Balayage(this.actif);

  @override
  void paint(Canvas canvas, Size size) {
    if (!actif) return;
    final trait = Paint()..color = const Color(0x08FFFFFF);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), trait);
    }
  }

  @override
  bool shouldRepaint(_Balayage ancien) => ancien.actif != actif;
}

/// Le curseur du terminal, qui clignote.
class Curseur extends StatefulWidget {
  /// Désactivé dans les tests (une animation sans fin les bloque).
  static bool clignote = true;

  final double hauteur;

  /// Couleur du curseur : celle du texte, sauf choix contraire.
  final Color? couleur;

  const Curseur({super.key, this.hauteur = 22, this.couleur});

  @override
  State<Curseur> createState() => _CurseurState();
}

class _CurseurState extends State<Curseur> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (Curseur.clignote) _anim.repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (context, _) => Opacity(
      opacity: _anim.value < 0.5 ? 1 : 0,
      child: Container(
        width: widget.hauteur * 0.5,
        height: widget.hauteur,
        margin: const EdgeInsets.only(left: 4),
        color: widget.couleur ?? Teintes.de(context).texte,
      ),
    ),
  );
}

/// Un bouton rétro rectangulaire : « [ FAIT ] ».
class BoutonRetro extends StatelessWidget {
  final String texte;
  final VoidCallback? onTap;
  final bool plein;
  final Color? couleur;

  const BoutonRetro(
    this.texte, {
    super.key,
    this.onTap,
    this.plein = false,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final c = couleur ?? t.texte;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: plein ? c : Colors.transparent,
            border: Border.all(color: plein ? c : t.puce),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              texte,
              maxLines: 1,
              style: styleMono(
                14,
                couleur: plein ? t.fond : c,
                poids: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre de progression en caractères : « [██████░░░░] ».
String barreRetro(double part, {int cases = 14}) {
  final pleines = (part.clamp(0, 1) * cases).round();
  return '[${'█' * pleines}${'░' * (cases - pleines)}]';
}
