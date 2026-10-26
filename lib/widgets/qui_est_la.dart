import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/deux_moi.dart';

/// En haut à gauche, toujours au même endroit : qui est là (revue du
/// 26/10/2026). Le demi-rond et le nom, ambre pour le Décideur (moitié
/// gauche du logo), bleu-vert pour l'Exécutant (moitié droite) ; à
/// droite, la date (et l'heure). Au repos, « Au repos ».
///
/// Toucher le nom fait passer à l'autre toi, en ascenseur ([onBascule],
/// demande de Paul du 26/10/2026).
class QuiEstLa extends StatelessWidget {
  final Moi moi;
  final String date;
  final Widget? fin;
  final VoidCallback? onBascule;

  const QuiEstLa({
    super.key,
    required this.moi,
    required this.date,
    this.fin,
    this.onBascule,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final decideur = moi == Moi.decideur;
    final couleur = decideur ? AppTheme.ambre : AppTheme.bleuVert;
    final nom = moi == Moi.repos
        ? Text(
            'AU REPOS',
            style: TextStyle(
              color: t.doux,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          )
        : Text(
            decideur ? 'DÉCIDEUR' : 'EXÉCUTANT',
            style: TextStyle(
              color: couleur,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          );
    final qui = Row(
      mainAxisSize: MainAxisSize.min,
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
        ],
        nom,
        if (onBascule != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.swap_vert_rounded, size: 18, color: t.doux),
        ],
      ],
    );
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (onBascule == null && moi != Moi.repos)
            qui
          else if (onBascule != null)
            Semantics(
              button: true,
              label: moi == Moi.executant
                  ? 'Passer au Décideur'
                  : 'Passer à l\'Exécutant',
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('bascule'),
                onTap: onBascule,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: qui,
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: onBascule == null && moi == Moi.repos
                  ? TextAlign.start
                  : TextAlign.end,
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
