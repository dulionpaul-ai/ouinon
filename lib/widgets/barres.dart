import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/stats.dart';

/// Barre horizontale découpée selon les réponses : rouge à gauche, vert à
/// droite, dans l'ordre des boutons.
class BarreBilan extends StatelessWidget {
  final Question question;
  final Bilan bilan;
  final double hauteur;

  const BarreBilan({
    super.key,
    required this.question,
    required this.bilan,
    this.hauteur = 10,
  });

  @override
  Widget build(BuildContext context) {
    final vide = Teintes.de(context).puce;
    return ClipRRect(
      borderRadius: BorderRadius.circular(hauteur / 2),
      child: SizedBox(
        height: hauteur,
        child: bilan.total == 0
            ? ColoredBox(color: vide)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = bilan.comptes.length - 1; i >= 0; i--)
                    if (bilan.comptes[i] > 0)
                      Expanded(
                        flex: bilan.comptes[i],
                        child: ColoredBox(
                          color: AppTheme.couleurReponse(
                            context,
                            i,
                            question.nbReponses,
                          ),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

/// Colonnes verticales : la part de la meilleure réponse pour chaque
/// période (semaine, jour de la semaine…), avec leur étiquette.
class Colonnes extends StatelessWidget {
  final List<Bilan> bilans;
  final List<String> etiquettes;
  final double hauteur;

  const Colonnes({
    super.key,
    required this.bilans,
    required this.etiquettes,
    this.hauteur = 96,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = Teintes.de(context);
    final vert = t.meilleure;
    final fond = t.puce;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < bilans.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: hauteur,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: fond,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: bilans[i].partMeilleure == null
                        ? null
                        : FractionallySizedBox(
                            heightFactor: bilans[i].partMeilleure!.clamp(
                              0.04,
                              1.0,
                            ),
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: vert,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    etiquettes[i],
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
