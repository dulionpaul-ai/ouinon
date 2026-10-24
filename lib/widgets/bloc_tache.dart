import 'package:flutter/material.dart';

import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/planning.dart';
import 'boutons_reponse.dart';
import 'rond.dart';

/// Une chose prévue, en bloc horaire : l'heure de début et de fin à
/// gauche, la carte à droite (avec un liseré à la couleur de la réponse),
/// et ses boutons si on peut y répondre.
class BlocTache extends StatelessWidget {
  final Tache tache;
  final VoidCallback? onTap;

  /// Nul : pas de boutons (jour à venir).
  final ValueChanged<int?>? onChoix;

  /// Horaire qui croise une autre chose du même jour.
  final bool croise;

  const BlocTache({
    super.key,
    required this.tache,
    this.onTap,
    this.onChoix,
    this.croise = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final couleur = switch (tache.etat) {
      Tache.fait => t.meilleure,
      Tache.pasFait => t.moinsBonne,
      _ => t.puce,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Padding(
            padding: const EdgeInsets.only(top: 16, right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Réduites plutôt que coupées (gros texte).
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    heureFr(tache.debut),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    heureFr(tache.fin % (24 * 60)),
                    maxLines: 1,
                    style: TextStyle(color: t.doux, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: CarteRonde(
            onTap: onTap,
            padding: EdgeInsets.zero,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 6,
                    color: couleur,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tache.texte,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              decoration: tache.etat == Tache.fait
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: t.doux,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Pastille(dureeFr(tache.duree)),
                              if (tache.reports > 0)
                                Pastille(
                                  tache.reports == 1
                                      ? 'Reportée'
                                      : 'Reportée ${tache.reports} fois',
                                ),
                              if (croise) Pastille('Croise', fond: t.moyenne),
                            ],
                          ),
                          if (onChoix != null) ...[
                            const SizedBox(height: 10),
                            BoutonsReponse(
                              question: reponsesTache,
                              choix: tache.etat,
                              onChoix: onChoix!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Le temps libre entre deux choses prévues (« Libre · 2 h »).
class EcartLibre extends StatelessWidget {
  final int minutes;

  const EcartLibre(this.minutes, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(58, 2, 0, 10),
      child: Row(
        children: [
          Container(width: 2, height: 18, color: t.trait),
          const SizedBox(width: 10),
          Text(
            'Libre · ${dureeFr(minutes)}',
            style: TextStyle(color: t.doux, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Les choses d'un jour en blocs, avec le temps libre entre elles.
List<Widget> blocsDuJour(
  List<Tache> taches, {
  required void Function(Tache) onTap,
  void Function(Tache, int?)? onChoix,
}) {
  final blocs = <Widget>[];
  int? finPrecedente;
  for (final tache in taches) {
    final ecart = finPrecedente == null ? 0 : tache.debut - finPrecedente;
    if (ecart >= 30) {
      blocs.add(EcartLibre(ecart, key: ValueKey('libre-${tache.id}')));
    } else if (blocs.isNotEmpty) {
      blocs.add(const SizedBox(height: 8));
    }
    blocs.add(
      BlocTache(
        key: ValueKey('tache-${tache.id}'),
        tache: tache,
        croise: chevauchements(tache, taches).isNotEmpty,
        onTap: () => onTap(tache),
        onChoix: onChoix == null ? null : (c) => onChoix(tache, c),
      ),
    );
    final fin = tache.fin;
    finPrecedente = finPrecedente == null || fin > finPrecedente
        ? fin
        : finPrecedente;
  }
  return blocs;
}
