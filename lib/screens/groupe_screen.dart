import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/courbes.dart';
import '../utils/familles.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';
import '../widgets/graphiques.dart';
import '../widgets/rond.dart';
import 'fiche_question_screen.dart';

/// L'analyse d'un groupe de questions qui s'évaluent ensemble (Paul,
/// 27/10/2026) : « Sport » = Cardio ? + Muscu ?. En haut, le groupe
/// entier (anneau, moyenne, courbe) ; en dessous, le détail de chaque
/// question, que l'on peut ouvrir.
class GroupeScreen extends StatelessWidget {
  final Base base;
  final Famille groupe;

  /// Toutes les réponses, par question.
  final Map<int, Reponses> reponses;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const GroupeScreen({
    super.key,
    required this.base,
    required this.groupe,
    required this.reponses,
    this.maintenant = DateTime.now,
  });

  static const _jours = 91;

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final aujourdhui = jourDe(maintenant());
    final debut = ajouteJours(aujourdhui, -(_jours - 1));
    final g = groupe.commeQuestion;
    final n = groupe.questions.length;
    // Moyenne des 30 derniers jours renseignés.
    final depuis = cleJour(ajouteJours(aujourdhui, -29));
    final recents = [
      for (final MapEntry(:key, :value) in groupe.reponses.entries)
        if (key.compareTo(depuis) >= 0) (2 * n - value) / 2,
    ];
    final moyenne = recents.isEmpty
        ? null
        : recents.reduce((a, b) => a + b) / recents.length;
    final bilanGroupe = bilan(
      g,
      groupe.reponses,
      debut: debut,
      fin: aujourdhui,
    );
    final membres = groupe.questions;
    return Scaffold(
      appBar: AppBar(title: Text(groupe.nom)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
            child: Text(
              [for (final q in membres) q.texte].join(' + '),
              style: TextStyle(color: t.doux, fontSize: 15),
            ),
          ),
          CarteRonde(
            child: AnimeQuandVisible(
              builder: (context, avance) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Anneau(
                        question: g,
                        bilan: bilanGroupe,
                        t: avance,
                        taille: 92,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              moyenne == null
                                  ? '—'
                                  : '${points((moyenne * 10).round() / 10)} sur $n',
                              key: const ValueKey('moyenne-groupe'),
                              style: const TextStyle(
                                fontFamily: AppTheme.policeMono,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'par jour en moyenne (30 jours)',
                              style: TextStyle(color: t.doux, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Anneau : jours à $n sur $n',
                              style: TextStyle(color: t.doux, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Courbes(
                    debut: debut,
                    a: courbeLissee(g, groupe.reponses, aujourdhui, _jours),
                    couleurA: t.accent,
                    nomA: groupe.nom,
                    t: avance,
                    hauteur: 170,
                  ),
                ],
              ),
            ),
          ),
          // Deux questions : leurs deux courbes l'une sur l'autre.
          if (membres.length == 2) ...[
            const SizedBox(height: 10),
            CarteRonde(
              child: AnimeQuandVisible(
                builder: (context, avance) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${membres[0].texte} et ${membres[1].texte}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Courbes(
                      debut: debut,
                      a: courbeLissee(
                        membres[0],
                        reponses[membres[0].id] ?? const {},
                        aujourdhui,
                        _jours,
                      ),
                      couleurA: t.accent,
                      nomA: membres[0].texte,
                      b: courbeLissee(
                        membres[1],
                        reponses[membres[1].id] ?? const {},
                        aujourdhui,
                        _jours,
                      ),
                      couleurB: t.moyenne,
                      nomB: membres[1].texte,
                      t: avance,
                      hauteur: 150,
                    ),
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
            child: Text(
              'Le détail',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final q in membres)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Membre(
                key: ValueKey('membre-${q.id}'),
                question: q,
                reponses: reponses[q.id] ?? const {},
                debut: debut,
                aujourdhui: aujourdhui,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FicheQuestionScreen(
                      base: base,
                      question: q,
                      maintenant: maintenant,
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

class _Membre extends StatelessWidget {
  final Question question;
  final Reponses reponses;
  final DateTime debut;
  final DateTime aujourdhui;
  final VoidCallback onTap;

  const _Membre({
    super.key,
    required this.question,
    required this.reponses,
    required this.debut,
    required this.aujourdhui,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return CarteRonde(
      onTap: onTap,
      child: AnimeQuandVisible(
        builder: (context, avance) => Row(
          children: [
            Anneau(
              question: question,
              bilan: bilan(question, reponses, debut: debut, fin: aujourdhui),
              t: avance,
              taille: 64,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          question.texte,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: t.doux),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Courbes(
                    debut: debut,
                    a: courbeLissee(
                      question,
                      reponses,
                      aujourdhui,
                      GroupeScreen._jours,
                    ),
                    couleurA: t.meilleure,
                    nomA: question.texte,
                    t: avance,
                    hauteur: 44,
                    mini: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
