import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../utils/date_fr.dart';

/// Ajout ou modification d'une question : texte, 2 ou 3 réponses (la
/// meilleure d'abord), heure de la notification, jours.
class EditionQuestionScreen extends StatefulWidget {
  final Base base;

  /// Nulle pour une nouvelle question.
  final Question? question;

  const EditionQuestionScreen({super.key, required this.base, this.question});

  @override
  State<EditionQuestionScreen> createState() => _EditionQuestionScreenState();
}

class _EditionQuestionScreenState extends State<EditionQuestionScreen> {
  static const _parDefaut = {
    2: ['Oui', 'Non'],
    3: ['Bien', 'Moyen', 'Pas bien'],
  };

  late final TextEditingController _texte;
  late List<TextEditingController> _reponses;
  late int _heure;
  late int _jours;
  String? _erreur;

  bool get _nouvelle => widget.question == null;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _texte = TextEditingController(text: q?.texte ?? '');
    _reponses = [
      for (final r in q?.reponses ?? _parDefaut[2]!)
        TextEditingController(text: r),
    ];
    _heure = q?.heure ?? 21 * 60;
    _jours = q?.jours ?? Question.tousLesJours;
  }

  @override
  void dispose() {
    _texte.dispose();
    for (final c in _reponses) {
      c.dispose();
    }
    super.dispose();
  }

  void _nombre(int nb) {
    final avant = [for (final c in _reponses) c.text];
    final inchange = _parDefaut.values.any(
      (d) =>
          d.length == avant.length &&
          d.indexed.every((e) => avant[e.$1] == e.$2),
    );
    setState(() {
      if (inchange) {
        for (final c in _reponses) {
          c.dispose();
        }
        _reponses = [
          for (final r in _parDefaut[nb]!) TextEditingController(text: r),
        ];
      } else if (nb > _reponses.length) {
        _reponses = [
          _reponses[0],
          TextEditingController(),
          ..._reponses.skip(1),
        ];
      } else {
        _reponses.removeAt(1).dispose();
      }
    });
  }

  Future<void> _choisitHeure() async {
    final choisie = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _heure ~/ 60, minute: _heure % 60),
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    if (choisie != null) {
      setState(() => _heure = choisie.hour * 60 + choisie.minute);
    }
  }

  Future<void> _enregistre() async {
    final texte = _texte.text.trim();
    final reponses = [for (final c in _reponses) c.text.trim()];
    final erreur = texte.isEmpty
        ? 'Écris la question.'
        : reponses.any((r) => r.isEmpty)
        ? 'Donne un nom à chaque réponse.'
        : reponses.toSet().length != reponses.length
        ? 'Les réponses doivent être différentes.'
        : _jours == 0
        ? 'Choisis au moins un jour.'
        : null;
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    final base =
        widget.question ?? Question(texte: '', reponses: reponses, heure: 0);
    await widget.base.enregistre(
      base.copie(
        texte: texte,
        reponses: reponses,
        heure: _heure,
        jours: _jours,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pause() async {
    final q = widget.question!;
    await widget.base.enregistre(q.copie(active: !q.active));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _supprime() async {
    final q = widget.question!;
    final nb = (await widget.base.reponsesDe(q.id!)).length;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la question ?'),
        content: Text(
          nb == 0
              ? 'Elle n\'a encore aucune réponse.'
              : 'Ses $nb réponse${nb > 1 ? 's' : ''} seront effacées. '
                    'Pour les garder, mets-la plutôt en pause.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.base.supprime(q.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doux = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final nb = _reponses.length;
    final q = widget.question;
    return Scaffold(
      appBar: AppBar(title: Text(_nouvelle ? 'Nouvelle question' : 'Modifier')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          TextField(
            controller: _texte,
            autofocus: _nouvelle,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Question',
              hintText: 'Ex. : Bu assez d\'eau ?',
            ),
          ),
          const SizedBox(height: 16),
          Text('Réponses', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'La meilleure d\'abord, la moins bonne en dernier.',
            style: doux,
          ),
          const SizedBox(height: 12),
          if (_nouvelle)
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2 réponses')),
                ButtonSegment(value: 3, label: Text('3 réponses')),
              ],
              selected: {nb},
              onSelectionChanged: (s) => _nombre(s.first),
            )
          else
            Text(
              '$nb réponses (fixé à la création, pour garder l\'historique '
              'juste).',
              style: doux,
            ),
          const SizedBox(height: 12),
          for (final (i, c) in _reponses.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ValueKey('reponse$i'),
                controller: c,
                maxLength: Question.longueurMaxReponse,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: i == 0
                      ? 'Meilleure réponse'
                      : i == nb - 1
                      ? 'Moins bonne réponse'
                      : 'Entre les deux',
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Notification', style: theme.textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Heure'),
            trailing: Text(heureFr(_heure), style: theme.textTheme.titleMedium),
            onTap: _choisitHeure,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(joursCourts[i]),
                  showCheckmark: false,
                  selected: _jours & (1 << i) != 0,
                  onSelected: (_) => setState(() => _jours ^= 1 << i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(joursFr(_jours), style: doux),
          if (_erreur != null) ...[
            const SizedBox(height: 16),
            Text(_erreur!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _enregistre,
            child: const Text('Enregistrer'),
          ),
          if (q != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _pause,
              child: Text(q.active ? 'Mettre en pause' : 'Reprendre'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _supprime,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        ],
      ),
    );
  }
}
