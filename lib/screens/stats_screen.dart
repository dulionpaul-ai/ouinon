import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';
import '../widgets/barres.dart';
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
    final theme = Theme.of(context);
    final doux = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final aujourdhui = jourDe(widget.maintenant());
    final liensMontres = _tousLesLiens
        ? _liens
        : _liens.take(_liensMontres).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Stats'), titleSpacing: 24),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text('Ce qui va avec quoi', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_liens.isEmpty)
            Text(
              'Les liens entre tes questions apparaîtront après au moins '
              '$minJoursCommuns jours de réponses, quand un écart net se '
              'dessine.',
              style: doux,
            )
          else ...[
            for (final l in liensMontres)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phraseLien(l), style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text('Sur ${l.jours} jours.', style: doux),
                  ],
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
            const SizedBox(height: 4),
            Text(
              'Ce sont des coïncidences observées dans tes réponses, pas des '
              'causes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text('30 derniers jours', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          for (final q in _questions) _carte(context, q, aujourdhui, doux),
        ],
      ),
    );
  }

  Widget _carte(
    BuildContext context,
    Question q,
    DateTime aujourdhui,
    TextStyle? doux,
  ) {
    final b = bilan(
      q,
      _reponses[q.id] ?? const {},
      debut: ajouteJours(aujourdhui, -29),
      fin: aujourdhui,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.texte,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 8),
            BarreBilan(question: q, bilan: b),
            const SizedBox(height: 6),
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
