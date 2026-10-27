import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/courbes.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';

/// Lance l'animation d'un graphique quand on s'arrête dessus en faisant
/// défiler (au moins 60 % visible, défilement arrêté) ; elle repart de
/// zéro quand le graphique est sorti de l'écran puis revient. `t` va de 0
/// à 1. Hors d'une liste qui défile, l'animation part tout de suite.
class AnimeQuandVisible extends StatefulWidget {
  final Widget Function(BuildContext context, double t) builder;
  final Duration duree;

  const AnimeQuandVisible({
    super.key,
    required this.builder,
    this.duree = const Duration(milliseconds: 1100),
  });

  @override
  State<AnimeQuandVisible> createState() => _AnimeQuandVisibleState();
}

class _AnimeQuandVisibleState extends State<AnimeQuandVisible>
    with SingleTickerProviderStateMixin {
  late final _controleur = AnimationController(
    vsync: this,
    duration: widget.duree,
  );
  late final _courbe = CurvedAnimation(
    parent: _controleur,
    curve: Curves.easeOutCubic,
  );
  ScrollPosition? _position;
  bool _joue = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.isScrollingNotifier.removeListener(_verifie);
      _position?.removeListener(_sortie);
      _position = position;
      _position?.isScrollingNotifier.addListener(_verifie);
      _position?.addListener(_sortie);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifie());
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_verifie);
    _position?.removeListener(_sortie);
    _controleur.dispose();
    super.dispose();
  }

  /// Part du graphique visible dans la liste (1 hors d'une liste).
  double _partVisible() {
    final boite = context.findRenderObject();
    final liste = _position?.context.notificationContext?.findRenderObject();
    if (boite is! RenderBox || !boite.attached || boite.size.height == 0) {
      return 0;
    }
    if (liste is! RenderBox || !liste.attached) return 1;
    final haut = boite.localToGlobal(Offset.zero).dy;
    final bas = haut + boite.size.height;
    final listeHaut = liste.localToGlobal(Offset.zero).dy;
    final listeBas = listeHaut + liste.size.height;
    final commun = math.min(bas, listeBas) - math.max(haut, listeHaut);
    return (commun / boite.size.height).clamp(0.0, 1.0);
  }

  /// Défilement arrêté et graphique bien visible : on anime.
  void _verifie() {
    if (!mounted || _joue) return;
    if (_position?.isScrollingNotifier.value ?? false) return;
    if (_partVisible() >= 0.6) {
      _joue = true;
      _controleur.forward(from: 0);
    }
  }

  /// Sorti de l'écran : prêt à rejouer.
  void _sortie() {
    if (!mounted || !_joue) return;
    if (_partVisible() < 0.05) {
      _joue = false;
      _controleur.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _courbe,
    builder: (context, _) => widget.builder(context, _courbe.value),
  );
}

/// Ne garde que la partie gauche (`part` de la largeur) : la courbe « se
/// dessine » de gauche à droite.
class _ClipGauche extends CustomClipper<Rect> {
  final double part;

  const _ClipGauche(this.part);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -20, size.width * part, size.height + 40);

  @override
  bool shouldReclip(_ClipGauche ancien) => ancien.part != part;
}

List<FlSpot> _points(List<double?> valeurs) => [
  for (final (i, v) in valeurs.indexed)
    v == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), v),
];

LineChartBarData _ligne(
  List<double?> valeurs,
  Color couleur, {
  bool aire = true,
}) => LineChartBarData(
  spots: _points(valeurs),
  isCurved: true,
  curveSmoothness: 0.3,
  preventCurveOverShooting: true,
  color: couleur,
  barWidth: 3,
  isStrokeCapRound: true,
  dotData: const FlDotData(show: false),
  belowBarData: BarAreaData(
    show: aire,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [couleur.withValues(alpha: 0.32), couleur.withValues(alpha: 0.0)],
    ),
  ),
);

/// Une ou deux courbes lissées (moyenne sur 7 jours), avec un dégradé
/// dessous, qui se dessinent de gauche à droite. Le doigt posé dessus
/// montre le jour et les valeurs.
class Courbes extends StatelessWidget {
  /// Premier jour des séries.
  final DateTime debut;
  final List<double?> a;
  final Color couleurA;
  final String nomA;
  final List<double?>? b;
  final Color? couleurB;
  final String? nomB;
  final double t;
  final double hauteur;

  /// Mini-courbe (sans axes ni toucher), pour les cartes.
  final bool mini;

