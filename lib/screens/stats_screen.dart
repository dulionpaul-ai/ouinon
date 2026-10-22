import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';
import '../theme/app_theme.dart';
import '../widgets/barres.dart';
import '../widgets/rond.dart';
import 'fiche_question_screen.dart';

/// Les liens les plus nets entre questions, puis le bilan des 30 derniers
/// jours de chaque question (toucher pour le détail).
class StatsScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const StatsScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _liensMontres = 5;

  List<Question> _questions = const [];
  Map<int, Reponses> _reponses = const {};
  List<Lien> _liens = const [];
  bool _tousLesLiens = false;

  @override
  void initState() {
    super.initState();
    widget.base.changements.addListener(_recharge);
    _recharge();
  }

  @override
  void dispose() {
    widget.base.changements.removeListener(_recharge);
    super.dispose();
  }

  Future<void> _recharge() async {
    final questions = await widget.base.questions();
    final reponses = await widget.base.toutesLesReponses();
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _reponses = reponses;
      _liens = liens(questions, reponses);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux);
    final aujourdhui = jourDe(widget.maintenant());
    final liensMontres = _tousLesLiens
        ? _liens
        : _liens.take(_liensMontres).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 22, 6, 18),
              child: GrandTitre('Stats'),
            ),
            _Section('Ce qui va avec quoi'),
            if (_liens.isEmpty)
              CarteRonde(
                child: Text(
                  'Les liens entre tes questions apparaîtront après au moins '
                  '$minJoursCommuns jours de réponses, quand un écart net se '
                  'dessine.',
                  style: doux,
                ),
              )
            else ...[
              for (final l in liensMontres)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CarteRonde(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phraseLien(l),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Pastille('Sur ${l.jours} jours.'),
                      ],
                    ),
                  ),
                ),
              if (_liens.length > _liensMontres)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _tousLesLiens = !_tousLesLiens),
                    child: Text(
                      _tousLesLiens
                          ? 'Voir moins'
                          : 'Voir les ${_liens.length} liens',
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                child: Text(
                  'Ce sont des coïncidences observées dans tes réponses, pas '
                  'des causes.',
                  style: doux.copyWith(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _Section('30 derniers jours'),
            for (final q in _questions) _carte(context, q, aujourdhui, doux),
          ],
        ),
      ),
    );
  }

  Widget _carte(
    BuildContext context,
    Question q,
    DateTime aujourdhui,
    TextStyle doux,
  ) {
    final b = bilan(
      q,
      _reponses[q.id] ?? const {},
      debut: ajouteJours(aujourdhui, -29),
      fin: aujourdhui,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CarteRonde(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FicheQuestionScreen(
              base: widget.base,
              question: q,
              maintenant: widget.maintenant,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.texte,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: doux.color),
              ],
            ),
            const SizedBox(height: 12),
            BarreBilan(question: q, bilan: b, hauteur: 14),
            const SizedBox(height: 8),
            Text(
              b.total == 0
                  ? 'Pas encore de réponse.'
                  : '« ${q.reponses[0]} » ${foisSurDix(b.partMeilleure!)} '
                        '(${b.total} réponse${b.total > 1 ? 's' : ''})',
              style: doux,
            ),
          ],
        ),
      ),
    );
  }
}

/// Intertitre de section.
class _Section extends StatelessWidget {
  final String texte;

  const _Section(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
    child: Text(texte, style: Theme.of(context).textTheme.titleLarge),
  );
}
