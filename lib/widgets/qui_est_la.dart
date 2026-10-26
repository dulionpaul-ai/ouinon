import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/deux_moi.dart';

/// En haut à gauche, toujours au même endroit : qui est là (revue du
/// 26/10/2026). Le demi-rond et le nom, ambre pour le Décideur (moitié
/// gauche du logo), bleu-vert pour l'Exécutant (moitié droite) ; à
/// droite, la date (et l'heure). Au repos, la date seule.
class QuiEstLa extends StatelessWidget {
  final Moi moi;
  final String date;
  final Widget? fin;

  const QuiEstLa({super.key, required this.moi, required this.date, this.fin});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final decideur = moi == Moi.decideur;
    final couleur = decideur ? AppTheme.ambre : AppTheme.bleuVert;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (moi != Moi.repos) ...[
            Container(
              width: 8,
              height: 16,
              decoration: BoxDecoration(
                color: couleur,
                borderRadius: decideur
                    ? const BorderRadius.horizontal(left: Radius.circular(8))
                    : const BorderRadius.horizontal(right: Radius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              decideur ? 'DÉCIDEUR' : 'EXÉCUTANT',
              style: TextStyle(
                color: couleur,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: moi == Moi.repos ? TextAlign.start : TextAlign.end,
              style: TextStyle(
                color: t.doux,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?fin,
        ],
      ),
    );
  }
}
