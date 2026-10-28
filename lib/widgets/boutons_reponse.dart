import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/question.dart';
import '../theme/app_theme.dart';

/// Les 2 ou 3 réponses d'une question, en pilules côte à côte : la moins
/// bonne à gauche, la meilleure à droite, comme dans la notification
/// (choix de Paul). Chaque réponse a sa couleur, translucide (vert d'eau
/// la meilleure, gris au milieu, orange la moins bonne) ; la choisie
/// s'allume ; la toucher à nouveau l'efface.
class BoutonsReponse extends StatelessWidget {
  final Question question;
  final int? choix;
  final ValueChanged<int?> onChoix;

  const BoutonsReponse({
    super.key,
    required this.question,
    required this.choix,
    required this.onChoix,
  });

  @override
  Widget build(BuildContext context) {
    final nb = question.nbReponses;
    return Row(
      children: [
        for (var i = nb - 1; i >= 0; i--) ...[
          if (i < nb - 1) const SizedBox(width: 6),
          Expanded(
            child: _Pilule(
              texte: question.reponses[i],
              choisie: choix == i,
              couleur: AppTheme.couleurReponse(context, i, nb),
              onTap: () => onChoix(choix == i ? null : i),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pilule extends StatelessWidget {
  final String texte;
  final bool choisie;
  final Color couleur;
  final VoidCallback onTap;

  const _Pilule({
    required this.texte,
    required this.choisie,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Choisie : elle se gonfle un instant, comme une touche qui répond.
    return TweenAnimationBuilder<double>(
      key: ValueKey(choisie),
      tween: Tween(begin: choisie ? 0.9 : 1, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, v, enfant) => Transform.scale(scale: v, child: enfant),
      child: Semantics(
        button: true,
        selected: choisie,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 46,
          decoration: ShapeDecoration(
            color: couleur.withValues(alpha: choisie ? 0.26 : 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Teintes.de(context).rayon),
              side: BorderSide(
                color: couleur.withValues(alpha: choisie ? 1 : 0.5),
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: Teintes.de(context).forme,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  // Réduit plutôt que coupé (« Moins de 6 h »).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      texte,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: couleur,
                        fontSize: 14,
                        fontWeight: choisie ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
