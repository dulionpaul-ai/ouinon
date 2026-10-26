import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/retro.dart';

/// L'intro des deux toi (idée de Paul du 26/10/2026), en trois pages :
/// 1. le pourquoi, puis « Il y a deux toi » : le rond entier se fend et
///    se sépare en deux couleurs (texte B choisi par Paul le 26/10/2026) ;
/// 2. « Qui est là, et quand ? » : les heures de chacun ;
/// 3. les notifications, par lesquelles ils se parlent.
///
/// Renvoie vrai si la personne a demandé les notifications.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  int _page = 0;
  ({int debut, int fin}) _jour = (
    debut: Preferences.debutJourneeParDefaut,
    fin: Preferences.finJourneeParDefaut,
  );
  ({int debut, int fin}) _soir = (
    debut: Preferences.heureRappelPlanningParDefaut,
    fin: DeuxMoi.finSoirParDefaut,
  );

  late final _logo = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_Recit.total * 1000).round()),
  )..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) _logo.value = 1;
  }

  @override
  void initState() {
    super.initState();
    _charge();
  }

  Future<void> _charge() async {
    final jour = await Preferences.journee();
    final soir = await DeuxMoi.soir();
    if (mounted) {
      setState(() {
        _jour = jour;
        _soir = soir;
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _logo.dispose();
    super.dispose();
  }

  void _suivante() => _pages.nextPage(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  Future<void> _termine(bool notifications) async {
    await Preferences.changeJournee(debut: _jour.debut, fin: _jour.fin);
    await DeuxMoi.changeSoir(debut: _soir.debut, fin: _soir.fin);
    await DeuxMoi.active(true);
    if (mounted) Navigator.pop(context, notifications);
  }

  /// Cadran d'heure (sans clavier, 24 h) ; nul si annulé.
  Future<int?> _heure(int depart, String aide) async {
    final choisie = await showTimePicker(
      context: context,
      helpText: aide,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: TimeOfDay(hour: depart ~/ 60, minute: depart % 60),
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    return choisie == null ? null : choisie.hour * 60 + choisie.minute;
  }

  Future<void> _choisitJour() async {
    final debut = await _heure(_jour.debut, 'Tu commences à');
    if (debut == null) return;
    final fin = await _heure(_jour.fin, 'Tu finis à');
    if (fin == null || !mounted) return;
    if (fin <= debut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit venir après le début.')),
      );
      return;
    }
    setState(() => _jour = (debut: debut, fin: fin));
  }

  Future<void> _choisitSoir() async {
    final debut = await _heure(_soir.debut, 'Tu décides à partir de');
    if (debut == null) return;
    final fin = await _heure(_soir.fin, 'Jusqu\'à');
    if (fin == null || !mounted) return;
    setState(() => _soir = (debut: debut, fin: fin));
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final pages = [_pageDeuxToi(context), _pageHeures(context), _pageNotifs()];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (p) => setState(() => _page = p),
                  children: pages,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: ShapeDecoration(
                        color: i == _page ? t.texte : t.puce,
                        shape: const StadiumBorder(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (_page < 2)
                AnimatedBuilder(
                  animation: _logo,
                  builder: (context, enfant) => Opacity(
                    opacity: _page == 0
                        ? _Recit.apparition(_logo.value, _Recit.bouton)
                        : 1,
                    child: enfant,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (_page == 0 && _logo.isAnimating) {
                          _logo.value = 1;
                        } else {
                          _suivante();
                        }
                      },
                      child: Text(
                        _page == 0 ? 'Faire connaissance' : 'C\'est ça',
                      ),
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _termine(true),
                    child: const Text('Autoriser les notifications'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _termine(false),
                  child: const Text('Plus tard'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageDeuxToi(BuildContext context) {
    final t = Teintes.de(context);
    Widget ligne(double debut, Widget enfant, {double sortie = 99}) =>
        AnimatedBuilder(
          animation: _logo,
          builder: (context, _) {
            final v =
                _Recit.apparition(_logo.value, debut) *
                (1 - _Recit.apparition(_logo.value, sortie, duree: 0.5));
            return Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - v)),
                child: enfant,
              ),
            );
          },
        );
    const texte = TextStyle(fontSize: 18, height: 1.4);
    final pourquoi = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _Recit.pourquoi.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          ligne(
            _Recit.entree(i),
            Text(
              _Recit.pourquoi[i],
              style: i == _Recit.pourquoi.length - 1
                  ? texte
                  : texte.copyWith(color: t.doux),
            ),
            sortie: _Recit.sortie,
          ),
        ],
      ],
    );
    final deuxToi = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ligne(
          _Recit.deuxToi,
          Text(
            'Il y a deux toi.',
            style: TextStyle(
              fontFamily: AppTheme.policeTitre,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: t.texte,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ligne(
          _Recit.deuxToi + 0.6,
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Le soir',
                  style: TextStyle(
                    color: AppTheme.ambre,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: ', l\'un décide.'),
              ],
            ),
            style: texte,
          ),
        ),
        const SizedBox(height: 8),
        ligne(
          _Recit.deuxToi + 1.2,
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Le jour',
                  style: TextStyle(
                    color: AppTheme.bleuVert,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: ', l\'autre exécute.'),
              ],
            ),
            style: texte,
          ),
        ),
      ],
    );
    // Toucher l'écran passe directement à la fin de l'animation.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _logo.value = 1,
      child: LayoutBuilder(
        builder: (context, contraintes) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: contraintes.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: _logo,
                    builder: (context, _) {
                      final s = _logo.value * _Recit.total;
                      return CustomPaint(
                        size: const Size(150, 150),
                        painter: RondDissocie(
                          naissance: Curves.easeOutCubic.transform(
                            (s / 0.7).clamp(0.0, 1.0),
                          ),
                          fente: Curves.easeInOutCubic.transform(
                            ((s - _Recit.coupe) / 0.5).clamp(0.0, 1.0),
                          ),
                          ecart: Curves.easeInOutCubic.transform(
                            ((s - _Recit.coupe - 0.5) / 1.1).clamp(0.0, 1.0),
                          ),
                          entier: t.texte,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Stack(children: [pourquoi, deuxToi]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeures(BuildContext context) {
    final t = Teintes.de(context);
    Widget ligne({
      required Key cle,
      required Color couleur,
      required String titre,
      required String sousTitre,
      required ({int debut, int fin}) plage,
      required VoidCallback onTap,
    }) => InkWell(
      key: cle,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.puce)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    sousTitre,
                    style: TextStyle(color: t.doux, fontSize: 13),
                  ),
                ],
              ),
            ),
            Text(
              '${hhmm(plage.debut)} – ${hhmm(plage.fin)}',
              style: styleMono(15, couleur: couleur),
            ),
          ],
        ),
      ),
    );
    return ListView(
      children: [
        const SizedBox(height: 24),
        Text(
          'Qui est là, et quand ?',
          style: TextStyle(
            fontFamily: AppTheme.policeTitre,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: t.texte,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Touche une ligne pour changer ses heures.',
          style: TextStyle(color: t.doux, fontSize: 15),
        ),
        const SizedBox(height: 28),
        Center(
          child: SizedBox(
            width: 210,
            height: 210,
            child: CustomPaint(
              painter: _Cadran(jour: _jour, soir: _soir, puce: t.puce),
              child: Center(
                child: Text(
                  'le reste :\nrepos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.doux,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        ligne(
          cle: const ValueKey('intro-soir'),
          couleur: AppTheme.ambre,
          titre: 'Toi qui décides',
          sousTitre: 'le soir, tu prépares demain',
          plage: _soir,
          onTap: _choisitSoir,
        ),
        ligne(
          cle: const ValueKey('intro-jour'),
          couleur: AppTheme.bleuVert,
          titre: 'Toi qui exécutes',
          sousTitre: 'le jour, tu fais',
          plage: _jour,
          onTap: _choisitJour,
        ),
      ],
    );
  }

  Widget _pageNotifs() => Container(
    margin: const EdgeInsets.symmetric(vertical: 24),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Teintes.retro.fond,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Teintes.retro.puce),
    ),
    child: FondRetro(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ILS SE PARLENT', style: styleRetro(34)),
            Text('PAR NOTIFICATIONS.', style: styleRetro(34)),
            const SizedBox(height: 24),
            for (final (heure, texte) in [
              (hhmm(_soir.debut), 'LE SOIR : PRÉPARER DEMAIN'),
              (hhmm(_jour.debut), 'LE MATIN : TA JOURNÉE T\'ATTEND'),
              ('', 'CHAQUE CHOSE : C\'EST L\'HEURE, PUIS C\'EST FAIT ?'),
              (hhmm(_jour.fin), 'LE COMPTE RENDU'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        heure,
                        maxLines: 1,
                        softWrap: false,
                        style: styleMono(13),
                      ),
                    ),
                    Expanded(child: Text(texte, style: styleMono(13))),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Text(
              'Tout reste sur ton téléphone.',
              style: styleMono(12, couleur: Teintes.retro.doux),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Le minutage de la page 1, en secondes : les lignes du pourquoi une à
/// une, le rond qui se fend sur la dernière, puis « Il y a deux toi ».
abstract final class _Recit {
  static const pourquoi = [
    'Tu voulais reprendre ta vie en main.',
    'Tu savais quoi faire. Tu ne le faisais pas.',
    'Le même toi décidait et faisait. C\'était trop pour un seul.',
    'Alors tu as séparé les deux.',
  ];

  static double entree(int i) => 0.8 + i * 1.9;
  static final coupe = entree(pourquoi.length - 1) + 0.5;
  static final sortie = coupe + 2.2;
  static final deuxToi = sortie + 0.6;
  static final bouton = deuxToi + 2.1;
  static final total = bouton + 0.6;

  /// De 0 à 1 en [duree] secondes à partir de [debut], selon [valeur]
  /// (l'avancée de l'animation, de 0 à 1).
  static double apparition(double valeur, double debut, {double duree = 0.6}) =>
      Curves.easeInOutCubic.transform(
        ((valeur * total - debut) / duree).clamp(0.0, 1.0),
      );
}

/// Le logo : un rond coupé en deux, moitié gauche ambre (le soir) plus
/// haute, moitié droite bleu-vert (le jour) plus basse. Pour l'intro :
/// `naissance` le fait apparaître, `fente` le fend de haut en bas, et
/// `ecart` de 0 (rond entier, couleur `entier`) à 1 (dissocié, en
/// couleurs).
class RondDissocie extends CustomPainter {
  final double naissance;
  final double fente;
  final double ecart;
  final Color entier;
  final Color gauche;
  final Color droite;

  const RondDissocie({
    this.naissance = 1,
    this.fente = 1,
    this.ecart = 1,
    this.entier = const Color(0xFFF5F5F2),
    this.gauche = AppTheme.ambre,
    this.droite = AppTheme.bleuVert,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (naissance <= 0) return;
    final r = size.shortestSide * 0.38 * (0.85 + 0.15 * naissance);
    final c = size.center(Offset.zero);
    final dx = r * 0.07 * ecart + 1;
    final dy = r * 0.09 * ecart;
    Paint peinture(Color couleur) => Paint()
      ..color = Color.lerp(
        entier,
        couleur,
        ecart,
      )!.withValues(alpha: naissance);
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(-dx, -dy), radius: r),
      math.pi / 2,
      math.pi,
      true,
      peinture(gauche),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(dx, dy), radius: r),
      -math.pi / 2,
      math.pi,
      true,
      peinture(droite),
    );
    // Tant que la fente n'est pas allée au bout, le bas reste soudé.
    if (fente < 1 && ecart == 0) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      canvas.drawRect(
        Rect.fromLTRB(
          c.dx - 1.5,
          c.dy - r + 2 * r * fente,
          c.dx + 1.5,
          c.dy + r,
        ),
        peinture(gauche),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(RondDissocie ancien) =>
      ancien.ecart != ecart ||
      ancien.fente != fente ||
      ancien.naissance != naissance ||
      ancien.entier != entier;
}

/// Cadran de 24 heures : le soir en ambre, le jour en bleu-vert.
class _Cadran extends CustomPainter {
  final ({int debut, int fin}) jour;
  final ({int debut, int fin}) soir;
  final Color puce;

  const _Cadran({required this.jour, required this.soir, required this.puce});

  @override
  void paint(Canvas canvas, Size size) {
    final epaisseur = size.shortestSide * 0.11;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - epaisseur / 2,
    );
    Paint trait(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trait(puce));
    void plage(({int debut, int fin}) p, Color c) {
      final duree = (p.fin - p.debut) % (24 * 60);
      canvas.drawArc(
        rect,
        -math.pi / 2 + p.debut / (24 * 60) * 2 * math.pi,
        duree / (24 * 60) * 2 * math.pi,
        false,
        trait(c),
      );
    }

    plage(jour, AppTheme.bleuVert);
    plage(soir, AppTheme.ambre);
  }

  @override
  bool shouldRepaint(_Cadran ancien) =>
      ancien.jour != jour || ancien.soir != soir;
}
