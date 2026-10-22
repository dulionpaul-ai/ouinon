import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';
import '../widgets/barres.dart';
import '../widgets/boutons_reponse.dart';
import '../widgets/rond.dart';
import 'edition_question_screen.dart';

/// Tout sur une question : bilan (7 jours, 30 jours, depuis le début),
/// évolution semaine par semaine, jour de la semaine, calendrier (toucher
/// un jour pour changer sa réponse).
class FicheQuestionScreen extends StatefulWidget {
  final Base base;
  final Question question;
  final DateTime Function() maintenant;

  const FicheQuestionScreen({
    super.key,
    required this.base,
    required this.question,
    this.maintenant = DateTime.now,
  });

  @override
  State<FicheQuestionScreen> createState() => _FicheQuestionScreenState();
}

enum _Periode { semaine, mois, tout }

class _FicheQuestionScreenState extends State<FicheQuestionScreen> {
  late Question _q = widget.question;
  Reponses _reponses = const {};
  _Periode _periode = _Periode.mois;

  /// Premier jour du mois affiché dans le calendrier.
  late DateTime _mois;

  @override
  void initState() {
    super.initState();
    final auj = widget.maintenant();
    _mois = DateTime(auj.year, auj.month);
    widget.base.changements.addListener(_recharge);
    _recharge();
  }

  @override
  void dispose() {
    widget.base.changements.removeListener(_recharge);
    super.dispose();
  }

  Future<void> _recharge() async {
    final q = await widget.base.question(widget.question.id!);
    if (q == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final reponses = await widget.base.reponsesDe(q.id!);
    if (mounted) {
      setState(() {
        _q = q;
        _reponses = reponses;
      });
    }
  }

  Future<void> _changeJour(DateTime jour) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              majuscule(jourEtDate(jour)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            BoutonsReponse(
              question: _q,
              choix: _reponses[cleJour(jour)],
              onChoix: (c) async {
                Navigator.pop(context);
                if (c == null) {
                  await widget.base.efface(_q.id!, jour);
                } else {
                  await widget.base.repond(_q.id!, jour, c);
                  try {
                    await Notifications.instance.retire(_q.id!, jour);
                  } catch (_) {}
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doux = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final auj = jourDe(widget.maintenant());
    final b = bilan(
      _q,
      _reponses,
      debut: switch (_periode) {
        _Periode.semaine => ajouteJours(auj, -6),
        _Periode.mois => ajouteJours(auj, -29),
        _Periode.tout => null,
      },
      fin: auj,
    );
    final semaines = evolution(_q, _reponses, aujourdhui: auj);
    final lundis = [
      for (var s = semaines.length - 1; s >= 0; s--)
        ajouteJours(lundiDe(auj), -7 * s),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_q.texte),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EditionQuestionScreen(base: widget.base, question: _q),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: [
          ChoixPilules<_Periode>(
            options: const [
              (_Periode.semaine, '7 jours'),
              (_Periode.mois, '30 jours'),
              (_Periode.tout, 'Tout'),
            ],
            valeur: _periode,
            onChoix: (p) => setState(() => _periode = p),
          ),
          const SizedBox(height: 10),
          CarteRonde(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BarreBilan(question: _q, bilan: b, hauteur: 18),
                const SizedBox(height: 14),
                for (var i = 0; i < _q.nbReponses; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.couleurReponse(
                              context,
                              i,
                              _q.nbReponses,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _q.reponses[i],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          b.total == 0
                              ? '0'
                              : '${b.comptes[i]} · '
                                    '${(100 * b.comptes[i] / b.total).round()} %',
                          style: doux,
                        ),
                      ],
                    ),
                  ),
                if (b.total == 0)
                  Text('Pas de réponse sur cette période.', style: doux),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CarteRonde(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Semaine par semaine', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Part de « ${_q.reponses[0]} », semaines du lundi',
                  style: doux,
                ),
                const SizedBox(height: 14),
                Colonnes(
                  bilans: semaines,
                  etiquettes: [for (final l in lundis) '${l.day}'],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CarteRonde(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Selon le jour', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Part de « ${_q.reponses[0]} », depuis le début',
                  style: doux,
                ),
                const SizedBox(height: 14),
                Colonnes(
                  bilans: parJourSemaine(_q, _reponses),
                  etiquettes: initialesJours,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CarteRonde(child: _calendrier(context, auj, doux)),
        ],
      ),
    );
  }

  Widget _calendrier(BuildContext context, DateTime auj, TextStyle? doux) {
    final theme = Theme.of(context);
    final premier = _mois;
    final nbJours = DateTime(premier.year, premier.month + 1, 0).day;
    final avant = premier.weekday - 1;
    final moisCourant = premier.year == auj.year && premier.month == auj.month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                majuscule(moisEtAnnee(premier)),
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Mois d\'avant',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                () => _mois = DateTime(premier.year, premier.month - 1),
              ),
            ),
            IconButton(
              tooltip: 'Mois d\'après',
              icon: const Icon(Icons.chevron_right),
              onPressed: moisCourant
                  ? null
                  : () => setState(
                      () => _mois = DateTime(premier.year, premier.month + 1),
                    ),
            ),
          ],
        ),
        Row(
          children: [
            for (final j in initialesJours)
              Expanded(
                child: Center(
                  child: Text(j, style: theme.textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < avant; i++) const SizedBox.shrink(),
            for (var d = 1; d <= nbJours; d++)
              _case(context, DateTime(premier.year, premier.month, d), auj),
          ],
        ),
        const SizedBox(height: 4),
        Text('Touche un jour pour changer sa réponse.', style: doux),
      ],
    );
  }

  Widget _case(BuildContext context, DateTime jour, DateTime auj) {
    final theme = Theme.of(context);
    final choix = _reponses[cleJour(jour)];
    final futur = jour.isAfter(auj);
    final prevu = _q.revientLe(jour.weekday);
    final fond = choix == null
        ? Colors.transparent
        : AppTheme.couleurReponse(context, choix, _q.nbReponses);
    final texte = choix == null
        ? (futur || !prevu
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
              : theme.colorScheme.onSurface)
        : AppTheme.texteSurReponse(context, choix, _q.nbReponses);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: fond,
        shape: CircleBorder(
          side: choix == null && prevu && !futur
              ? BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: futur ? null : () => _changeJour(jour),
          child: Center(
            child: Text(
              '${jour.day}',
              style: TextStyle(
                color: texte,
                fontWeight: jour == auj ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
