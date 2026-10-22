import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_theme.dart';

/// Les 2 ou 3 réponses d'une question, côte à côte. La réponse choisie est
/// pleine (à sa couleur) ; la toucher à nouveau l'efface.
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
        for (var i = 0; i < nb; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: choix == i
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.couleurReponse(context, i, nb),
                      foregroundColor: AppTheme.texteSurReponse(context, i, nb),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () => onChoix(null),
                    child: _Libelle(question.reponses[i]),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () => onChoix(i),
                    child: _Libelle(question.reponses[i]),
                  ),
          ),
        ],
      ],
    );
  }
}

class _Libelle extends StatelessWidget {
  final String texte;

  const _Libelle(this.texte);

  @override
  Widget build(BuildContext context) => Text(
    texte,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
  );
}
