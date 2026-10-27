import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/deux_moi.dart';
import 'retro.dart';

/// En haut à gauche, toujours au même endroit : qui est là (revue du
/// 26/10/2026). Le demi-rond et le nom, ambre pour le Décideur (moitié
/// gauche du logo), bleu-vert pour l'Exécutant (moitié droite) ; à
/// droite, la date (et l'heure). Avant l'intro (repos), la date seule.
/// On change de toi en changeant d'onglet.
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
    final nom = Text(
      decideur ? 'DÉCIDEUR' : 'EXÉCUTANT',
      style: t.terminal
          ? styleMono(12, couleur: couleur, poids: FontWeight.w600)
          : TextStyle(
              color: couleur,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
    );
    final ligne = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!t.terminal) ...[
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
        ],
        nom,
      ],
    );
    // Chez l'Exécutant : dans un petit cadre, comme une étiquette de
    // terminal.
    final qui = t.terminal
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: couleur),
              borderRadius: BorderRadius.circular(t.rayon),
            ),
            child: ligne,
          )
        : ligne;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (moi != Moi.repos) qui,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: moi == Moi.repos ? TextAlign.start : TextAlign.end,
              style: t.terminal
                  ? styleMono(12, couleur: t.doux)
                  : TextStyle(
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
