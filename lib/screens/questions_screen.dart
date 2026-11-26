import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/bilan.dart';
import '../utils/frequence.dart';
import '../utils/jour.dart';
import 'question_screen.dart';

/// Le seul écran de l'appli (maquette validée le 26/11/2026) : en haut, la
/// phrase « Je deviens quelqu'un qui… » et le compte de la semaine ; puis
/// les questions du jour, avec 7 points (les 7 derniers jours) et leurs
/// réponses ; repliées en bas, celles qui ne sont pas posées aujourd'hui
/// et celles en pause. Toucher une question la modifie ; « + » en crée
/// une ; le bouton du haut copie le bilan pour le coach.
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
  String _phrase = '';
  bool _heurePrecise = true;

  /// Questions répondues aujourd'hui dont on a rouvert les boutons.
  final _rouvertes = <int>{};
  bool _voirAutres = false;
  bool _voirPause = false;

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
    final phrase = await base.phrase();
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _reponses = reponses;
      _phrase = phrase;
    });
  }

  DateTime get _aujourdhui => jourDe(widget.maintenant());

  Future<void> _repond(Question q, int choix) async {
    final base = _base!;
    HapticFeedback.selectionClick();
    final actuelle = _reponses[q.id]?[cleJour(_aujourdhui)];
    setState(() => _rouvertes.remove(q.id));
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

  /// Écrire ou changer la phrase du haut.
  Future<void> _changePhrase() async {
    final champ = TextEditingController(text: _phrase);
    final phrase = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Je deviens quelqu\'un qui…'),
        content: TextField(
          key: const ValueKey('phrase'),
          controller: champ,
          autofocus: true,
          maxLength: 100,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'dort, bouge et tient parole.',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, champ.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (phrase == null) return;
    HapticFeedback.lightImpact();
    await _base!.changePhrase(phrase);
  }

  @override
  Widget build(BuildContext context) {
    final aujourdhui = _aujourdhui;
    Reponses r(Question q) => _reponses[q.id] ?? const {};
    final duJour = [
      for (final q in _questions)
        if (poseeLe(q, aujourdhui, r(q))) q,
    ];
    final autres = [
      for (final q in _questions)
        if (!q.enPause && !poseeLe(q, aujourdhui, r(q))) q,
    ];
    final enPause = [
      for (final q in _questions)
        if (q.enPause) q,
    ];
    final repondues = duJour
        .where((q) => r(q).containsKey(cleJour(aujourdhui)))
        .length;
    final s = semaine(_questions, _reponses, aujourdhui);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          dateLongue(aujourdhui),
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.doux,
            fontWeight: FontWeight.w500,
          ),
        ),
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
                _Phrase(phrase: _phrase, onTap: _changePhrase),
                if (s.total > 0) _Semaine(oui: s.oui, total: s.total),
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
                if (duJour.isNotEmpty)
                  _Section('Aujourd\'hui · $repondues sur ${duJour.length}'),
                for (final q in duJour)
                  _Ligne(
                    key: ValueKey('q${q.id}'),
                    question: q,
                    points: _points(q, aujourdhui),
                    reponse: r(q)[cleJour(aujourdhui)],
                    ouverte:
                        !r(q).containsKey(cleJour(aujourdhui)) ||
                        _rouvertes.contains(q.id),
                    onTap: () => _ouvre(q),
                    onRouvre: () => setState(() => _rouvertes.add(q.id!)),
                    onRepond: (c) => _repond(q, c),
                  ),
                if (autres.isNotEmpty || enPause.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: Wrap(
                      children: [
                        if (autres.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setState(() => _voirAutres = !_voirAutres),
                            child: Text(
                              'Pas aujourd\'hui (${autres.length})',
                              style: TextStyle(
                                color: _voirAutres
                                    ? AppTheme.texte
                                    : AppTheme.doux,
                              ),
                            ),
                          ),
                        if (enPause.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setState(() => _voirPause = !_voirPause),
                            child: Text(
                              'En pause (${enPause.length})',
                              style: TextStyle(
                                color: _voirPause
                                    ? AppTheme.texte
                                    : AppTheme.doux,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_voirAutres)
                  for (final q in autres)
                    _Ligne(
                      key: ValueKey('q${q.id}'),
                      question: q,
                      dans: revientDans(q, aujourdhui, r(q)),
                      onTap: () => _ouvre(q),
                    ),
                if (_voirPause)
                  for (final q in enPause)
                    _Ligne(
                      key: ValueKey('q${q.id}'),
                      question: q,
                      onTap: () => _ouvre(q),
                    ),
              ],
            ),
    );
  }

  /// Les 7 derniers jours (aujourd'hui en dernier) : la couleur de la
  /// réponse ; posée sans réponse : un rond vide ; pas posée : rien.
  List<_Point> _points(Question q, DateTime aujourdhui) {
    final r = _reponses[q.id] ?? const {};
    return [
      for (var n = 6; n >= 0; n--)
        () {
          final j = ajouteJours(aujourdhui, -n);
          if (!poseeLe(q, j, r)) return _Point.rien;
          final c = r[cleJour(j)];
          if (c == null) return _Point.vide;
          return c == 0
              ? _Point.vert
              : c == q.nbReponses - 1
              ? _Point.orange
              : _Point.gris;
        }(),
    ];
  }
}

