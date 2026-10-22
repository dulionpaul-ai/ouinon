import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/date_fr.dart';

/// Carte blanche très arrondie (32), le bloc de base du style.
class CarteRonde extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const CarteRonde({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Material(
      color: t.carte,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Petite pastille de texte (heure d'une question, date).
class Pastille extends StatelessWidget {
  final String texte;
  final Color? fond;
  final double hauteur;
  final double taille;

  const Pastille(
    this.texte, {
    super.key,
    this.fond,
    this.hauteur = 26,
    this.taille = 12,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Container(
      height: hauteur,
      padding: EdgeInsets.symmetric(horizontal: hauteur * 0.4),
      decoration: ShapeDecoration(
        color: fond ?? t.puce,
        shape: const StadiumBorder(),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          texte,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: taille,
            fontWeight: FontWeight.w700,
            color: fond == null || fond == t.puce || fond == t.carte
                ? t.texte
                : AppTheme.texteSurReponse(context, 0, 2),
          ),
        ),
      ),
    );
  }
}

/// Bouton rond (44) avec une icône.
class BoutonRond extends StatelessWidget {
  final IconData icone;
  final String infobulle;
  final VoidCallback? onPressed;

  const BoutonRond({
    super.key,
    required this.icone,
    required this.infobulle,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return IconButton(
      tooltip: infobulle,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: t.carte,
        disabledBackgroundColor: t.carte.withValues(alpha: 0.5),
        foregroundColor: t.texte,
        fixedSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
      icon: Icon(icone, size: 22),
    );
  }
}

/// Titre d'écran en Unbounded.
class GrandTitre extends StatelessWidget {
  final String texte;

  const GrandTitre(this.texte, {super.key});

  /// Réduit plutôt que coupé en deux lignes (gros texte du téléphone).
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      texte,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontFamily: AppTheme.policeTitre,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.1,
        color: Teintes.de(context).texte,
      ),
    ),
  );
}

/// La barre d'onglets flottante, en pilule.
class BarreOnglets extends StatelessWidget {
  final int index;
  final List<String> libelles;
  final ValueChanged<int> onChoix;

  const BarreOnglets({
    super.key,
    required this.index,
    required this.libelles,
    required this.onChoix,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(7),
          decoration: ShapeDecoration(
            color: t.barre,
            shape: const StadiumBorder(),
            shadows: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (final (i, libelle) in libelles.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      decoration: ShapeDecoration(
                        color: i == index ? t.accent : Colors.transparent,
                        shape: const StadiumBorder(),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () => onChoix(i),
                          child: Center(
                            child: Text(
                              libelle,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: i == index ? t.surAccent : t.texteBarre,
                              ),
                            ),
                          ),
                        ),
                      ),
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

/// Choix entre quelques options, en pilules dans une pilule (période des
/// stats, nombre de réponses).
class ChoixPilules<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T valeur;
  final ValueChanged<T> onChoix;

  const ChoixPilules({
    super.key,
    required this.options,
    required this.valeur,
    required this.onChoix,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: ShapeDecoration(color: t.carte, shape: const StadiumBorder()),
      child: Row(
        children: [
          for (final (v, libelle) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == valeur,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: ShapeDecoration(
                    color: v == valeur ? t.texte : Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onChoix(v),
                      child: Center(
                        child: Text(
                          libelle,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: v == valeur ? t.fond : t.texte,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bouton rond citron (ajouter).
class BoutonPlus extends StatelessWidget {
  final String infobulle;
  final VoidCallback onPressed;

  const BoutonPlus({
    super.key,
    required this.infobulle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return IconButton(
      tooltip: infobulle,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.surAccent,
        fixedSize: const Size(56, 56),
        shape: const CircleBorder(),
      ),
      icon: const Icon(Icons.add_rounded, size: 30),
    );
  }
}

/// Un jour de la semaine à cocher : rond, initiale, citron si choisi.
class JourRond extends StatelessWidget {
  final int index;
  final bool choisi;
  final VoidCallback onTap;

  /// Diamètre (44 au plus, moins sur un téléphone étroit).
  final double taille;

  const JourRond({
    super.key,
    required this.index,
    required this.choisi,
    required this.onTap,
    this.taille = 44,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      button: true,
      selected: choisi,
      label: nomJour(index + 1),
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: choisi ? t.accent : t.puce,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Text(
                initialesJours[index],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: choisi ? t.surAccent : t.doux,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Petite pilule à toucher (modèle de réponses, raccourci de jours) ;
/// citron quand elle est choisie.
class PiluleChoix extends StatelessWidget {
  final String texte;
  final bool choisie;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Texte centré et réduit si besoin (pilules côte à côte sur une ligne).
  final bool centree;

  const PiluleChoix(
    this.texte, {
    super.key,
    this.choisie = false,
    required this.onTap,
    this.onLongPress,
    this.centree = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      button: true,
      selected: choisie,
      child: Material(
        color: choisie ? t.accent : t.puce,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: centree ? 6 : 16,
              vertical: 11,
            ),
            child: _texte(t),
          ),
        ),
      ),
    );
  }

  Widget _texte(Teintes t) {
    final texte = Text(
      this.texte,
      maxLines: 1,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: choisie ? t.surAccent : t.texte,
      ),
    );
    return centree
        ? Center(
            heightFactor: 1,
            child: FittedBox(fit: BoxFit.scaleDown, child: texte),
          )
        : texte;
  }
}
