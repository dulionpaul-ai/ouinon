import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/date_fr.dart';

/// Carte sombre arrondie, le bloc de base du style.
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.rayon + 6),
      ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.rayonPetit),
        ),
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

/// Titre d'écran, dans la police de l'appli.
class GrandTitre extends StatelessWidget {
  final String texte;

  const GrandTitre(this.texte, {super.key});

  /// Réduit plutôt que coupé en deux lignes (gros texte du téléphone).
  /// Chez l'Exécutant, en majuscules de vieux terminal.
  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        t.terminal ? texte.toUpperCase() : texte,
        maxLines: 1,
        softWrap: false,
        style: t.terminal
            ? TextStyle(
                fontFamily: AppTheme.policeRetro,
                fontSize: 42,
                height: 1,
                color: t.accent,
                shadows: [
                  Shadow(color: t.accent.withValues(alpha: 0.4), blurRadius: 8),
                ],
              )
            : TextStyle(
                fontFamily: AppTheme.policeTitre,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
                height: 1.1,
                color: t.texte,
              ),
      ),
    );
  }
}

/// La barre d'onglets flottante, en pilule.
class BarreOnglets extends StatelessWidget {
  final int index;
  final List<String> libelles;
  final ValueChanged<int> onChoix;

  /// Le bouton Ascenseur, à droite des onglets.
  final Widget? ascenseur;

  const BarreOnglets({
    super.key,
    required this.index,
    required this.libelles,
    required this.onChoix,
    this.ascenseur,
  });

  /// Revue le 26/10/2026 (moins rond) : posée en bas, des mots ; celui
  /// choisi souligné à l'accent. Chez l'Exécutant, trois touches carrées
  /// de terminal, la choisie pleine.
  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    Widget onglet(int i, String libelle) {
      final choisi = i == index;
      // Orbite (27/10/2026) : des mots en capitales, l'onglet choisi
      // posé sur un voile orange translucide cerclé d'orange.
      return Expanded(
        child: Semantics(
          button: true,
          selected: choisi,
          child: GestureDetector(
            key: ValueKey('onglet-$i'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onChoix(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: choisi
                    ? t.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(t.rayon),
                border: Border.all(
                  color: choisi ? t.accent : Colors.transparent,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                // Réduit plutôt que coupé (petit téléphone, gros texte).
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    libelle.toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppTheme.policeTitre,
                      fontSize: 10,
                      letterSpacing: 1,
                      color: choisi ? t.accent : t.texteBarre,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.fond,
        border: Border(top: BorderSide(color: t.puce)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                // Un seul onglet (l'Exécutant) : rien à choisir, la
                // barre ne garde que l'ascenseur (retour de Paul du
                // 26/10/2026).
                if (libelles.length < 2)
                  const Spacer()
                else
                  for (final (i, libelle) in libelles.indexed) ...[
                    if (i > 0 && t.terminal) const SizedBox(width: 6),
                    onglet(i, libelle),
                  ],
                if (ascenseur != null) ...[
                  const SizedBox(width: 8),
                  ascenseur!,
                ],
              ],
            ),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          // Réduit plutôt que coupé (gros texte).
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
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

/// Série en cours : petite flamme citron et nombre de jours d'affilée.
class PastilleSerie extends StatelessWidget {
  final int jours;

  const PastilleSerie(this.jours, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      label: '$jours jours d\'affilée',
      excludeSemantics: true,
      child: Container(
        height: 26,
        padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
        decoration: ShapeDecoration(
          color: t.puce,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: t.accent,
            ),
            const SizedBox(width: 3),
            Text(
              '$jours',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: t.texte,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le bouton Ascenseur (26/10/2026) : toujours à droite de la barre du
/// bas, bien visible, à la couleur du toi où il mène (ambre vers le
/// Décideur, bleu-vert vers l'Exécutant).
class BoutonAscenseur extends StatelessWidget {
  /// Vers le Décideur (▲), sinon vers l'Exécutant (▼).
  final bool versLeSoir;
  final VoidCallback onTap;

  const BoutonAscenseur({
    super.key,
    required this.versLeSoir,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final couleur = versLeSoir ? AppTheme.ambre : AppTheme.bleuVert;
    return Semantics(
      button: true,
      label: versLeSoir
          ? 'Ascenseur vers le Décideur'
          : 'Ascenseur vers l\'Exécutant',
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('ascenseur'),
        color: couleur.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: couleur, width: 1.5),
          borderRadius: BorderRadius.circular(t.rayon),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.rayon),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  versLeSoir
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 18,
                  color: couleur,
                ),
                const SizedBox(width: 6),
                Text(
                  versLeSoir ? 'Décideur' : 'Exécutant',
                  maxLines: 1,
                  style: TextStyle(
                    color: couleur,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
