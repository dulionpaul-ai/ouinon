import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../utils/jeu.dart';

/// Le bandeau du jeu « Synchro », en haut de chaque page (docs/jeu.md,
/// étape 1) : le niveau, la barre de points qui se remplit, la synchro du
/// jour en petit anneau et les points gagnés aujourd'hui. Quand des points
/// arrivent, « +N » s'envole ; quand un niveau est passé, l'écran entier
/// le fête. Le toucher ouvre le détail des points du jour.
class BandeauJeu extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const BandeauJeu({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<BandeauJeu> createState() => _BandeauJeuState();
}

class _BandeauJeuState extends State<BandeauJeu> with TickerProviderStateMixin {
  BilanJeu? _bilan;

  /// Remplissage de la barre : part du niveau, animée de l'ancienne à la
  /// nouvelle (à l'ouverture, depuis zéro).
  double _de = 0;
  late final _barre = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Le « +N » qui s'envole.
  int _gain = 0;
  late final _envol = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    widget.base.changements.addListener(_charge);
    _charge();
  }

  @override
  void dispose() {
    widget.base.changements.removeListener(_charge);
    _barre.dispose();
    _envol.dispose();
    super.dispose();
  }

  double _part(BilanJeu b) => b.dansNiveau / b.pourNiveau;

  Future<void> _charge() async {
    final base = widget.base;
    final taches = await base.taches();
    final reponses = await base.toutesLesReponses();
    final plans = await PrefsJeu.plans();
    if (!mounted) return;
    final nouveau = bilanJeu(
      taches: taches,
      reponses: reponses,
      plans: plans,
      aujourdhui: widget.maintenant(),
    );
    final ancien = _bilan;
    if (ancien != null && nouveau.total == ancien.total) {
      setState(() => _bilan = nouveau);
      return;
    }
    setState(() {
      // Un niveau passé : la barre repart de zéro.
      _de = ancien == null || nouveau.niveau != ancien.niveau
          ? 0
          : _part(ancien);
      _bilan = nouveau;
      if (ancien != null && nouveau.total > ancien.total) {
        _gain = nouveau.total - ancien.total;
      }
    });
    unawaited(_barre.forward(from: 0));
    if (ancien != null && nouveau.total > ancien.total) {
      unawaited(_envol.forward(from: 0));
    }
    await _fete(nouveau);
  }

  /// Un niveau pas encore fêté : l'écran du niveau suivant. La toute
  /// première fois, on note le niveau sans rien montrer.
  Future<void> _fete(BilanJeu b) async {
    final vu = await PrefsJeu.niveauVu();
    if (vu != null && b.niveau <= vu) return;
    await PrefsJeu.changeNiveauVu(b.niveau);
    if (vu == null || !mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, _, _) => NiveauSuivant(
        ancien: vu,
        niveau: b.niveau,
        nouveauStade: stadePour(vu) != b.stade ? b.stade : null,
      ),
    );
  }

  void _detail() {
    final b = _bilan;
    if (b == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _Detail(bilan: b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final b = _bilan;
    return Semantics(
      button: true,
      label: b == null
          ? 'Jeu'
          : 'Niveau ${b.niveau}, ${b.duJour} points aujourd\'hui',
      child: InkWell(
        key: const ValueKey('bandeau-jeu'),
        onTap: _detail,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.puce)),
          ),
          child: b == null
              ? null
              : Row(
                  children: [
                    // Le niveau.
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NIV',
                          style: TextStyle(
                            fontFamily: AppTheme.policeTitre,
                            fontSize: 8,
                            letterSpacing: 2,
                            color: t.doux,
                          ),
                        ),
                        Text(
                          '${b.niveau}',
                          key: const ValueKey('niveau-jeu'),
                          style: TextStyle(
                            fontFamily: AppTheme.policeTitre,
                            fontSize: 20,
                            height: 1.1,
                            color: t.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Le stade et la barre de points.
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  b.stade.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.policeTitre,
                                    fontSize: 9,
                                    letterSpacing: 1.6,
                                    color: t.texte,
                                  ),
                                ),
                              ),
                              Text(
                                '${b.dansNiveau}/${b.pourNiveau}',
                                style: TextStyle(
                                  fontFamily: AppTheme.policeMono,
                                  fontSize: 10,
                                  color: t.doux,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AnimatedBuilder(
                            animation: _barre,
                            builder: (context, _) {
                              final v = Curves.easeOutCubic.transform(
                                _barre.value,
                              );
                              return CustomPaint(
                                size: const Size.fromHeight(6),
                                painter: _Barre(
                                  part: _de + (_part(b) - _de) * v,
                                  accent: t.accent,
                                  fond: t.puce,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // La synchro du jour.
                    _AnneauSynchro(part: b.synchroDuJour),
                    const SizedBox(width: 12),
                    // Les points du jour, et le « +N » qui s'envole.
                    SizedBox(
                      width: 52,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerRight,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${b.duJour}',
                                key: const ValueKey('points-du-jour'),
                                style: TextStyle(
                                  fontFamily: AppTheme.policeMono,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: t.texte,
                                ),
                              ),
                              Text(
                                'AUJ.',
                                style: TextStyle(
                                  fontFamily: AppTheme.policeTitre,
                                  fontSize: 8,
                                  letterSpacing: 1.6,
                                  color: t.doux,
                                ),
                              ),
                            ],
                          ),
                          AnimatedBuilder(
                            animation: _envol,
                            builder: (context, _) {
                              final v = _envol.value;
                              if (v == 0 || v == 1 || _gain == 0) {
                                return const SizedBox.shrink();
                              }
                              final monte = Curves.easeOutCubic.transform(v);
                              return Positioned(
                                right: 0,
                                top: 20 - 40 * monte,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: v < 0.7 ? 1 : (1 - v) / 0.3,
                                    child: Transform.scale(
                                      scale: 1 + 0.4 * math.sin(v * math.pi),
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '+$_gain',
                                        style: TextStyle(
                                          fontFamily: AppTheme.policeMono,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: t.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// La barre de points, en segments, avec un bord net qui brille.
class _Barre extends CustomPainter {
  final double part;
  final Color accent;
  final Color fond;

  _Barre({required this.part, required this.accent, required this.fond});

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 20;
    const vide = 2.0;
    final largeur = (size.width - vide * (segments - 1)) / segments;
    final plein = part.clamp(0.0, 1.0) * segments;
    for (var i = 0; i < segments; i++) {
      final x = i * (largeur + vide);
      final r = Rect.fromLTWH(x, 0, largeur, size.height);
      canvas.drawRect(r, Paint()..color = fond);
      final remplit = (plein - i).clamp(0.0, 1.0);
      if (remplit > 0) {
        final dernier = plein - i < 1;
        canvas.drawRect(
          Rect.fromLTWH(x, 0, largeur * remplit, size.height),
          Paint()..color = dernier ? accent : accent.withValues(alpha: 0.75),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Barre old) => old.part != part || old.accent != accent;
}

/// La synchro du jour : un petit anneau et le pourcentage.
class _AnneauSynchro extends StatelessWidget {
  final double? part;

  const _AnneauSynchro({required this.part});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final p = part;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: p ?? 0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 38,
        height: 38,
        child: CustomPaint(
          painter: _Anneau(part: v, accent: t.accent, fond: t.puce),
          child: Center(
            child: Text(
              p == null ? '—' : '${(v * 100).round()}',
              key: const ValueKey('synchro-jeu'),
              style: TextStyle(
                fontFamily: AppTheme.policeMono,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p == null ? t.doux : t.texte,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Anneau extends CustomPainter {
  final double part;
  final Color accent;
  final Color fond;

  _Anneau({required this.part, required this.accent, required this.fond});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
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
        trait..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(_Anneau old) => old.part != part;
}

/// Le détail des points d'aujourd'hui, et comment on en gagne.
class _Detail extends StatelessWidget {
  final BilanJeu bilan;

  const _Detail({required this.bilan});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final b = bilan;
    TextStyle titre(double taille, Color couleur) => TextStyle(
      fontFamily: AppTheme.policeTitre,
      fontSize: taille,
      letterSpacing: 1.6,
      color: couleur,
    );
    Widget ligne(String texte, String points, {bool fort = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: fort ? t.texte : t.doux),
            ),
          ),
          Text(
            points,
            style: TextStyle(
              fontFamily: AppTheme.policeMono,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: fort ? t.accent : t.doux,
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'NIVEAU ${b.niveau} · ${b.stade.toUpperCase()}',
              style: titre(13, t.accent),
            ),
            const SizedBox(height: 4),
            Text(
              '${b.total} points en tout · encore '
              '${b.pourNiveau - b.dansNiveau} pour le niveau ${b.niveau + 1}'
              '${b.serie >= 2 ? ' · série de ${b.serie} jours' : ''}',
              style: TextStyle(color: t.doux, fontSize: 14),
            ),
            const SizedBox(height: 18),
            Text('AUJOURD\'HUI', style: titre(10, t.doux)),
            const SizedBox(height: 6),
            if (b.gainsDuJour.isEmpty)
              ligne('Rien encore aujourd\'hui', '0')
            else
              for (final g in b.gainsDuJour)
                ligne(g.texte, '+${g.points}', fort: true),
            const SizedBox(height: 18),
            Text('CE QUI RAPPORTE', style: titre(10, t.doux)),
            const SizedBox(height: 6),
            ligne('Une chose faite, selon sa durée', '+10 à +35'),
            ligne('Venue de « D\'abord »', '+$bonusDabord'),
            ligne('Une réponse, quelle qu\'elle soit', '+$pointsReponse'),
            ligne('Le plan de demain validé', '+$pointsPlan'),
            ligne('Synchro du jour à 100 %', '+50'),
            ligne('Série : par jour d\'affilée', '+5'),
            const SizedBox(height: 8),
            Text(
              'On ne perd jamais de points.',
              style: TextStyle(color: t.doux, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'écran du niveau suivant : lignes de balayage, « NIVEAU », le numéro
/// qui bascule chiffre par chiffre comme un panneau de gare, et le nom du
/// nouveau stade s'il change. On touche pour fermer.
class NiveauSuivant extends StatefulWidget {
  final int ancien;
  final int niveau;

  /// Le stade atteint, s'il vient de changer.
  final String? nouveauStade;

  const NiveauSuivant({
    super.key,
    required this.ancien,
    required this.niveau,
    this.nouveauStade,
  });

  @override
  State<NiveauSuivant> createState() => _NiveauSuivantState();
}

class _NiveauSuivantState extends State<NiveauSuivant>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// La part de l'animation entre [debut] et [fin] (de 0 à 1).
  double _entre(double debut, double fin) =>
      ((_anim.value - debut) / (fin - debut)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final avant = '${widget.ancien}'.padLeft('${widget.niveau}'.length, '0');
    final apres = '${widget.niveau}';
    return GestureDetector(
      key: const ValueKey('niveau-suivant'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final cadre = Curves.easeOutCubic.transform(_entre(0, 0.25));
            final stade = _entre(0.7, 0.95);
            return CustomPaint(
              painter: _Balayage(avance: _anim.value, couleur: t.accent),
              child: Center(
                child: Opacity(
                  opacity: cadre,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NIVEAU',
                        style: TextStyle(
                          fontFamily: AppTheme.policeTitre,
                          fontSize: 16,
                          letterSpacing: 8 + 6 * (1 - cadre),
                          color: t.doux,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < apres.length; i++)
                            _Chiffre(
                              avant: avant[i],
                              apres: apres[i],
                              // Chiffre par chiffre, de gauche à droite.
                              avance: Curves.easeInOutCubic.transform(
                                _entre(0.2 + 0.12 * i, 0.45 + 0.12 * i),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 60,
                        child: widget.nouveauStade == null
                            ? null
                            : Opacity(
                                opacity: stade,
                                child: Column(
                                  children: [
                                    Text(
                                      'NOUVEAU STADE',
                                      style: TextStyle(
                                        fontFamily: AppTheme.policeTitre,
                                        fontSize: 10,
                                        letterSpacing: 3,
                                        color: t.doux,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      // Lettre par lettre.
                                      widget.nouveauStade!
                                          .toUpperCase()
                                          .substring(
                                            0,
                                            (widget.nouveauStade!.length *
                                                    stade)
                                                .round(),
                                          ),
                                      style: TextStyle(
                                        fontFamily: AppTheme.policeTitre,
                                        fontSize: 20,
                                        letterSpacing: 2,
                                        color: t.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      Opacity(
                        opacity: _entre(0.85, 1),
                        child: Text(
                          'Touche pour continuer',
                          style: TextStyle(color: t.doux, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Un chiffre du panneau : l'ancien bascule vers le haut, le nouveau
/// arrive d'en bas.
class _Chiffre extends StatelessWidget {
  final String avant;
  final String apres;
  final double avance;

  const _Chiffre({
    required this.avant,
    required this.apres,
    required this.avance,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    const hauteur = 112.0;
    final style = TextStyle(
      fontFamily: AppTheme.policeTitre,
      fontSize: 84,
      height: 1.25,
      color: t.texte,
    );
    final change = avant != apres;
    final v = change ? avance : 1.0;
    return Container(
      width: 76,
      height: hauteur,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: t.carte,
        border: Border.all(color: t.accent.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (change && v < 1)
              Transform.translate(
                offset: Offset(0, -hauteur * v),
                child: Text(avant, style: style),
              ),
            Transform.translate(
              offset: Offset(0, hauteur * (1 - v)),
              child: Text(apres, style: style),
            ),
            // La ligne du milieu du panneau.
            Container(height: 1, color: t.fond.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}

/// Lignes de balayage fines et une ligne nette qui descend l'écran.
class _Balayage extends CustomPainter {
  final double avance;
  final Color couleur;

  _Balayage({required this.avance, required this.couleur});

  @override
  void paint(Canvas canvas, Size size) {
    final lignes = Paint()..color = couleur.withValues(alpha: 0.05);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), lignes);
    }
    // Deux passages de la ligne de balayage.
    final passage = (avance * 2) % 1;
    if (avance < 1) {
      final y = size.height * Curves.easeInOut.transform(passage);
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 2),
        Paint()..color = couleur.withValues(alpha: 0.7),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, y - 40, size.width, 40),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              couleur.withValues(alpha: 0),
              couleur.withValues(alpha: 0.12),
            ],
          ).createShader(Rect.fromLTWH(0, y - 40, size.width, 40)),
      );
    }
  }

  @override
  bool shouldRepaint(_Balayage old) => old.avance != avance;
}