  const Courbes({
    super.key,
    required this.debut,
    required this.a,
    required this.couleurA,
    required this.nomA,
    this.b,
    this.couleurB,
    this.nomB,
    required this.t,
    this.hauteur = 190,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final teintes = Teintes.de(context);
    final n = a.length;
    final donnees = LineChartData(
      minX: 0,
      maxX: (n - 1).toDouble(),
      minY: -0.04,
      maxY: 1.04,
      clipData: const FlClipData.all(),
      lineBarsData: [
        _ligne(a, couleurA, aire: true),
        if (b != null) _ligne(b!, couleurB ?? teintes.moinsBonne, aire: false),
      ],
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: !mini,
        drawVerticalLine: false,
        horizontalInterval: 0.5,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: teintes.trait, strokeWidth: 1, dashArray: [4, 6]),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: !mini,
            reservedSize: 24,
            interval: 1,
            getTitlesWidget: (valeur, meta) {
              final jour = ajouteJours(debut, valeur.round());
              if (jour.day != 1 || valeur != valeur.roundToDouble()) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  moisCourts[jour.month - 1],
                  style: TextStyle(color: teintes.doux, fontSize: 11),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: !mini,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => teintes.barre,
          tooltipBorderRadius: BorderRadius.circular(14),
          fitInsideHorizontally: true,
          getTooltipItems: (touches) => [
            for (final (i, s) in touches.indexed)
              LineTooltipItem(
                '${i == 0 ? '${dateCourte(ajouteJours(debut, s.x.round()))}\n' : ''}'
                '${s.barIndex == 0 ? nomA : nomB} : ${(s.y * 100).round()} %',
                TextStyle(
                  color: s.barIndex == 0
                      ? couleurA
                      : (couleurB ?? teintes.moinsBonne),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        getTouchedSpotIndicator: (barre, indices) => [
          for (final _ in indices)
            TouchedSpotIndicatorData(
              FlLine(color: teintes.doux, strokeWidth: 1, dashArray: [3, 4]),
              FlDotData(
                getDotPainter: (spot, _, b, _) => FlDotCirclePainter(
                  radius: 5,
                  color: b.color ?? couleurA,
                  strokeWidth: 2,
                  strokeColor: teintes.carte,
                ),
              ),
            ),
        ],
      ),
    );
    return SizedBox(
      height: hauteur,
      child: ClipRect(
        clipper: _ClipGauche(t),
        child: LineChart(donnees, duration: Duration.zero),
      ),
    );
  }
}

/// Légende d'une ou deux courbes.
class LegendeCourbes extends StatelessWidget {
  final List<(String, Color)> courbes;

  const LegendeCourbes(this.courbes, {super.key});

  @override
  Widget build(BuildContext context) {
    final teintes = Teintes.de(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (nom, couleur) in courbes)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 4,
                decoration: ShapeDecoration(
                  color: couleur,
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  nom,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: teintes.doux,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Anneau des réponses (la moins bonne en premier, dans le sens des
/// aiguilles), qui se remplit ; au centre, la part de la meilleure.
class Anneau extends StatelessWidget {
  final Question question;
  final Bilan bilan;
  final double t;
  final double taille;

  const Anneau({
    super.key,
    required this.question,
    required this.bilan,
    required this.t,
    this.taille = 120,
  });

  @override
  Widget build(BuildContext context) {
    final teintes = Teintes.de(context);
    final total = bilan.total;
    final epaisseur = taille * 0.16;
    final sections = <PieChartSectionData>[
      if (total == 0)
        PieChartSectionData(
          value: 1,
          color: teintes.puce,
          radius: epaisseur,
          showTitle: false,
        )
      else ...[
        for (var i = question.nbReponses - 1; i >= 0; i--)
          if (bilan.comptes[i] > 0)
            PieChartSectionData(
              value: bilan.comptes[i] * t,
              color: AppTheme.couleurReponse(context, i, question.nbReponses),
              radius: epaisseur,
              showTitle: false,
            ),
        if (t < 1)
          PieChartSectionData(
            value: total * (1 - t),
            color: Colors.transparent,
            radius: epaisseur,
            showTitle: false,
          ),
      ],
    ];
    return SizedBox(
      width: taille,
      height: taille,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: taille / 2 - epaisseur,
              sectionsSpace: total == 0 ? 0 : 2,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(enabled: false),
            ),
            duration: Duration.zero,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total == 0
                    ? '—'
                    : '${(bilan.partMeilleure! * 100 * t).round()} %',
                style: TextStyle(
                  fontFamily: AppTheme.policeTitre,
                  fontSize: taille * 0.17,
                  fontWeight: FontWeight.w700,
                  color: teintes.texte,
                ),
              ),
              if (taille >= 100)
                Text(
                  question.reponses[0],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: teintes.doux, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barres arrondies qui montent : la part de la meilleure réponse pour
/// chaque étiquette (jours de la semaine…).
class Barres extends StatelessWidget {
  final List<double?> valeurs;
  final List<String> etiquettes;
  final double t;
  final double hauteur;

  const Barres({
    super.key,
    required this.valeurs,
    required this.etiquettes,
    required this.t,
    this.hauteur = 150,
  });

  @override
  Widget build(BuildContext context) {
    final teintes = Teintes.de(context);
    return SizedBox(
      height: hauteur,
      child: BarChart(
        BarChartData(
          maxY: 1,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    etiquettes[v.toInt()],
                    style: TextStyle(color: teintes.doux, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          barGroups: [
            for (final (i, v) in valeurs.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: math.max(0.02, (v ?? 0) * t),
                    width: 22,
                    borderRadius: BorderRadius.circular(11),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        teintes.meilleure.withValues(alpha: 0.55),
                        teintes.meilleure,
                      ],
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 1,
                      color: teintes.puce,
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

/// Nuage de points (une semaine par point, ou un jour) et sa droite de
/// tendance.
class Nuage extends StatelessWidget {
  final List<({double x, double y, DateTime lundi})> points;
  final String nomX;
  final String nomY;
  final double t;

  /// Bulle d'un point : « Semaine du … » par défaut.
  final String Function(({double x, double y, DateTime lundi}) point)? bulle;

  const Nuage({
    super.key,
    required this.points,
    required this.nomX,
    required this.nomY,
    required this.t,
    this.bulle,
  });

  @override
  Widget build(BuildContext context) {
    final teintes = Teintes.de(context);
    final tendance = droite([for (final p in points) (x: p.x, y: p.y)]);
    final donnees = LineChartData(
      minX: -0.05,
      maxX: 1.05,
      minY: -0.05,
      maxY: 1.05,
      borderData: FlBorderData(show: false),
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        drawVerticalLine: true,
        horizontalInterval: 0.25,
        verticalInterval: 0.25,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: teintes.trait, strokeWidth: 1),
        getDrawingVerticalLine: (_) =>
            FlLine(color: teintes.trait, strokeWidth: 1),
      ),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(),
        rightTitles: AxisTitles(),
        leftTitles: AxisTitles(),
        bottomTitles: AxisTitles(),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => teintes.barre,
          tooltipBorderRadius: BorderRadius.circular(14),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (touches) => [
            for (final s in touches)
              s.barIndex == 0
                  ? LineTooltipItem(
                      bulle?.call(points[s.spotIndex]) ??
                          'Semaine du ${dateCourte(points[s.spotIndex].lundi)}'
                              '\n$nomX ${(s.x * 100).round()} % · '
                              '$nomY ${(s.y * 100).round()} %',
                      TextStyle(
                        color: teintes.texte,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [for (final p in points) FlSpot(p.x, p.y)],
          barWidth: 0,
          color: Colors.transparent,
          dotData: FlDotData(
            getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
              // Plus petits quand ils sont nombreux (un point par jour).
              radius:
                  (points.length > 40 ? 4.5 : 7) *
                  Curves.easeOutBack.transform(
                    ((t * points.length - i * 0.5) / 2).clamp(0.0, 1.0),
                  ),
              color: teintes.meilleure.withValues(alpha: 0.75),
              strokeWidth: 0,
            ),
          ),
        ),
        if (tendance != null)
          LineChartBarData(
            spots: [
              FlSpot(0, tendance.origine),
              FlSpot(t, tendance.origine + tendance.pente * t),
            ],
            color: teintes.texte.withValues(alpha: 0.7),
            barWidth: 2,
            dashArray: [6, 6],
            dotData: const FlDotData(show: false),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RotatedBox(
              quarterTurns: 3,
              child: Text(
                '$nomY →',
                style: TextStyle(color: teintes.doux, fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.3,
                child: LineChart(donnees, duration: Duration.zero),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$nomX →',
          textAlign: TextAlign.center,
          style: TextStyle(color: teintes.doux, fontSize: 12),
        ),
      ],
    );
  }
}

/// La grille des derniers mois : un carré par jour, à la couleur de la
/// réponse, colonne par semaine ; elle se remplit de gauche à droite.
class GrilleJours extends StatelessWidget {
  final Question question;
  final Reponses reponses;
  final DateTime aujourdhui;
  final int semaines;
  final double t;

  const GrilleJours({
    super.key,
    required this.question,
    required this.reponses,
    required this.aujourdhui,
    required this.t,
    this.semaines = 26,
  });

  @override
  Widget build(BuildContext context) {
    final teintes = Teintes.de(context);
    final premierLundi = ajouteJours(lundiDe(aujourdhui), -7 * (semaines - 1));
    return LayoutBuilder(
      builder: (context, contraintes) {
        const ecart = 3.0;
        final cote = math.min(
          16.0,
          (contraintes.maxWidth - ecart * (semaines - 1)) / semaines,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 16,
              child: Stack(
                children: [
                  for (var s = 0; s < semaines; s++)
                    if (() {
                      final l = ajouteJours(premierLundi, 7 * s);
                      return l.day <= 7;
                    }())
                      Positioned(
                        left: s * (cote + ecart),
                        child: Text(
                          moisCourts[ajouteJours(premierLundi, 7 * s).month -
                              1],
                          style: TextStyle(color: teintes.doux, fontSize: 10),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var s = 0; s < semaines; s++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: s < semaines - 1 ? ecart : 0,
                    ),
                    child: Opacity(
                      opacity: ((t * (semaines + 2) - s) / 3).clamp(0.0, 1.0),
                      child: Column(
                        children: [
                          for (var d = 0; d < 7; d++)
                            _case(
                              context,
                              ajouteJours(premierLundi, 7 * s + d),
                              cote,
                              ecart,
                              teintes,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _case(
    BuildContext context,
    DateTime jour,
    double cote,
    double ecart,
    Teintes teintes,
  ) {
    final choix = reponses[cleJour(jour)];
    final futur = jour.isAfter(aujourdhui);
    final couleur = futur
        ? Colors.transparent
        : choix == null
        ? (question.revientLe(jour.weekday)
              ? teintes.puce
              : teintes.puce.withValues(alpha: 0.35))
        : AppTheme.couleurReponse(context, choix, question.nbReponses);
    return Container(
      width: cote,
      height: cote,
      margin: EdgeInsets.only(bottom: ecart),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(cote * 0.3),
      ),
    );
  }
}

/// Carte de chaleur : chaque case croise deux questions ; plus elle est
/// vive, plus leurs courbes se ressemblent (citron), ou s'opposent
/// (corail). Toucher une case la choisit.
class CarteChaleur extends StatelessWidget {
  final List<Question> questions;
  final List<Decouverte> ressemblances;
  final double t;
  final void Function(Decouverte d) onChoix;
  final Decouverte? choisie;

  const CarteChaleur({
    super.key,
    required this.questions,
    required this.ressemblances,
    required this.t,
    required this.onChoix,
    this.choisie,
  });

  Decouverte? _paire(Question x, Question y) {
    for (final d in ressemblances) {
      if ((d.a.id == x.id && d.b.id == y.id) ||
          (d.a.id == y.id && d.b.id == x.id)) {
        return d;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final teintes = Teintes.de(context);
    final n = questions.length;
    return LayoutBuilder(
      builder: (context, contraintes) {
        const largeurNom = 110.0, ecart = 4.0;
        final cote = math.min(
          46.0,
          (contraintes.maxWidth - largeurNom - ecart * n) / n,
        );
        return Column(
          children: [
            for (var i = 0; i < n; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: ecart),
                child: Row(
                  children: [
                    SizedBox(
                      width: largeurNom,
                      child: Text(
                        '${i + 1}. ${questions[i].texte}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: teintes.doux,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (var j = 0; j < n; j++) ...[
                      SizedBox(width: ecart),
                      _case(context, i, j, cote, teintes),
                    ],
                  ],
                ),
              ),
            Row(
              children: [
                const SizedBox(width: largeurNom),
                for (var j = 0; j < n; j++) ...[
                  SizedBox(width: ecart),
                  SizedBox(
                    width: cote,
                    child: Text(
                      '${j + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: teintes.doux, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _case(BuildContext context, int i, int j, double cote, Teintes t0) {
    if (i == j) {
      return SizedBox(
        width: cote,
        height: cote,
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: t0.trait, shape: BoxShape.circle),
          ),
        ),
      );
    }
    final d = _paire(questions[i], questions[j]);
    final force = d == null ? 0.0 : d.r.abs().clamp(0.0, 1.0);
    final apparition = ((t * 1.6) - (i + j) * 0.08).clamp(0.0, 1.0);
    final base = d == null
        ? t0.puce
        : (d.inverse ? t0.moinsBonne : t0.meilleure);
    final couleur = d == null
        ? t0.puce
        : Color.lerp(t0.puce, base, (0.15 + force * 1.2).clamp(0.0, 1.0))!;
    final estChoisie =
        choisie != null &&
        d != null &&
        choisie!.a.id == d.a.id &&
        choisie!.b.id == d.b.id;
    return Transform.scale(
      scale: 0.6 + 0.4 * apparition,
      child: Opacity(
        opacity: apparition,
        child: Material(
          color: couleur,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cote * 0.3),
            side: estChoisie
                ? BorderSide(color: t0.texte, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cote * 0.3),
            ),
            onTap: d == null ? null : () => onChoix(d),
            child: SizedBox(
              width: cote,
              height: cote,
              child: d == null || force < 0.2
                  ? null
                  : Center(
                      child: Text(
                        '${(d.r.abs() * 100).round()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: force > 0.45
                              ? const Color(0xFF111114)
                              : t0.texte,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
