import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/question.dart';
import '../theme/app_theme.dart';

/// Les 2 ou 3 réponses d'une question, en pilules côte à côte. La réponse
/// choisie prend sa couleur ; la toucher à nouveau l'efface.
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
    final t = Teintes.de(context);
    final nb = question.nbReponses;
    return Row(
      children: [
        for (var i = 0; i < nb; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Pilule(
              texte: question.reponses[i],
              choisie: choix == i,
              fond: choix == i
                  ? AppTheme.couleurReponse(context, i, nb)
                  : t.puce,
              couleurTexte: choix == i
                  ? AppTheme.texteSurReponse(context, i, nb)
                  : t.texte,
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
  final Color fond;
  final Color couleurTexte;
  final VoidCallback onTap;

  const _Pilule({
    required this.texte,
    required this.choisie,
    required this.fond,
    required this.couleurTexte,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: choisie,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 54,
        decoration: ShapeDecoration(color: fond, shape: const StadiumBorder()),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
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
                      color: couleurTexte,
                      fontSize: 15,
                      fontWeight: choisie ? FontWeight.w800 : FontWeight.w600,
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
