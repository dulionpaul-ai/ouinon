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

/// Les questions d'un jour (aujourd'hui au départ) avec leurs réponses :
/// pour rattraper une notification manquée ou changer d'avis. On passe
/// d'un jour à l'autre en glissant le doigt (vers la droite : la veille)
/// ou avec les flèches, sans dépasser aujourd'hui.
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
  /// Page 0 = aujourd'hui, page 1 = hier… (dix ans en arrière au plus).
  static const _joursMax = 3650;

  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _va(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pages,
      // Inversé : glisser vers la droite montre la veille, et on ne peut
      // pas aller après aujourd'hui (page 0).
      reverse: true,
      itemCount: _joursMax,
      itemBuilder: (context, page) => _PageJour(
        key: ValueKey(page),
        base: widget.base,
        maintenant: widget.maintenant,
        decalage: -page,
        onAvant: page < _joursMax - 1 ? () => _va(page + 1) : null,
        onApres: page > 0 ? () => _va(page - 1) : null,
      ),
    );
  }
}

class _PageJour extends StatefulWidget {
  final Base base;
  final DateTime Function() maintenant;

  /// Décalage par rapport à aujourd'hui (0 = aujourd'hui, −1 = hier…).
  final int decalage;
  final VoidCallback? onAvant;
  final VoidCallback? onApres;

  const _PageJour({
    super.key,
    required this.base,
    required this.maintenant,
    required this.decalage,
    required this.onAvant,
    required this.onApres,
  });

  @override
  State<_PageJour> createState() => _PageJourState();
}

class _PageJourState extends State<_PageJour> {
  int get _decalage => widget.decalage;
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
                    onPressed: widget.onAvant,
                  ),
                  const SizedBox(width: 6),
                  BoutonRond(
                    icone: Icons.chevron_right_rounded,
                    infobulle: 'Jour d\'après',
                    onPressed: widget.onApres,
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
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 14),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: CarteRonde(
                  padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
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
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Pastille(heureFr(q.heure)),
                        ],
                      ),
                      const SizedBox(height: 10),
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
