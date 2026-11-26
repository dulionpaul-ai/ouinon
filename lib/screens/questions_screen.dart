import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/base.dart';
import '../data/apparence_distante.dart';
import '../data/notifications.dart';
import '../models/apparence.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/bilan.dart';
import '../utils/frequence.dart';
import '../utils/jour.dart';
import 'question_screen.dart';

/// L'écran d'accueil, au style HUD (26/11/2026) : la phrase « Je deviens
/// quelqu'un qui… », la semaine, puis mes habitudes (heure, fréquence, 7
/// derniers jours). On ne répond plus ici : seulement dans les
/// notifications. Toucher une habitude la modifie ; le bouton du bas en
/// crée une ; celui du haut copie le bilan pour le coach. L'apparence se
/// règle sans APK (`ApparenceDistante`).
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApparenceDistante.courante.addListener(_redessine);
    _demarre();
  }

  void _redessine() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApparenceDistante.courante.removeListener(_redessine);
    _base?.changements.removeListener(_relis);
    super.dispose();
  }

  Future<void> _demarre() async {
    try {
      final base = await Base.ouvrir();
      base.changements.addListener(_relis);
      _base = base;
      await ApparenceDistante.charge(base);
      await _relis();
      await Notifications.instance.demandeAutorisation();
      await _reprogramme();
      await _metsAJourApparence();
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
      _metsAJourApparence();
    }
  }

  /// Relit le fichier public de réglages ; s'il a changé, les
  /// notifications sont refaites à la nouvelle apparence.
  Future<void> _metsAJourApparence() async {
    final base = _base;
    if (base == null) return;
    final avant = ApparenceDistante.courante.value;
    await ApparenceDistante.telecharge(base);
    if (!identical(avant, ApparenceDistante.courante.value)) {
      await _reprogramme();
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

  Future<void> _ouvre([Question? q]) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionScreen(
          base: _base!,
          question: q,
          maintenant: widget.maintenant,
        ),
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
    final a = Apparence.actuelle;
    final champ = TextEditingController(text: _phrase);
    final phrase = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${a.t('phrase')}…'),
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
    final a = Apparence.actuelle;
    final aujourdhui = _aujourdhui;
    Reponses r(Question q) => _reponses[q.id] ?? const {};
    final actives = [
      for (final q in _questions)
        if (!q.enPause) q,
    ];
    final enPause = [
      for (final q in _questions)
        if (q.enPause) q,
    ];
    final s = semaine(_questions, _reponses, aujourdhui);
    var numero = 0;
    return Scaffold(
      backgroundColor: a.fond,
      body: CustomPaint(
        painter: a.grille ? Quadrillage(a.trait) : null,
        child: SafeArea(
          child: _erreur != null
              ? Center(child: Text('Erreur : $_erreur'))
              : _base == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.t('titre'),
                                  style: AppTheme.etiquette(
                                    couleur: a.meilleure,
                                    taille: 13,
                                  ).copyWith(letterSpacing: 3),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Bilan pour le coach',
                                icon: Icon(
                                  Icons.content_copy_rounded,
                                  color: a.doux,
                                  size: 20,
                                ),
                                onPressed: _copieBilan,
                              ),
                            ],
                          ),
                          if (a.voirPhrase)
                            InkWell(
                              onTap: _changePhrase,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  _phrase.isEmpty
                                      ? '${a.t('phrase')}…'
                                      : '${a.t('phrase')} $_phrase',
                                  style: TextStyle(
                                    fontSize: a.taillePhrase,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: _phrase.isEmpty ? a.doux : a.texte,
                                  ),
                                ),
                              ),
                            ),
                          if (a.voirSemaine && s.total > 0)
                            _Semaine(
                              numero: numeroSemaine(aujourdhui),
                              oui: s.oui,
                              total: s.total,
                            ),
                          if (!_heurePrecise)
                            InkWell(
                              onTap: Notifications.instance.demandeHeurePrecise,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  '! LES NOTIFICATIONS PEUVENT ARRIVER EN '
                                  'RETARD : TOUCHER POUR AUTORISER L\'HEURE '
                                  'PRÉCISE',
                                  style: AppTheme.etiquette(
                                    couleur: a.moinsBonne,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (_questions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                a.t('vide'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: a.doux, fontSize: 16),
                              ),
                            ),
                          for (final q in [...actives, ...enPause])
                            _Ligne(
                              key: ValueKey('q${q.id}'),
                              numero: ++numero,
                              question: q,
                              detail: [
                                heureMono(q.heure),
                                frequenceFr(q),
                                if (revientDans(q, aujourdhui, r(q))
                                    case final n?)
                                  n == 1 ? 'demain' : 'dans $n j',
                              ].join(' · ').toUpperCase(),
                              jours: a.voirBarres && !q.enPause
                                  ? septJours(q, aujourdhui, r(q))
                                  : null,
                              onTap: () => _ouvre(q),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: BoutonHud(
                        texte: a.t('nouvelle'),
                        onTap: () => _ouvre(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// « SEM 48 ───── 17/26 ».
class _Semaine extends StatelessWidget {
  final int numero;
  final int oui;
  final int total;

  const _Semaine({
    required this.numero,
    required this.oui,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final a = Apparence.actuelle;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text('SEM $numero', style: AppTheme.etiquette()),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRect(
              child: LinearProgressIndicator(
                value: oui / total,
                minHeight: 2,
                color: a.meilleure,
                backgroundColor: a.trait,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$oui/$total',
            style: AppTheme.etiquette(couleur: a.meilleure, taille: 13),
          ),
        ],
      ),
    );
  }
}

/// Une habitude : son numéro, son texte, l'heure et la fréquence, et ses
/// 7 derniers jours en barres.
class _Ligne extends StatelessWidget {
  final int numero;
  final Question question;
  final String detail;
  final List<int?>? jours;
  final VoidCallback onTap;

  const _Ligne({
    super.key,
    required this.numero,
    required this.question,
    required this.detail,
    required this.onTap,
    this.jours,
  });

  @override
  Widget build(BuildContext context) {
    final a = Apparence.actuelle;
    final q = question;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: a.trait)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                numero.toString().padLeft(2, '0'),
                style: AppTheme.etiquette(
                  couleur: a.doux.withValues(alpha: 0.6),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.texte,
                    style: TextStyle(
                      fontSize: a.tailleLigne,
                      fontWeight: FontWeight.w600,
                      color: q.enPause ? a.doux : a.texte,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(detail, style: AppTheme.etiquette(taille: 10.5)),
                ],
              ),
            ),
            if (jours != null) ...[
              const SizedBox(width: 10),
              for (final j in jours!)
                Container(
                  width: 4,
                  height: 16,
                  margin: const EdgeInsets.only(left: 2),
                  color: switch (j) {
                    null => a.trait.withValues(alpha: 0.5),
                    -1 => a.trait,
                    _ => AppTheme.couleurReponse(j, q.nbReponses),
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le grand bouton du HUD : bordure d'accent, fond translucide ; plein
/// pour l'action principale.
class BoutonHud extends StatelessWidget {
  final String texte;
  final VoidCallback? onTap;
  final bool plein;

  const BoutonHud({
    super.key,
    required this.texte,
    required this.onTap,
    this.plein = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = Apparence.actuelle;
    final actif = onTap != null;
    return Semantics(
      button: true,
      enabled: actif,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: plein
                ? a.meilleure.withValues(alpha: actif ? 1 : 0.25)
                : a.meilleure.withValues(alpha: 0.10),
            border: Border.all(
              color: a.meilleure.withValues(alpha: actif ? 1 : 0.3),
            ),
          ),
          child: Text(
            texte,
            style: AppTheme.etiquette(
              couleur: plein ? a.fond : a.meilleure,
              taille: 14,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 3),
          ),
        ),
      ),
    );
  }
}

/// Le quadrillage fin du fond.
class Quadrillage extends CustomPainter {
  final Color couleur;

  const Quadrillage(this.couleur);

  @override
  void paint(Canvas canvas, Size size) {
    final trait = Paint()
      ..color = couleur.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), trait);
    }
    for (var y = 0.0; y <= size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), trait);
    }
  }

  @override
  bool shouldRepaint(Quadrillage ancien) => ancien.couleur != couleur;
}