enum _Point { rien, vide, vert, gris, orange }

/// La phrase du haut, à toucher pour l'écrire ou la changer.
class _Phrase extends StatelessWidget {
  final String phrase;
  final VoidCallback onTap;

  const _Phrase({required this.phrase, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        phrase.isEmpty
            ? 'Je deviens quelqu\'un qui…'
            : 'Je deviens quelqu\'un qui $phrase',
        style: TextStyle(
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: phrase.isEmpty ? AppTheme.doux : AppTheme.texte,
        ),
      ),
    ),
  );
}

/// « Cette semaine · 17 oui sur 26 », et sa barre.
class _Semaine extends StatelessWidget {
  final int oui;
  final int total;

  const _Semaine({required this.oui, required this.total});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Cette semaine',
                style: TextStyle(color: AppTheme.doux, fontSize: 14),
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$oui oui',
                    style: const TextStyle(
                      color: AppTheme.vert,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' sur $total',
                    style: const TextStyle(color: AppTheme.doux),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : oui / total,
            minHeight: 6,
            color: AppTheme.vert,
            backgroundColor: AppTheme.trait,
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String texte;

  const _Section(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      texte.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.doux,
        fontSize: 12,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Une question. Posée aujourd'hui : ses 7 points et son heure, puis ses
/// réponses (la moins bonne à gauche) ; répondue, sa réponse en pastille
/// (la toucher rouvre les boutons). Sinon : sa fréquence.
class _Ligne extends StatelessWidget {
  final Question question;
  final List<_Point>? points;

  /// La réponse du jour (nulle : pas encore répondu).
  final int? reponse;
  final bool ouverte;

  /// Pour une tâche pas posée aujourd'hui : dans combien de jours.
  final int? dans;
  final VoidCallback onTap;
  final VoidCallback? onRouvre;
  final ValueChanged<int>? onRepond;

  const _Ligne({
    super.key,
    required this.question,
    required this.onTap,
    this.points,
    this.reponse,
    this.ouverte = false,
    this.dans,
    this.onRouvre,
    this.onRepond,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final duJour = points != null;
    final c = reponse;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.trait)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.texte,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: q.enPause ? AppTheme.doux : AppTheme.texte,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (duJour)
                        Row(
                          children: [
                            for (final p in points!) _Rond(p),
                            const SizedBox(width: 6),
                            Text(
                              heureFr(q.heure),
                              style: const TextStyle(
                                color: AppTheme.doux,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          [
                            heureFr(q.heure),
                            frequenceFr(q),
                            if (dans != null)
                              dans == 1 ? 'demain' : 'dans $dans jours',
                          ].join(' · '),
                          style: const TextStyle(
                            color: AppTheme.doux,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (duJour && c != null && !ouverte) ...[
                  const SizedBox(width: 10),
                  _Bouton(
                    texte: q.reponses[c],
                    couleur: AppTheme.couleurReponse(c, q.nbReponses),
                    choisi: true,
                    compact: true,
                    onTap: onRouvre ?? () {},
                  ),
                ],
              ],
            ),
            if (duJour && ouverte) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = q.nbReponses - 1; i >= 0; i--) ...[
                    Expanded(
                      child: _Bouton(
                        texte: q.reponses[i],
                        couleur: AppTheme.couleurReponse(i, q.nbReponses),
                        choisi: c == i,
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

/// Un des 7 points.
class _Rond extends StatelessWidget {
  final _Point point;

  const _Rond(this.point);

  @override
  Widget build(BuildContext context) {
    final couleur = switch (point) {
      _Point.vert => AppTheme.vert,
      _Point.orange => AppTheme.orange,
      _Point.gris => AppTheme.gris,
      _ => null,
    };
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: couleur ?? (point == _Point.rien ? AppTheme.trait : null),
        border: point == _Point.vide
            ? Border.all(color: AppTheme.doux.withValues(alpha: 0.6))
            : null,
      ),
    );
  }
}

/// Un bouton de réponse, translucide ; plein quand il est choisi.
class _Bouton extends StatelessWidget {
  final String texte;
  final Color couleur;
  final bool choisi;
  final bool compact;
  final VoidCallback onTap;

  const _Bouton({
    required this.texte,
    required this.couleur,
    required this.choisi,
    required this.onTap,
    this.compact = false,
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
        height: compact ? 34 : 40,
        padding: compact ? const EdgeInsets.symmetric(horizontal: 14) : null,
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
