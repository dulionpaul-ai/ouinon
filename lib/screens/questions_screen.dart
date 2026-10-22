import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../utils/date_fr.dart';
import 'edition_question_screen.dart';

/// La liste des choses suivies : ajouter, ouvrir pour modifier, changer
/// l'ordre (appui long puis glisser).
class QuestionsScreen extends StatefulWidget {
  final Base base;

  const QuestionsScreen({super.key, required this.base});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List<Question> _questions = const [];

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
    if (mounted) setState(() => _questions = questions);
  }

  void _ouvre([Question? q]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionQuestionScreen(base: widget.base, question: q),
    ),
  );

  Future<void> _deplace(int de, int vers) async {
    final liste = [..._questions];
    liste.insert(vers, liste.removeAt(de));
    setState(() => _questions = liste);
    await widget.base.reordonne([for (final q in liste) q.id!]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes questions'), titleSpacing: 24),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvre,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: _questions.isEmpty
          ? Center(
              child: Text(
                'Aucune question pour l\'instant.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.only(bottom: 96),
              onReorderItem: _deplace,
              children: [
                for (final q in _questions)
                  ListTile(
                    key: ValueKey(q.id),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(
                      q.texte,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: q.active
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(
                      q.active
                          ? '${heureFr(q.heure)} · ${joursFr(q.jours)} · '
                                '${q.reponses.join(' / ')}'
                          : 'En pause',
                    ),
                    onTap: () => _ouvre(q),
                  ),
              ],
            ),
    );
  }
}
