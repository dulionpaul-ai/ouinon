import 'package:flutter/material.dart';

import '../data/base.dart';
import '../theme/app_theme.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../widgets/etape.dart';

/// « Demain est prêt. » (maquette validée par Paul le 26/10/2026) : les
/// deux moitiés du rond se rejoignent et respirent doucement ; en
/// dessous, ce que l'appli fera sonner demain, dans l'ordre. « Bonne
/// nuit » ramène à l'accueil : on n'a plus besoin d'ouvrir l'appli avant
/// le lendemain soir.
class PretScreen extends StatefulWidget {
  final Base base;
  final DateTime jour;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const PretScreen({
    super.key,
    required this.base,
    required this.jour,
    this.maintenant = DateTime.now,
  });

  @override
  State<PretScreen> createState() => _PretScreenState();
}

class _PretScreenState extends State<PretScreen>
    with SingleTickerProviderStateMixin {
  // Rapprochement en 1 s, puis trois respirations de 3 s.
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..forward();

  List<({int minute, String texte, String detail, bool question})> _rappels =
      const [];

  @override
  void initState() {
    super.initState();
    _charge();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _charge() async {
    final jour = jourDe(widget.jour);
    final questions = await widget.base.questions();
    final taches = await widget.base.tachesDu(jour);
    if (!mounted) return;
    final rappels = [
      for (final q in questions)
        if (q.active && q.revientLe(jour.weekday))
          (minute: q.heure, texte: q.texte, detail: 'question', question: true),
      for (final t in taches)
        (
          minute: t.debut,
          texte: t.texte,
          detail: t.imperatif ? 'rendez-vous' : dureeFr(t.duree),
          question: false,
        ),
    ]..sort((a, b) => a.minute.compareTo(b.minute));
    setState(() => _rappels = rappels);
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 14),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final s = _anim.value * 10;
              final rapproche = Curves.easeOutCubic.transform(
                s.clamp(0.0, 1.0),
              );
              final souffle = s < 1.2
                  ? 0.0
                  : (1 - ((s - 1.2) % 3 - 1.5).abs() / 1.5);
              double apparait(double debut) =>
                  Curves.easeOut.transform(((s - debut) / 0.5).clamp(0, 1));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Transform.scale(
                      scale: 1 + 0.04 * souffle,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.ambre.withValues(
                                alpha: 0.25 * souffle,
                              ),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        child: Opacity(
                          opacity: rapproche,
                          child: LogoRond(
                            taille: 96,
                            ecart: 6 + 46 * (1 - rapproche),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Opacity(
                    opacity: apparait(0.9),
                    child: Column(
                      children: [
                        const TitreEcran('Demain est prêt.'),
                        const SizedBox(height: 8),
                        Text(
                          'Je te préviendrai au bon moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.doux, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, r) in _rappels.take(9).indexed)
                          Opacity(
                            opacity: apparait(1.2 + i * 0.15),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: t.trait),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      _hhmm(r.minute),
                                      style: TextStyle(
                                        fontFamily: AppTheme.policeMono,
                                        fontSize: 13,
                                        color: r.question
                                            ? AppTheme.bleuVert
                                            : t.accent,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      r.texte,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  Text(
                                    r.detail,
                                    style: TextStyle(
                                      color: t.doux,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_rappels.length > 9)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+ ${_rappels.length - 9} autres',
                              style: TextStyle(color: t.doux, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: apparait(1.6),
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        key: const ValueKey('bonne-nuit'),
                        onPressed: () =>
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.texte,
                          side: BorderSide(color: t.barre),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Bonne nuit',
                          style: TextStyle(
                            fontFamily: AppTheme.policeTitre,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _hhmm(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}
