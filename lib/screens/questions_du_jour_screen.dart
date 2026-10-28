import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../widgets/boutons_reponse.dart';
import '../widgets/vivant.dart';
import 'edition_question_screen.dart';
import 'fiche_question_screen.dart';
import 'reglages_screen.dart';

/// Onglet 3, les questions du jour (maquette validée par Paul le
/// 28/10/2026) : celles qui sonnent aujourd'hui, par heure ; celles dont
/// l'heure n'est pas encore venue sont plus pâles, mais on peut déjà y
/// répondre. La moins bonne réponse à gauche, la meilleure à droite. Une
/// réponse donnée se verrouille avec une onde ; « Changer » rouvre les
/// boutons. Toucher la question elle-même ouvre sa fiche (la modifier,
/// ses stats). Le « + » crée une question. L'anneau en haut se remplit.
class QuestionsDuJourScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const QuestionsDuJourScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<QuestionsDuJourScreen> createState() => _QuestionsDuJourScreenState();
}

class _QuestionsDuJourScreenState extends State<QuestionsDuJourScreen> {
  List<Question> _questions = const [];
  Map<int, int> _reponses = const {};

  /// Questions dont on a rouvert les boutons après avoir répondu.
  final _rouvertes = <int>{};

  DateTime get _jour => jourDe(widget.maintenant());

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
    if (!mounted) return;
    setState(() {
      _questions = [
        for (final q in questions)
          if (q.active && q.revientLe(jour.weekday)) q,
      ]..sort((a, b) => a.heure.compareTo(b.heure));
      _reponses = reponses;
    });
  }

  Future<void> _choisit(Question q, int? choix) async {
    final jour = _jour;
    final avant = _reponses[q.id];
    // Tout de suite à l'écran, sans attendre la base : l'animation part
    // dès le toucher.
    setState(() {
      _rouvertes.remove(q.id);
      _reponses = {..._reponses}..remove(q.id);
      if (choix != null) _reponses[q.id!] = choix;
    });
    if (choix == null) {
      await widget.base.efface(q.id!, jour);
    } else {
      await widget.base.repond(q.id!, jour, choix);
      try {
        await Notifications.instance.retire(q.id!, jour);
      } catch (_) {}
    }
    if (!mounted) return;
    annonce(
      context,
      choix == null
          ? '${q.texte} : réponse effacée'
          : '${q.texte} ${q.reponses[choix]}',
      annuler: () => avant == null
          ? widget.base.efface(q.id!, jour)
          : widget.base.repond(q.id!, jour, avant),
    );
  }

  void _nouvelle() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => EditionQuestionScreen(base: widget.base)),
  );

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final now = widget.maintenant();
    final minute = now.hour * 60 + now.minute;
    final repondues = _questions
        .where((q) => _reponses.containsKey(q.id))
        .length;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: EnTete(
                date: _questions.isEmpty
                    ? dateCourte(_jour)
                    : '${dateCourte(_jour)} · $repondues sur '
                          '${_questions.length}',
                titre: 'Questions',
                actions: [
                  if (_questions.isNotEmpty)
                    _Anneau(
                      part: repondues / _questions.length,
                      aide: '$repondues réponses sur ${_questions.length}',
                    ),
                  BoutonRond(
                    icone: Icons.tune_rounded,
                    aide: 'Réglages et stats',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReglagesScreen(base: widget.base),
                      ),
                    ),
                  ),
                  BoutonRond(
                    key: const ValueKey('nouvelle-question'),
                    icone: Icons.add_rounded,
                    aide: 'Nouvelle question',
                    fort: true,
                    onTap: _nouvelle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _questions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Pas de question aujourd\'hui.',
                        style: TextStyle(color: t.doux, fontSize: 15),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      children: [
                        for (final q in _questions)
                          Apparition(
                            key: ValueKey('question-${q.id}'),
                            child: _LigneQuestion(
                              question: q,
                              choix: _reponses[q.id],
                              ouverte:
                                  !_reponses.containsKey(q.id) ||
                                  _rouvertes.contains(q.id),
                              // Pas encore l'heure : plus pâle.
                              aVenir: q.heure > minute,
                              onChoix: (c) => _choisit(q, c),
                              onRouvre: () =>
                                  setState(() => _rouvertes.add(q.id!)),
                              onFiche: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FicheQuestionScreen(
                                    base: widget.base,
                                    question: q,
                                    maintenant: widget.maintenant,
                                  ),
                                ),
                              ),
                            ),
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

class _LigneQuestion extends StatelessWidget {
  final Question question;
  final int? choix;
  final bool ouverte;
  final bool aVenir;
  final ValueChanged<int?> onChoix;
  final VoidCallback onRouvre;
  final VoidCallback onFiche;

  const _LigneQuestion({
    required this.question,
    required this.choix,
    required this.ouverte,
    required this.aVenir,
    required this.onChoix,
    required this.onRouvre,
    required this.onFiche,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final q = question;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: aVenir && choix == null ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.puce)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toucher la question (pas les réponses) : sa fiche, pour la
            // modifier et voir ses stats.
            GestureDetector(
              key: ValueKey('fiche-${q.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onFiche,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      q.texte,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    aVenir ? 'à ${_hhmm(q.heure)}' : _hhmm(q.heure),
                    style: TextStyle(
                      fontFamily: AppTheme.policeMono,
                      fontSize: 12,
                      color: t.doux,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Reponse(
              question: q,
              choix: choix,
              verrouillee: !ouverte && choix != null,
              onChoix: onChoix,
              onRouvre: onRouvre,
            ),
          ],
        ),
      ),
    );
  }
}

