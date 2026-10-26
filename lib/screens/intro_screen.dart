import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/retro.dart';

/// L'intro des deux toi (idée de Paul du 26/10/2026), en trois pages :
/// 1. le pourquoi, puis « Il y a deux toi » : le rond entier tremble, se
///    brise et se sépare en deux couleurs (revu avec Paul le 26/10/2026) ;
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
    final pages = [
      _pageDeuxToi(context),
      _pageHeures(context),
      _pageNotifs(context),
    ];
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
                        _page == 0 ? 'Répartir les rôles' : 'C\'est ça',
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
    const texte = TextStyle(fontSize: 18, height: 1.4);
    return GestureDetector(
      // Toucher l'écran passe directement à la fin de l'animation.
      behavior: HitTestBehavior.opaque,
      onTap: () => _logo.value = 1,
      child: AnimatedBuilder(
        animation: _logo,
        builder: (context, _) {
          final s = _logo.value * _Recit.total;
          double vu(double debut, {double duree = 0.6}) => Curves.easeInOutCubic
              .transform(((s - debut) / duree).clamp(0.0, 1.0));
          // Un mot qui tombe en gros, puis se pose (« savais », « TOI »…).
          double chute(double debut, {double duree = 0.5}) =>
              1 -
              Curves.easeOutCubic.transform(
                ((s - debut) / duree).clamp(0.0, 1.0),
              );
          Widget ligne(double debut, Widget enfant, {double sortie = 99}) {
            final v = vu(debut) * (1 - vu(sortie, duree: 0.6));
            return Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - v)),
                child: enfant,
              ),
            );
          }

          InlineSpan mot(String texte, double grossi, {Widget? enfant}) =>
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Transform.scale(
                  scale: 1 + grossi,
                  alignment: const Alignment(0, 0.4),
                  child:
                      enfant ??
                      Text(
                        texte,
                        style: TextStyle(
                          fontFamily: AppTheme.policeTitre,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: t.texte,
                        ),
                      ),
                ),
              );
          final doux = texte.copyWith(color: t.doux);
          final pourquoi = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ligne(
                _Recit.entrees[0],
                Text(_Recit.pourquoi[0], style: doux),
                sortie: _Recit.sortie,
              ),
              const SizedBox(height: 10),
              ligne(
                _Recit.entrees[1],
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Tu '),
                      mot('savais', 0.9 * chute(_Recit.entrees[1])),
                      const TextSpan(
                        text: ' quoi faire, mais tu ne le faisais pas.',
                      ),
                    ],
                  ),
                  style: doux,
                ),
                sortie: _Recit.sortie,
              ),
              const SizedBox(height: 10),
              ligne(
                _Recit.entrees[2],
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Le même '),
                      mot('TOI', 1.4 * chute(_Recit.entrees[2])),
                      const TextSpan(
                        text:
                            ' décidait et faisait. C\'était trop pour un '
                            'seul.',
                      ),
                    ],
                  ),
                  style: doux,
                ),
                sortie: _Recit.sortie,
              ),
              const SizedBox(height: 10),
              ligne(
                _Recit.entrees[3],
                Text(_Recit.pourquoi[3], style: texte),
                sortie: _Recit.sortie,
              ),
            ],
          );
          const titre = TextStyle(
            fontFamily: AppTheme.policeTitre,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          );
          final points = vu(_Recit.points, duree: 1.4);
          final deuxToi = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ligne(
                _Recit.deuxToi,
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Il y a '),
                      // « deux » aux couleurs des deux moitiés du logo.
                      mot(
                        'deux',
                        0.8 * chute(_Recit.deuxToi + 0.35, duree: 0.55),
                        enfant: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (r) => const LinearGradient(
                            colors: [
                              AppTheme.ambre,
                              AppTheme.ambre,
                              AppTheme.bleuVert,
                              AppTheme.bleuVert,
                            ],
                            stops: [0, 0.5, 0.5, 1],
                          ).createShader(r),
                          child: const Text('deux', style: titre),
                        ),
                      ),
                      const TextSpan(text: ' toi.'),
                    ],
                  ),
                  style: titre.copyWith(color: t.texte),
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
                      TextSpan(text: ', le décideur planifie.'),
                    ],
                  ),
                  style: texte,
                ),
              ),
              const SizedBox(height: 8),
              ligne(
                _Recit.deuxToi + 1.2,
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Le jour',
                        style: TextStyle(
                          color: AppTheme.bleuVert,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(text: ', l\'exécutant'),
                      // Trois points un par un, un temps, puis la chute.
                      for (var i = 0; i < 3; i++)
                        TextSpan(
                          text: '.',
                          style: TextStyle(
                            color: t.texte.withValues(
                              alpha: (points * 3 - i).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                      const TextSpan(text: ' '),
                      if (s >= _Recit.chute)
                        mot('s\'exécute.', 1.4 * chute(_Recit.chute))
                      else
                        const TextSpan(text: ''),
                    ],
                  ),
                  style: texte,
                ),
              ),
            ],
          );
          // Au moment où le rond se brise : l'écran secoue et flashe.
          final choc = _Recit.coupe + _Recit.fente;
          final apres = s - choc;
          final secousse = apres > 0 && apres < 0.8
              ? (1 - apres / 0.8) * 8
              : 0.0;
          final flash = apres > 0 && apres < 0.6
              ? 0.18 * (1 - apres / 0.6)
              : 0.0;
          return Container(
            foregroundDecoration: BoxDecoration(
              color: t.texte.withValues(alpha: flash),
            ),
            child: Transform.translate(
              offset: Offset(
                math.sin(s * 91) * secousse / 2,
                math.cos(s * 77) * secousse / 2,
              ),
              child: LayoutBuilder(
                builder: (context, contraintes) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: contraintes.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: CustomPaint(
                            size: const Size(170, 170),
                            painter: _Recit.rond(s, t.texte),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Stack(children: [pourquoi, deuxToi]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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

  /// Page 3 (revue avec Paul le 26/10/2026) : les deux toi ne se parlent
  /// pas ; seules les notifications font le lien, chacune à son heure.
  Widget _pageNotifs(BuildContext context) {
    final t = Teintes.de(context);
    const texte = TextStyle(fontSize: 17, height: 1.4);
    Widget ligne(String heure, Color couleur, String message, String quoi) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: couleur,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: Text(
                  heure,
                  maxLines: 1,
                  softWrap: false,
                  style: styleMono(14, couleur: couleur),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(quoi, style: TextStyle(color: t.doux, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        );
    return LayoutBuilder(
      builder: (context, contraintes) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: contraintes.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Les deux '),
                    // « TOI » aux couleurs des deux moitiés du logo.
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) => const LinearGradient(
                          colors: [
                            AppTheme.ambre,
                            AppTheme.ambre,
                            AppTheme.bleuVert,
                            AppTheme.bleuVert,
                          ],
                          stops: [0, 0.5, 0.5, 1],
                        ).createShader(r),
                        child: const Text(
                          'TOI',
                          style: TextStyle(
                            fontFamily: AppTheme.policeTitre,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' ne se parlent pas.'),
                  ],
                ),
                style: TextStyle(
                  fontFamily: AppTheme.policeTitre,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1.15,
                  color: t.texte,
                ),
              ),
              const SizedBox(height: 16),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Le Décideur',
                      style: TextStyle(
                        color: AppTheme.ambre,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: ' planifie. Chaque matin, '),
                    TextSpan(
                      text: 'l\'Exécutant',
                      style: TextStyle(
                        color: AppTheme.bleuVert,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' reçoit ses ordres. Entre eux, rien que '
                          'des notifications :',
                    ),
                  ],
                ),
                style: texte,
              ),
              const SizedBox(height: 14),
              ligne(
                hhmm(_soir.debut),
                AppTheme.ambre,
                '«\u00a0Et demain, tu fais quoi\u00a0?\u00a0»',
                'le Décideur prépare la journée',
              ),
              ligne(
                hhmm(_jour.debut),
                AppTheme.bleuVert,
                '«\u00a0Ta journée t\'attend\u00a0»',
                'l\'Exécutant reçoit ses tâches',
              ),
              ligne(
                '',
                AppTheme.bleuVert,
                '«\u00a0C\'est l\'heure\u00a0», puis «\u00a0C\'est fait\u00a0?\u00a0»',
                'pour chaque chose, au début et à la fin',
              ),
              ligne(
                hhmm(_jour.fin),
                AppTheme.ambre,
                '«\u00a0Fin de service\u00a0»',
                'le compte rendu remonte au Décideur',
              ),
              const SizedBox(height: 18),
              Text(
                'Tout reste sur ton téléphone.',
                style: TextStyle(color: t.doux, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le minutage de la page 1, en secondes (revu avec Paul le 26/10/2026) :
/// les lignes du pourquoi une à une (« savais » et « TOI » tombent avec
/// leur phrase), un silence, le rond qui tremble puis se brise lentement,
/// puis « Il y a deux toi » et « l'exécutant… s'exécute. ».
abstract final class _Recit {
  static const pourquoi = [
    'Tu voulais reprendre ta vie en main.',
    'Tu savais quoi faire, mais tu ne le faisais pas.',
    'Le même TOI décidait et faisait. C\'était trop pour un seul.',
    'Alors tu as séparé les deux.',
  ];

  static const entrees = [0.8, 2.7, 4.7, 9.0];
  static const coupe = 10.2;
  static const fente = 0.6;
  static const ecart = 2.8;
  static const sortie = coupe + 4.2;
  static const deuxToi = sortie + 0.6;
  static const points = deuxToi + 1.9;
  static const chute = points + 2.0;
  static const bouton = chute + 1.2;
  static const total = bouton + 0.6;

  /// De 0 à 1 en [duree] secondes à partir de [debut], selon [valeur]
  /// (l'avancée de l'animation, de 0 à 1).
  static double apparition(double valeur, double debut, {double duree = 0.6}) =>
      Curves.easeInOutCubic.transform(
        ((valeur * total - debut) / duree).clamp(0.0, 1.0),
      );

  /// Le logo à l'instant [s] : il naît, tremble de plus en plus à partir
  /// de « TOI », se fend, envoie une onde, puis ses moitiés s'éloignent.
  static RondDissocie rond(double s, Color entier) {
    double part(double debut, double duree) =>
        ((s - debut) / duree).clamp(0.0, 1.0);
    final debutTension = entrees[2] + 0.6;
    final tension = s > debutTension && s < coupe + fente
        ? math.pow(part(debutTension, coupe - debutTension), 1.8).toDouble()
        : 0.0;
    return RondDissocie(
      naissance: Curves.easeOutCubic.transform(part(0, 0.7)),
      fente: Curves.easeInOutCubic.transform(part(coupe, fente)),
      ecart: Curves.easeInOutCubic.transform(part(coupe + fente * 0.8, ecart)),
      tension: tension,
      tremble: Offset(math.sin(s * 97), math.cos(s * 83)),
      onde: part(coupe + fente, 1.8),
      entier: entier,
    );
  }
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

  /// Tremblement (de 0 à 1) et sa direction du moment.
  final double tension;
  final Offset tremble;

  /// Onde de choc après la cassure, de 0 à 1 (1 = finie).
  final double onde;
  final Color entier;
  final Color gauche;
  final Color droite;

  const RondDissocie({
    this.naissance = 1,
    this.fente = 1,
    this.ecart = 1,
    this.tension = 0,
    this.tremble = Offset.zero,
    this.onde = 1,
    this.entier = const Color(0xFFF5F5F2),
    this.gauche = AppTheme.ambre,
    this.droite = AppTheme.bleuVert,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (naissance <= 0) return;
    final r =
        size.shortestSide *
        0.38 *
        (0.85 + 0.15 * naissance) *
        (1 + 0.05 * tension);
    final c = size.center(Offset.zero) + tremble * (3 * tension);
    if (onde > 0 && onde < 1) {
      final o = Curves.easeOutCubic.transform(onde);
      canvas.drawCircle(
        c,
        r * (1 + 0.7 * o),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - onde) + 0.5
          ..color = entier.withValues(alpha: 0.7 * (1 - onde)),
      );
    }
    final dx = r * 0.1 * ecart + (fente > 0 ? 1 : 0);
    final dy = r * 0.12 * ecart;
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
    if (fente < 1) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      canvas.drawRect(
        Rect.fromLTRB(c.dx - 2, c.dy - r + 2 * r * fente, c.dx + 2, c.dy + r),
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
      ancien.tension != tension ||
      ancien.onde != onde ||
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
