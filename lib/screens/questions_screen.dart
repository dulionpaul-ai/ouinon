import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../utils/date_fr.dart';
import '../theme/app_theme.dart';
import '../widgets/rond.dart';
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
    final t = Teintes.de(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ReorderableListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
          header: Padding(
            padding: const EdgeInsets.fromLTRB(6, 22, 6, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: GrandTitre('Questions')),
                    const SizedBox(width: 12),
                    BoutonPlus(
                      infobulle: 'Ajouter une question',
                      onPressed: _ouvre,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _questions.isEmpty
                      ? 'Aucune question pour l\'instant.'
                      : 'Touche pour modifier, appui long pour déplacer.',
                  style: TextStyle(color: t.doux),
                ),
              ],
            ),
          ),
          footer: CarteRonde(
            onTap: _ouvre,
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: t.texte),
                const SizedBox(width: 8),
                const Text(
                  'Ajouter une question',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          onReorderItem: _deplace,
          children: [
            for (final q in _questions)
              Padding(
                key: ValueKey(q.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: CarteRonde(
                  onTap: () => _ouvre(q),
                  padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.texte,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: q.active ? t.texte : t.doux,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              q.active
                                  ? '${heureFr(q.heure)} · ${joursFr(q.jours)}'
                                  : 'En pause',
                              style: TextStyle(color: t.doux),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final (i, r) in q.reponses.indexed)
                                  Pastille(
                                    r,
                                    fond: q.active
                                        ? AppTheme.couleurReponse(
                                            context,
                                            i,
                                            q.nbReponses,
                                          )
                                        : t.puce,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: t.doux),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
