import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/question.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../theme/app_theme.dart';
import '../widgets/boutons_reponse.dart';
import '../widgets/rond.dart';
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
    final t = Teintes.de(context);
    final faites = _questions.where((q) => _reponses.containsKey(q.id)).length;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 0, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Pastille(
                        dateCourte(_jour),
                        fond: t.carte,
                        hauteur: 36,
                        taille: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BoutonRond(
                    icone: Icons.chevron_left_rounded,
                    infobulle: 'Jour d\'avant',
                    onPressed: () => _va(_decalage - 1),
                  ),
                  const SizedBox(width: 6),
                  BoutonRond(
                    icone: Icons.chevron_right_rounded,
                    infobulle: 'Jour d\'après',
                    onPressed: _decalage < 0 ? () => _va(_decalage + 1) : null,
                  ),
                  const SizedBox(width: 6),
                  BoutonRond(
                    icone: Icons.tune_rounded,
                    infobulle: 'Réglages',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReglagesScreen(base: widget.base),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GrandTitre(_titre),
                  if (_questions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      container: true,
                      label:
                          '$faites sur ${_questions.length} répondue'
                          '${faites > 1 ? 's' : ''}',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          for (var i = 0; i < _questions.length; i++)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < faites ? t.texte : t.trait,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            '$faites sur ${_questions.length}',
                            style: TextStyle(
                              color: t.doux,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_charge && _questions.isEmpty)
              CarteRonde(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Aucune question ce jour-là.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.doux, fontSize: 16),
                ),
              ),
            for (final q in _questions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarteRonde(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.texte,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Pastille(heureFr(q.heure)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      BoutonsReponse(
                        question: q,
                        choix: _reponses[q.id],
                        onChoix: (c) => _choisit(q, c),
                      ),
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
