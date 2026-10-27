import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/question.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../widgets/boutons_reponse.dart';
import '../widgets/etape.dart';
import 'edition_tache_screen.dart';

/// L'accueil (refait avec Paul le 26/10/2026) : la journée tourne seule
/// avec les notifications, et le soir on ouvre l'appli une fois.
/// « Bonsoir. », l'anneau de ce qui a été fait, la journée en lignes, les
/// questions sans réponse, puis « Préparer demain ». Ouverte dans la
/// journée, elle montre en plus ce qui est en cours.
class BilanScreen extends StatefulWidget {
  final Base base;
  final VoidCallback onPreparer;
  final VoidCallback onSuivi;
  final VoidCallback onReglages;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const BilanScreen({
    super.key,
    required this.base,
    required this.onPreparer,
    required this.onSuivi,
    required this.onReglages,
    this.maintenant = DateTime.now,
  });

  @override
  State<BilanScreen> createState() => _BilanScreenState();
}

class _BilanScreenState extends State<BilanScreen> {
  List<Question> _questions = const [];
  Map<int, int> _reponses = const {};
  List<Tache> _taches = const [];
  bool _charge = false;

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
    final taches = await widget.base.tachesDu(jour);
    if (!mounted) return;
    setState(() {
      _questions = [
        for (final q in questions)
          if (q.active && q.revientLe(jour.weekday)) q,
      ];
      _reponses = reponses;
      _taches = [...taches]..sort((a, b) => a.debut.compareTo(b.debut));
      _charge = true;
    });
  }

  Future<void> _choisit(Question q, int? choix) async {
    if (choix == null) {
      await widget.base.efface(q.id!, _jour);
      return;
    }
    await widget.base.repond(q.id!, _jour, choix);
    try {
      await Notifications.instance.retire(q.id!, _jour);
    } catch (_) {}
  }

  Future<void> _repond(Tache tache, int? etat) async {
    await widget.base.repondTache(tache.id!, etat);
    if (etat != null) {
      try {
        await Notifications.instance.retireTache(tache.id!);
      } catch (_) {}
    }
  }

  /// Toucher une chose de la journée : Pas fait · Reporter · Fait, ou la
  /// modifier.
  Future<void> _actions(Tache tache) async {
    final t = Teintes.de(context);
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tache.texte, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _TroisBoutons(
                onPasFait: () => Navigator.pop(context, 'pasfait'),
                onReporter: () => Navigator.pop(context, 'reporter'),
                onFait: () => Navigator.pop(context, 'fait'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context, 'modifier'),
                style: TextButton.styleFrom(foregroundColor: t.doux),
                child: const Text('Modifier'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (choix) {
      case 'fait':
        await _repond(tache, Tache.fait);
      case 'pasfait':
        await _repond(tache, Tache.pasFait);
      case 'reporter':
        await widget.base.reporteTache(tache.id!, widget.maintenant());
      case 'modifier':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditionTacheScreen(
              base: widget.base,
              tache: tache,
              jour: tache.jour,
              maintenant: widget.maintenant,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final m = widget.maintenant();
    final minute = m.hour * 60 + m.minute;
    final soir = m.hour >= 17 || m.hour < 4;
    final enCours = _taches
        .where((x) => x.etat == null && x.debut <= minute && minute < x.fin)
        .firstOrNull;
    final sansReponse = [
      for (final q in _questions)
        if (!_reponses.containsKey(q.id) && q.heure <= minute) q,
    ];
    final repondues = [
      for (final q in _questions)
        if (_reponses.containsKey(q.id)) q,
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const LogoRond(taille: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'OUINON',
                    style: TextStyle(
                      fontFamily: AppTheme.policeMono,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${dateCourte(m).toUpperCase()} · ${_hhmm(minute)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: AppTheme.policeMono,
                        fontSize: 12,
                        color: t.doux,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('reglages'),
                    tooltip: 'Réglages',
                    onPressed: widget.onReglages,
                    icon: Icon(Icons.settings_outlined, color: t.doux),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Apparition(
                retard: 0,
                child: TitreEcran(soir ? 'Bonsoir.' : 'Bonjour.', taille: 40),
              ),
              const SizedBox(height: 6),
              _Apparition(
                retard: 150,
                child: Text(
                  _taches.isEmpty
                      ? 'Rien de prévu aujourd\'hui.'
                      : soir
                      ? 'Voilà ce qu\'a donné ta journée.'
                      : 'Ta journée tourne toute seule.',
                  style: TextStyle(color: t.doux, fontSize: 17),
                ),
              ),
              const SizedBox(height: 18),
              if (_charge)
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (enCours != null && !soir)
                        _Apparition(
                          retard: 250,
                          child: _Maintenant(
                            tache: enCours,
                            minute: minute,
                            onPasFait: () => _repond(enCours, Tache.pasFait),
                            onReporter: () => widget.base.reporteTache(
                              enCours.id!,
                              widget.maintenant(),
                            ),
                            onFait: () => _repond(enCours, Tache.fait),
                          ),
                        ),
                      if (_taches.isNotEmpty)
                        _Apparition(
                          retard: 300,
                          child: _Anneau(taches: _taches),
                        ),
                      const SizedBox(height: 14),
                      for (final (i, x) in _taches.indexed)
                        _Apparition(
                          retard: 450 + i * 60,
                          child: _LigneTache(
                            key: ValueKey('journee-${x.id}'),
                            tache: x,
                            onTap: () => _actions(x),
                          ),
                        ),
                      for (final q in sansReponse)
                        Padding(
                          key: ValueKey('question-${q.id}'),
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                q.texte,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              BoutonsReponse(
                                question: q,
                                choix: null,
                                onChoix: (c) => _choisit(q, c),
                              ),
                            ],
                          ),
                        ),
                      if (repondues.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                for (final (i, q) in repondues.indexed) ...[
                                  if (i > 0) const TextSpan(text: ' · '),
                                  TextSpan(text: '${_court(q.texte)} '),
                                  TextSpan(
                                    text: q.reponses[_reponses[q.id]!],
                                    style: TextStyle(
                                      color: t.texte,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            style: TextStyle(color: t.doux, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                )
              else
                const Spacer(),
              const SizedBox(height: 12),
              BoutonSuite(
                key: const ValueKey('preparer-demain'),
                texte: 'Préparer demain',
                lueur: soir,
                onPressed: widget.onPreparer,
              ),
              Center(
                child: TextButton(
                  key: const ValueKey('mon-suivi'),
                  onPressed: widget.onSuivi,
                  style: TextButton.styleFrom(foregroundColor: t.doux),
                  child: const Text(
                    'Mon suivi',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// « Sommeil ? » → « Sommeil ».
  static String _court(String texte) =>
      texte.endsWith('?') ? texte.substring(0, texte.length - 1).trim() : texte;

  static String _hhmm(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}

/// Monte doucement à l'ouverture, avec un petit retard (ms).
class _Apparition extends StatelessWidget {
  final int retard;
  final Widget child;

  const _Apparition({required this.retard, required this.child});

  @override
  Widget build(BuildContext context) {
    final total = retard + 600;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, v, enfant) {
        final p = Curves.easeOutCubic.transform(
          ((v * total - retard) / 600).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, (1 - p) * 14),
            child: enfant,
          ),
        );
      },
      child: child,
    );
  }
}

/// L'anneau de la journée : faites (bleu-vert), pas faites (corail),
/// sans réponse (gris) ; il se remplit à l'ouverture.
class _Anneau extends StatelessWidget {
  final List<Tache> taches;

  const _Anneau({required this.taches});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final faites = taches.where((x) => x.etat == Tache.fait).length;
    final pasFaites = taches.where((x) => x.etat == Tache.pasFait).length;
    final attente = taches.length - faites - pasFaites;
    Widget legende(Color c, String texte) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1600),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => SizedBox(
            width: 132,
            height: 132,
            child: CustomPaint(
              painter: _PeintureAnneau(
                total: taches.length,
                faites: faites,
                pasFaites: pasFaites,
                avance: v,
                fond: t.puce,
                fait: AppTheme.bleuVert,
                pasFait: t.moinsBonne,
              ),
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${(faites * v).round()}'),
                      TextSpan(
                        text: '/${taches.length}',
                        style: TextStyle(color: t.doux, fontSize: 20),
                      ),
                    ],
                  ),
                  key: const ValueKey('anneau-faites'),
                  style: const TextStyle(
                    fontFamily: AppTheme.policeTitre,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              legende(
                AppTheme.bleuVert,
                '$faites faite${faites > 1 ? 's' : ''}',
              ),
              if (pasFaites > 0)
                legende(
                  t.moinsBonne,
                  '$pasFaites pas faite${pasFaites > 1 ? 's' : ''}',
                ),
              if (attente > 0) legende(t.puce, '$attente sans réponse'),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeintureAnneau extends CustomPainter {
  final int total;
  final int faites;
  final int pasFaites;
  final double avance;
  final Color fond;
  final Color fait;
  final Color pasFait;

  const _PeintureAnneau({
    required this.total,
    required this.faites,
    required this.pasFaites,
    required this.avance,
    required this.fond,
    required this.fait,
    required this.pasFait,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const epaisseur = 11.0;
    final rect = (Offset.zero & size).deflate(epaisseur / 2);
    Paint trait(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trait(fond));
    if (total == 0) return;
    const depart = -math.pi / 2;
    final part = 2 * math.pi / total;
    final f = faites * part * avance;
    if (f > 0) canvas.drawArc(rect, depart, f, false, trait(fait));
    final p = pasFaites * part * avance;
    if (p > 0) {
      // Un petit écart entre les deux arcs (les bouts sont arrondis).
      canvas.drawArc(
        rect,
        depart + faites * part + 0.12,
        math.max(0.01, p - 0.24),
        false,
        trait(pasFait),
      );
    }
  }

  @override
  bool shouldRepaint(_PeintureAnneau a) =>
      a.avance != avance || a.faites != faites || a.total != total;
}

/// Une chose de la journée : l'heure, un signe (fait, pas fait), le nom.
class _LigneTache extends StatelessWidget {
  final Tache tache;
  final VoidCallback onTap;

  const _LigneTache({super.key, required this.tache, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final x = tache;
    final fait = x.etat == Tache.fait;
    final pasFait = x.etat == Tache.pasFait;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.trait)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                _BilanScreenState._hhmm(x.debut),
                style: TextStyle(
                  fontFamily: AppTheme.policeMono,
                  fontSize: 12,
                  color: t.doux,
                ),
              ),
            ),
            SizedBox(
              width: 26,
              child: fait
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppTheme.bleuVert,
                    )
                  : pasFait
                  ? Icon(Icons.close_rounded, size: 18, color: t.moinsBonne)
                  : null,
            ),
            Expanded(
              child: Text(
                x.texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: fait ? t.doux : t.texte,
                  decoration: fait ? TextDecoration.lineThrough : null,
                  decorationColor: t.doux,
                ),
              ),
            ),
            if (pasFait && x.listeId != null)
              Text(
                'revient dans la liste',
                style: TextStyle(fontSize: 12, color: t.moinsBonne),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ce qui est en cours, ouvert dans la journée : Pas fait · Reporter ·
/// Fait.
class _Maintenant extends StatelessWidget {
  final Tache tache;
  final int minute;
  final VoidCallback onPasFait;
  final VoidCallback onReporter;
  final VoidCallback onFait;

  const _Maintenant({
    required this.tache,
    required this.minute,
    required this.onPasFait,
    required this.onReporter,
    required this.onFait,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MAINTENANT · ${_BilanScreenState._hhmm(tache.debut)} → '
            '${_BilanScreenState._hhmm(tache.fin)}',
            style: TextStyle(
              fontFamily: AppTheme.policeMono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tache.texte,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            'encore ${dureeFr(tache.fin - minute)}',
            style: TextStyle(color: t.doux),
          ),
          const SizedBox(height: 10),
          _TroisBoutons(
            onPasFait: onPasFait,
            onReporter: onReporter,
            onFait: onFait,
          ),
        ],
      ),
    );
  }
}

/// Pas fait · Reporter · Fait (la moins bonne à gauche).
class _TroisBoutons extends StatelessWidget {
  final VoidCallback onPasFait;
  final VoidCallback onReporter;
  final VoidCallback onFait;

  const _TroisBoutons({
    required this.onPasFait,
    required this.onReporter,
    required this.onFait,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    Widget bouton(
      String texte,
      Key cle,
      Color c,
      VoidCallback f, {
      bool plein = false,
    }) => Expanded(
      child: SizedBox(
        height: 46,
        child: plein
            ? FilledButton(
                key: cle,
                onPressed: f,
                style: FilledButton.styleFrom(
                  backgroundColor: c,
                  foregroundColor: t.surAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _Mot(texte),
              )
            : OutlinedButton(
                key: cle,
                onPressed: f,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c,
                  side: BorderSide(color: t.barre),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _Mot(texte),
              ),
      ),
    );
    return Row(
      children: [
        bouton('Pas fait', const ValueKey('pas-fait'), t.moinsBonne, onPasFait),
        const SizedBox(width: 8),
        bouton('Reporter', const ValueKey('reporter'), t.texte, onReporter),
        const SizedBox(width: 8),
        bouton(
          'Fait',
          const ValueKey('fait'),
          AppTheme.bleuVert,
          onFait,
          plein: true,
        ),
      ],
    );
  }
}

/// Un mot de bouton sur une seule ligne, réduit plutôt que coupé.
class _Mot extends StatelessWidget {
  final String texte;

  const _Mot(this.texte);

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(texte, maxLines: 1));
}
