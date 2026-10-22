import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/question.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../widgets/boutons_reponse.dart';
import 'reglages_screen.dart';

/// Les questions d'un jour (aujourd'hui par défaut) avec leurs réponses :
/// pour rattraper une notification manquée ou changer d'avis. Les flèches
/// mènent aux jours passés.
class AujourdhuiScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const AujourdhuiScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<AujourdhuiScreen> createState() => _AujourdhuiScreenState();
}

class _AujourdhuiScreenState extends State<AujourdhuiScreen> {
  /// Décalage par rapport à aujourd'hui (0 = aujourd'hui, −1 = hier…).
  int _decalage = 0;
  List<Question> _questions = const [];
  Map<int, int> _reponses = const {};
  bool _charge = false;

  DateTime get _jour => ajouteJours(jourDe(widget.maintenant()), _decalage);

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
    final jour = _jour;
    final questions = await widget.base.questions();
    final reponses = await widget.base.reponsesDuJour(jour);
    if (!mounted || jour != _jour) return;
    setState(() {
      _questions = [
        for (final q in questions)
          if (q.active && q.revientLe(jour.weekday)) q,
      ];
      _reponses = reponses;
      _charge = true;
    });
  }

  void _va(int decalage) {
    setState(() => _decalage = decalage);
    _recharge();
  }

  Future<void> _choisit(Question q, int? choix) async {
    final jour = _jour;
    if (choix == null) {
      await widget.base.efface(q.id!, jour);
    } else {
      await widget.base.repond(q.id!, jour, choix);
      try {
        await Notifications.instance.retire(q.id!, jour);
      } catch (_) {}
    }
  }

  String get _titre => switch (_decalage) {
    0 => 'Aujourd\'hui',
    -1 => 'Hier',
    _ => majuscule(jourEtDate(_jour).split(' ').first),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faites = _questions.where((q) => _reponses.containsKey(q.id)).length;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              majuscule(jourEtDate(_jour)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _titre,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Jour d\'avant',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _va(_decalage - 1),
          ),
          IconButton(
            tooltip: 'Jour d\'après',
            icon: const Icon(Icons.chevron_right),
            onPressed: _decalage < 0 ? () => _va(_decalage + 1) : null,
          ),
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReglagesScreen(base: widget.base),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_charge
          ? const SizedBox.shrink()
          : _questions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Aucune question ce jour-là.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(
                  '$faites sur ${_questions.length} répondue'
                  '${faites > 1 ? 's' : ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final (i, q) in _questions.indexed) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                q.texte,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              heureFr(q.heure),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        BoutonsReponse(
                          question: q,
                          choix: _reponses[q.id],
                          onChoix: (c) => _choisit(q, c),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
