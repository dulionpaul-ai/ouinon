import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/bilan.dart';
import '../utils/jour.dart';
import 'question_screen.dart';

/// Le seul écran de l'appli : mes questions. Celles du jour portent leurs
/// réponses (pour répondre sans la notification) ; toucher une question
/// la modifie ; « + » en crée une. En haut, le bilan pour le coach.
class QuestionsScreen extends StatefulWidget {
  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const QuestionsScreen({super.key, this.maintenant = DateTime.now});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen>
    with WidgetsBindingObserver {
  Base? _base;
  Object? _erreur;
  List<Question> _questions = const [];
  Map<int, Reponses> _reponses = const {};
  bool _heurePrecise = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _demarre();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _base?.changements.removeListener(_relis);
    super.dispose();
  }

  Future<void> _demarre() async {
    try {
      final base = await Base.ouvrir();
      base.changements.addListener(_relis);
      _base = base;
      await _relis();
      await Notifications.instance.demandeAutorisation();
      await _reprogramme();
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  /// Au retour dans l'appli : les réponses données depuis les
  /// notifications, et l'heure précise peut-être autorisée entre-temps.
  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed && _base != null) {
      _relis();
      _reprogramme();
    }
  }

  Future<void> _reprogramme() async {
    final base = _base;
    if (base == null) return;
    try {
      await Notifications.instance.replanifie(base);
      final precise = await Notifications.instance.heurePrecise();
      if (mounted && precise != _heurePrecise) {
        setState(() => _heurePrecise = precise);
      }
    } catch (_) {}
  }

  Future<void> _relis() async {
    final base = _base;
    if (base == null) return;
    final questions = await base.questions();
    final reponses = await base.toutesLesReponses();
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _reponses = reponses;
    });
  }

  DateTime get _aujourdhui => jourDe(widget.maintenant());

  Future<void> _repond(Question q, int choix) async {
    final base = _base!;
    HapticFeedback.selectionClick();
    final actuelle = _reponses[q.id]?[cleJour(_aujourdhui)];
    // Toucher la réponse déjà choisie l'enlève.
    if (actuelle == choix) {
      await base.efface(q.id!, _aujourdhui);
    } else {
      await base.repond(q.id!, _aujourdhui, choix);
      await Notifications.instance.retire(q.id!, _aujourdhui);
    }
    await _reprogramme();
  }

  Future<void> _ouvre([Question? q]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionScreen(base: _base!, question: q),
      ),
    );
    await _reprogramme();
  }

  Future<void> _copieBilan() async {
    final texte = bilan(_questions, _reponses, _aujourdhui);
    await Clipboard.setData(ClipboardData(text: texte));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Bilan copié, colle-le au coach.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final aujourdhui = _aujourdhui;
    final actives = [
      for (final q in _questions)
        if (!q.enPause) q,
    ];
    final enPause = [
      for (final q in _questions)
        if (q.enPause) q,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ouinon'),
        actions: [
          if (_base != null)
            IconButton(
              tooltip: 'Bilan pour le coach',
              icon: const Icon(Icons.content_copy_rounded),
              onPressed: _copieBilan,
            ),
        ],
      ),
      floatingActionButton: _base == null
          ? null
          : FloatingActionButton(
              tooltip: 'Nouvelle question',
              onPressed: _ouvre,
              child: const Icon(Icons.add_rounded),
            ),
      body: _erreur != null
          ? Center(child: Text('Erreur : $_erreur'))
          : _base == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (!_heurePrecise)
                  ListTile(
                    leading: const Icon(
                      Icons.schedule_rounded,
                      color: AppTheme.orange,
                    ),
                    title: const Text(
                      'Les questions peuvent arriver en retard',
                    ),
                    subtitle: const Text(
                      'Toucher pour autoriser l\'heure précise',
                    ),
                    onTap: Notifications.instance.demandeHeurePrecise,
                  ),
                if (_questions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aucune question.\nTouche + pour en créer une.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.doux, fontSize: 16),
                    ),
                  ),
                for (final q in actives)
                  _Ligne(
                    question: q,
                    choix: q.revientLe(aujourdhui.weekday)
                        ? (reponse: _reponses[q.id]?[cleJour(aujourdhui)])
                        : null,
                    onTap: () => _ouvre(q),
                    onRepond: (c) => _repond(q, c),
                  ),
                if (enPause.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
                    child: Text(
                      'EN PAUSE',
                      style: TextStyle(
                        color: AppTheme.doux,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                for (final q in enPause)
                  _Ligne(question: q, onTap: () => _ouvre(q)),
              ],
            ),
    );
  }
}

/// Une question : son texte, son heure et ses jours ; si elle est posée
/// aujourd'hui, ses réponses (la moins bonne à gauche).
class _Ligne extends StatelessWidget {
  final Question question;

  /// Nul : pas posée aujourd'hui. Sinon, la réponse du jour (nulle : pas
  /// encore répondu).
  final ({int? reponse})? choix;
  final VoidCallback onTap;
  final ValueChanged<int>? onRepond;

  const _Ligne({
    required this.question,
    required this.onTap,
    this.choix,
    this.onRepond,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final pause = q.enPause;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.trait)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              q.texte,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: pause ? AppTheme.doux : AppTheme.texte,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pause
                  ? heureFr(q.heure)
                  : '${heureFr(q.heure)} · ${joursFr(q.jours)}',
              style: const TextStyle(color: AppTheme.doux, fontSize: 13),
            ),
            if (choix != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = q.nbReponses - 1; i >= 0; i--) ...[
                    Expanded(
                      child: _Bouton(
                        texte: q.reponses[i],
                        couleur: AppTheme.couleurReponse(i, q.nbReponses),
                        choisi: choix!.reponse == i,
                        onTap: () => onRepond?.call(i),
                      ),
                    ),
                    if (i > 0) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un bouton de réponse, translucide ; plein quand il est choisi.
class _Bouton extends StatelessWidget {
  final String texte;
  final Color couleur;
  final bool choisi;
  final VoidCallback onTap;

  const _Bouton({
    required this.texte,
    required this.couleur,
    required this.choisi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: choisi,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: choisi ? 0.32 : 0.06),
          border: Border.all(
            color: couleur.withValues(alpha: choisi ? 0.9 : 0.35),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          texte,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: choisi ? AppTheme.texte : couleur,
            fontWeight: choisi ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
