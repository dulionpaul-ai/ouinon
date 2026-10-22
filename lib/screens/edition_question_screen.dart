import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../utils/date_fr.dart';
import '../theme/app_theme.dart';
import '../widgets/rond.dart';

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

  /// Réponses toutes prêtes, pour aller vite.
  static const _modeles = [
    ['Oui', 'Non'],
    ['Bien', 'Moyen', 'Pas bien'],
    ['Beaucoup', 'Un peu', 'Pas du tout'],
  ];

  void _modele(List<String> m) => setState(() {
    for (final c in _reponses) {
      c.dispose();
    }
    _reponses = [for (final r in m) TextEditingController(text: r)];
  });

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
    final t = Teintes.de(context);
    final theme = Theme.of(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    final nb = _reponses.length;
    final q = widget.question;
    Widget titre(String texte) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Text(texte, style: theme.textTheme.titleMedium),
    );
    return Scaffold(
      appBar: AppBar(title: Text(_nouvelle ? 'Nouvelle question' : 'Modifier')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: FilledButton(
          onPressed: _enregistre,
          child: const Text('Enregistrer'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          titre('Question'),
          TextField(
            controller: _texte,
            autofocus: _nouvelle,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Ex. : Bu assez d\'eau ?',
              counterText: '',
            ),
          ),
          titre('Réponses'),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            child: Text(
              'La meilleure en haut (citron), la moins bonne en bas '
              '(corail).',
              style: doux,
            ),
          ),
          if (_nouvelle) ...[
            ChoixPilules<int>(
              options: const [(2, '2 réponses'), (3, '3 réponses')],
              valeur: nb,
              onChoix: (n) {
                if (n != nb) _nombre(n);
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _modeles)
                  PiluleChoix(m.join(' / '), onTap: () => _modele(m)),
              ],
            ),
            const SizedBox(height: 12),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
              child: Text(
                '$nb réponses : fixé à la création, pour garder '
                'l\'historique juste.',
                style: doux,
              ),
            ),
          for (final (i, c) in _reponses.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ValueKey('reponse$i'),
                controller: c,
                maxLength: Question.longueurMaxReponse,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: i == 0
                      ? 'Meilleure réponse'
                      : i == nb - 1
                      ? 'Moins bonne réponse'
                      : 'Entre les deux',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 18, right: 12),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.couleurReponse(context, i, nb),
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(),
                ),
              ),
            ),
          titre('Notification'),
          CarteRonde(
            onTap: _choisitHeure,
            padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Heure',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: t.puce,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 20, color: t.texte),
                      const SizedBox(width: 8),
                      Text(
                        heureFr(_heure),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CarteRonde(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, contraintes) {
                    final taille = ((contraintes.maxWidth - 6 * 4) / 7).clamp(
                      28.0,
                      44.0,
                    );
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 7; i++)
                          JourRond(
                            key: ValueKey('jour$i'),
                            index: i,
                            taille: taille,
                            choisi: _jours & (1 << i) != 0,
                            onTap: () => setState(() => _jours ^= 1 << i),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (masque, libelle) in const [
                      (0x7F, 'Tous les jours'),
                      (0x1F, 'En semaine'),
                      (0x60, 'Le week-end'),
                    ])
                      PiluleChoix(
                        libelle,
                        choisie: _jours == masque,
                        onTap: () => setState(() => _jours = masque),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _erreur!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (q != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _pause,
              child: Text(q.active ? 'Mettre en pause' : 'Reprendre'),
            ),
            const SizedBox(height: 8),
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