/// Les réponses d'une question, en un seul mouvement continu (Paul,
/// 28/10/2026, « pas hyper fluide ») : au toucher, la réponse choisie
/// s'allume tout de suite ; un court instant après, les boutons
/// s'effacent pendant que la pastille arrive en glissant, puis l'onde
/// part. La hauteur ne change jamais (rien ne saute). « Changer » refait
/// le chemin à l'envers, plus vite.
class _Reponse extends StatefulWidget {
  final Question question;
  final int? choix;
  final bool verrouillee;
  final ValueChanged<int?> onChoix;
  final VoidCallback onRouvre;

  const _Reponse({
    required this.question,
    required this.choix,
    required this.verrouillee,
    required this.onChoix,
    required this.onRouvre,
  });

  @override
  State<_Reponse> createState() => _ReponseState();
}

class _ReponseState extends State<_Reponse>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
    value: widget.verrouillee ? 1 : 0,
  );

  @override
  void didUpdateWidget(_Reponse ancien) {
    super.didUpdateWidget(ancien);
    if (widget.verrouillee && !ancien.verrouillee) {
      _anim.forward(from: 0);
    } else if (!widget.verrouillee && ancien.verrouillee) {
      _anim.animateBack(0, duration: const Duration(milliseconds: 280));
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  static double _part(
    double v,
    double debut,
    double fin, [
    Curve c = Curves.linear,
  ]) => c.transform(((v - debut) / (fin - debut)).clamp(0.0, 1.0));

  static const _ecart = 6.0;
  static const _style = TextStyle(
    fontFamily: AppTheme.policeTexte,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final q = widget.question;
    final nb = q.nbReponses;
    return SizedBox(
      height: 46,
      child: LayoutBuilder(
        builder: (context, contraintes) => AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final v = _anim.value;
            final choix = widget.choix;
            final boutons = BoutonsReponse(
              question: q,
              choix: choix,
              onChoix: widget.onChoix,
            );
            if (v == 0 || choix == null) return boutons;
            // Les autres réponses s'effacent, puis la choisie se
            // transforme en pastille en glissant à gauche ; « Changer »
            // apparaît, l'onde part.
            final efface = _part(v, 0.08, 0.32, Curves.easeOut);
            final morph = _part(v, 0.22, 0.68, Curves.easeInOutCubic);
            final changer = _part(v, 0.5, 0.8, Curves.easeOut);
            final onde = _part(v, 0.62, 1, Curves.easeOut);
            final largeur = contraintes.maxWidth;
            final bouton = (largeur - _ecart * (nb - 1)) / nb;
            // De gauche à droite : la moins bonne d'abord.
            final xBouton = (nb - 1 - choix) * (bouton + _ecart);
            final texte = q.reponses[choix];
            final mesure = TextPainter(
              text: TextSpan(text: texte, style: _style),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final pastille = (mesure.width + 30).clamp(0.0, bouton);
            double entre(double a, double b) => a + (b - a) * morph;
            final c = AppTheme.couleurReponse(context, choix, nb);
            final x = entre(xBouton, 0);
            final w = entre(bouton, pastille);
            final h = entre(46, 34);
            final rayon = entre(t.rayon, 17);
            final forme = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(rayon),
              side: BorderSide(color: c),
            );
            return Semantics(
              button: true,
              label: '$texte, changer',
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('changer-${q.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.verrouillee ? widget.onRouvre : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (efface < 1)
                      Opacity(
                        opacity: 1 - efface,
                        child: IgnorePointer(child: boutons),
                      ),
                    // La réponse choisie, pleine (rien ne transparaît).
                    Positioned(
                      left: x,
                      top: (46 - h) / 2,
                      width: w,
                      height: h,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: Color.alphaBlend(
                                  c.withValues(alpha: 0.22),
                                  t.fond,
                                ),
                                shape: forme,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    texte,
                                    maxLines: 1,
                                    style: _style.copyWith(color: c),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (onde > 0 && onde < 1)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Transform.scale(
                                  scaleX: 1 + 0.5 * onde,
                                  scaleY: 1 + 1.1 * onde,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          rayon,
                                        ),
                                        side: BorderSide(
                                          color: c.withValues(alpha: 1 - onde),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (changer > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Opacity(
                          opacity: changer,
                          child: Center(
                            child: Text(
                              'Changer',
                              style: TextStyle(color: t.doux, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// « 09:00 », en chiffres de tableau de bord.
String _hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// L'anneau des réponses du jour : il se remplit à chaque réponse.
class _Anneau extends StatelessWidget {
  final double part;
  final String aide;

  const _Anneau({required this.part, required this.aide});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      label: aide,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: part),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          size: const Size(44, 44),
          painter: _PeintAnneau(part: v, fond: t.trait, couleur: t.accent),
        ),
      ),
    );
  }
}

class _PeintAnneau extends CustomPainter {
  final double part;
  final Color fond;
  final Color couleur;

  _PeintAnneau({required this.part, required this.fond, required this.couleur});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(r, 0, 2 * math.pi, false, trait..color = fond);
    if (part > 0) {
      canvas.drawArc(
        r,
        -math.pi / 2,
        2 * math.pi * part.clamp(0.0, 1.0),
        false,
        trait..color = couleur,
      );
    }
  }

  @override
  bool shouldRepaint(_PeintAnneau old) =>
      old.part != part || old.couleur != couleur;
}
