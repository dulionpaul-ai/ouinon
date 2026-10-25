import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../utils/date_fr.dart';
import '../theme/app_theme.dart';
import '../widgets/rond.dart';
import 'edition_question_screen.dart';

/// La liste des questions, dans l'ordre de la journée : ajouter, ouvrir
/// pour modifier. Depuis les Réglages (revue du 25/10/2026 : trois
/// onglets seulement).
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

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes questions'),
        actions: [
          IconButton(
            tooltip: 'Ajouter une question',
            onPressed: _ouvre,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
              child: Text(
                _questions.isEmpty
                    ? 'Aucune question pour l\'instant.'
                    : 'Dans l\'ordre de la journée. Touche pour modifier.',
                style: TextStyle(color: t.doux),
              ),
            ),
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
                                // Dans l'ordre des boutons : la meilleure à droite.
                                for (final (i, r)
                                    in q.reponses.indexed.toList().reversed)
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
            CarteRonde(
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
          ],
        ),
      ),
    );
  }
}
