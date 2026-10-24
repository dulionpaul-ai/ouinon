import 'package:flutter/material.dart';

import '../models/a_faire.dart';
import '../theme/app_theme.dart';
import '../utils/planning.dart';

/// Couleur d'une case d'Eisenhower : corail pour « D'abord », citron pour
/// « À planifier » (la case qui compte), abricot pour « Vite fait »,
/// neutre pour « Peut-être jamais ».
Color couleurCase(BuildContext context, Case c) {
  final t = Teintes.de(context);
  return switch (c) {
    Case.dabord => t.moinsBonne,
    Case.aPlanifier => t.meilleure,
    Case.viteFait => t.moyenne,
    Case.peutEtreJamais => t.puce,
  };
}

/// Texte sur la couleur d'une case.
Color texteSurCase(BuildContext context, Case c) =>
    c == Case.peutEtreJamais ? Teintes.de(context).texte : Teintes.sombre.fond;

/// Les 4 cases en grille 2 × 2 (urgent à gauche, important en haut) :
/// combien de choses et combien de temps dans chacune. Toucher une case
/// la montre.
class Matrice extends StatelessWidget {
  final Map<Case, List<AFaire>> parCase;
  final ValueChanged<Case> onChoix;

  const Matrice({super.key, required this.parCase, required this.onChoix});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    Widget cellule(Case c) {
      final liste = parCase[c] ?? const [];
      final minutes = liste.fold(0, (s, a) => s + a.duree);
      final couleur = couleurCase(context, c);
      final texte = texteSurCase(context, c);
      return Expanded(
        child: Material(
          color: liste.isEmpty && c != Case.peutEtreJamais
              ? couleur.withValues(alpha: 0.25)
              : couleur,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChoix(c),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      c.nom,
                      maxLines: 1,
                      style: TextStyle(
                        color: liste.isEmpty ? t.texte : texte,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${liste.length}',
                    style: TextStyle(
                      fontFamily: AppTheme.policeTitre,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: liste.isEmpty ? t.texte : texte,
                    ),
                  ),
                  Text(
                    liste.isEmpty ? 'rien' : dureeFr(minutes),
                    style: TextStyle(
                      color: (liste.isEmpty ? t.texte : texte).withValues(
                        alpha: 0.75,
                      ),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            cellule(Case.dabord),
            const SizedBox(width: 8),
            cellule(Case.aPlanifier),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            cellule(Case.viteFait),
            const SizedBox(width: 8),
            cellule(Case.peutEtreJamais),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '← Urgent',
                style: TextStyle(color: t.doux, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                'Pas urgent →',
                textAlign: TextAlign.right,
                style: TextStyle(color: t.doux, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
