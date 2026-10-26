import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/a_faire.dart';
import '../models/question.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/courbes.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/stats.dart';
import '../widgets/cases.dart';
import '../widgets/graphiques.dart';
import '../widgets/rond.dart';
import 'fiche_question_screen.dart';

/// Les stats en graphiques (demande de Paul du 23/10/2026 : l'outil
/// trouve les liens tout seul, des courbes à comparer, des graphiques
/// modernes et animés) : découvertes automatiques, comparateur de
/// courbes avec décalage, nuage de points, carte de chaleur de tous les
/// liens, le planning, puis chaque question en mini-courbe et anneau.
///
/// Le planning compte comme une courbe de plus (la part faite chaque
/// jour) : l'appli cherche aussi ses liens avec les questions.
class StatsScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const StatsScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _decouvertesMontrees = 4;

  List<Question> _questions = const [];

  /// Les questions, et le planning s'il a des réponses : tout ce qui se
  /// compare.
  List<Question> _courbes = const [];
  Map<int, Reponses> _reponses = const {};
  List<Tache> _taches = const [];
  List<AFaire> _liste = const [];
  List<Decouverte> _ressemblances = const [];
  List<Decouverte> _decouvertes = const [];

  /// Comparateur : la courbe A, la courbe B décalée de `_decalage` jours.
  int? _idA;
  int? _idB;
  int _decalage = 0;
  int _periode = 91;

  final _cleComparateur = GlobalKey();

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
    final questions = await widget.base.questions();
    final reponses = await widget.base.toutesLesReponses();
    final taches = await widget.base.taches();
    final liste = await widget.base.liste();
    if (!mounted) return;
    final planning = reponsesPlanning(taches);
    if (planning.isNotEmpty) reponses[idPlanning] = planning;
    final courbes = [...questions, if (planning.isNotEmpty) questionPlanning];
    final ressemblances = toutesLesRessemblances(courbes, reponses);
    setState(() {
      _questions = questions;
      _courbes = courbes;
      _taches = taches;
      _liste = liste;
      _reponses = reponses;
      _ressemblances = ressemblances;
      _decouvertes = [
        for (final d in ressemblances)
          if (d.r.abs() >= seuilDecouverte) d,
      ];
      final ids = {for (final q in courbes) q.id};
      if (!ids.contains(_idA) || !ids.contains(_idB) || _idA == _idB) {
        if (_decouvertes.isNotEmpty) {
          _choisit(_decouvertes.first);
        } else if (courbes.length >= 2) {
          _idA = courbes[0].id;
          _idB = courbes[1].id;
          _decalage = 0;
        }
      }
    });
  }

  void _choisit(Decouverte d) {
    _idA = d.a.id;
    _idB = d.b.id;
    _decalage = d.decalage;
  }

  Question? _question(int? id) {
    for (final q in _courbes) {
      if (q.id == id) return q;
    }
    return null;
  }

  DateTime get _aujourdhui => jourDe(widget.maintenant());

  /// Courbe lissée d'une question sur `jours` jours, décalée de
  /// `decalage` (la valeur montrée un jour est celle de `decalage` jours
  /// plus tard), éventuellement inversée.
  List<double?> _courbe(
    Question q,
    int jours, {
    int decalage = 0,
    bool inverse = false,
  }) {
    final debut = ajouteJours(_aujourdhui, -(jours - 1));
    final notes = notesParJour(
      q,
      _reponses[q.id] ?? const {},
      ajouteJours(debut, decalage - 6),
      ajouteJours(_aujourdhui, decalage),
    );
    final lisse = moyenneGlissante(notes).sublist(6);
    return [for (final v in lisse) v == null ? null : (inverse ? 1 - v : v)];
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 22, 6, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GrandTitre('Stats'),
                  const SizedBox(height: 4),
                  Text(
                    'Ce que le Décideur apprend de l\'Exécutant.',
                    style: TextStyle(
                      color: Teintes.de(context).doux,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const _Section('Découvertes'),
            if (_decouvertes.isEmpty)
              CarteRonde(
                child: Text(
                  'Ouinon compare toutes tes questions entre elles, le même '
                  'jour et avec 1 à 3 jours de décalage. Les premières '
                  'découvertes arrivent après $minJoursCourbes jours de '
                  'réponses.',
                  style: doux,
                ),
              )
            else
              for (final d in _decouvertes.take(_decouvertesMontrees))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CarteDecouverte(
                    decouverte: d,
                    debut: ajouteJours(_aujourdhui, -90),
                    a: _courbe(d.a, 91),
                    b: _courbe(
                      d.b,
                      91,
                      decalage: d.decalage,
                      inverse: d.inverse,
                    ),
                    onTap: () => _ouvreComparateur(d),
                  ),
                ),
            const SizedBox(height: 18),
            _Section('Comparer deux courbes', cle: _cleComparateur),
            if (_courbes.length < 2)
              CarteRonde(
                child: Text(
                  'Il faut au moins deux questions pour comparer.',
                  style: doux,
                ),
              )
            else
              _comparateur(context),
            const SizedBox(height: 18),
            if (_courbes.length >= 2) ...[
              const _Section('Tous les liens'),
              CarteRonde(
                child: AnimeQuandVisible(
                  builder: (context, avance) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CarteChaleur(
                        questions: _courbes,
                        ressemblances: _ressemblances,
                        t: avance,
                        choisie: _paireChoisie(),
                        onChoix: _ouvreComparateur,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Citron : même courbe. Corail : à l\'inverse. Plus '
                        'c\'est vif, plus c\'est net. Touche une case pour '
                        'comparer.',
                        style: doux.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_taches.isNotEmpty) ...[
              const _Section('Ton planning'),
              ..._planning(context),
              const SizedBox(height: 8),
            ],
            const _Section('Tes questions'),
            for (final q in _questions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CarteQuestion(
                  question: q,
                  courbe: _courbe(q, 91),
                  debut: ajouteJours(_aujourdhui, -90),
                  bilan: bilan(
                    q,
                    _reponses[q.id] ?? const {},
                    debut: ajouteJours(_aujourdhui, -90),
                    fin: _aujourdhui,
                  ),
                  serie: serie(q, _reponses[q.id] ?? const {}, _aujourdhui),
                  onTap: () => Navigator.push(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
              child: Text(
                'Des coïncidences observées dans tes réponses, pas des '
                'causes.',
                style: doux.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Decouverte? _paireChoisie() {
    for (final d in _ressemblances) {
      if ((d.a.id == _idA && d.b.id == _idB) ||
          (d.a.id == _idB && d.b.id == _idA)) {
        return d;
      }
    }
    return null;
  }

  void _ouvreComparateur(Decouverte d) {
    setState(() => _choisit(d));
    final contexte = _cleComparateur.currentContext;
    if (contexte != null) {
      Scrollable.ensureVisible(
        contexte,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Le planning : part faite sur 30 jours, sa courbe, selon le moment
  /// et le jour, la charge de la journée, et ce qui est le plus reporté.
  List<Widget> _planning(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux, fontSize: 13, height: 1.35);
    const titre = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);
    final passees = [
      for (final tache in _taches)
        if (!tache.jour.isAfter(_aujourdhui)) tache,
    ];
    final mois = [
      for (final tache in passees)
        if (!tache.jour.isBefore(ajouteJours(_aujourdhui, -29))) tache,
    ];
    final c = compte(mois);
    final important = partTempsImportant(mois);
    final avecCase = passees.any((t) => t.quadrant != null);
    final attente = [
      for (final a in _liste)
        if (ecartJours(a.creeLe, _aujourdhui) >= 1) a,
    ]..sort((x, y) => x.creeLe.compareTo(y.creeLe));
    final reportees = plusReportees(passees);
    final charge = pointsCharge(passees);
    Widget carte(Widget enfant) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CarteRonde(child: enfant),
    );
    Widget ligne(Color couleur, String texte, int n) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text('$n', style: TextStyle(color: t.doux)),
        ],
      ),
    );
    return [
      carte(
        AnimeQuandVisible(
          builder: (context, avance) => Row(
            children: [
              Anneau(
                question: reponsesTache,
                bilan: Bilan([c.faits, c.pasFaits]),
                t: avance,
                taille: 124,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('30 derniers jours', style: titre),
                    const SizedBox(height: 6),
                    ligne(t.meilleure, 'Fait', c.faits),
                    ligne(t.moinsBonne, 'Pas fait', c.pasFaits),
                    ligne(t.puce, 'Sans réponse', c.sansReponse),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (_reponses[idPlanning] != null)
        carte(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('La courbe', style: titre),
              const SizedBox(height: 4),
              Text('Part faite chaque jour, moyenne sur 7 jours.', style: doux),
              const SizedBox(height: 12),
              AnimeQuandVisible(
                builder: (context, avance) => Courbes(
                  debut: ajouteJours(_aujourdhui, -90),
                  a: _courbe(questionPlanning, 91),
                  couleurA: t.meilleure,
                  nomA: 'Planning',
                  t: avance,
                ),
              ),
            ],
          ),
        ),
      carte(
        AnimeQuandVisible(
          builder: (context, avance) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Selon le moment', style: titre),
              const SizedBox(height: 4),
              Text(
                'Part faite le matin, l\'après-midi (dès midi) et le soir '
                '(dès 18 h).',
                style: doux,
              ),
              const SizedBox(height: 12),
              Barres(
                valeurs: partParMoment(passees),
                etiquettes: moments,
                t: avance,
                hauteur: 130,
              ),
              const SizedBox(height: 18),
              const Text('Selon le jour', style: titre),
              const SizedBox(height: 12),
              Barres(
                valeurs: partParJourSemaine(passees),
                etiquettes: initialesJours,
                t: avance,
                hauteur: 130,
              ),
            ],
          ),
        ),
      ),
      if (charge.length >= 3)
        carte(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Journées chargées', style: titre),
              const SizedBox(height: 4),
              Text(
                'Un point par jour : à droite, plus d\'heures prévues ; en '
                'haut, plus de choses faites.',
                style: doux,
              ),
              const SizedBox(height: 10),
              AnimeQuandVisible(
                builder: (context, avance) => Nuage(
                  points: charge,
                  nomX: 'Heures prévues (0 à $heuresMaxCharge h)',
                  nomY: 'Fait',
                  t: avance,
                  bulle: (p) =>
                      '${dateCourte(p.lundi)}\n'
                      '${dureeFr((p.x * heuresMaxCharge * 60).round())} '
                      'prévues · ${(p.y * 100).round()} % fait',
                ),
              ),
            ],
          ),
        ),
      if (avecCase)
        carte(
          AnimeQuandVisible(
            builder: (context, avance) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Les 4 cases', style: titre),
                if (important != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${(important * 100 * avance).round()} %',
                        style: TextStyle(
                          fontFamily: AppTheme.policeTitre,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: t.meilleure,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'du temps fait sur ta liste est allé à « À '
                          'planifier » (important, pas urgent), sur 30 jours.',
                          style: doux.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text('Part faite selon la case.', style: doux),
                const SizedBox(height: 12),
                Barres(
                  valeurs: partParCase(passees),
                  etiquettes: const [
                    'D\'abord',
                    'À planifier',
                    'Vite fait',
                    'Peut-être',
                  ],
                  t: avance,
                  hauteur: 130,
                ),
              ],
            ),
          ),
        ),
      if (attente.isNotEmpty)
        carte(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Ce qui attend le plus', style: titre),
              const SizedBox(height: 8),
              for (final a in attente.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: couleurCase(context, a.caseLe(_aujourdhui)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.texte,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Pastille('Depuis ${ecartJours(a.creeLe, _aujourdhui)} j'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (reportees.isNotEmpty)
        carte(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Le plus reporté', style: titre),
              const SizedBox(height: 8),
              for (final r in reportees)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.texte,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Pastille('${r.fois} fois'),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _comparateur(BuildContext context) {
    final t = Teintes.de(context);
    final a = _question(_idA);
    final b = _question(_idB);
    Widget choix(String titre, String cle, int? valeur, ValueChanged<int> f) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre,
              style: TextStyle(color: t.doux, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in _courbes)
                  PiluleChoix(
                    q.texte,
                    key: ValueKey('$cle-${q.id}'),
                    choisie: q.id == valeur,
                    onTap: () => f(q.id!),
                  ),
              ],
            ),
          ],
        );
    final res = a == null || b == null || a.id == b.id
        ? null
        : ressemblance(
            _reponses[a.id] ?? const {},
            a,
            _reponses[b.id] ?? const {},
            b,
            _decalage,
          );
    final debut = ajouteJours(_aujourdhui, -(_periode - 1));
    return CarteRonde(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          choix('Courbe 1', 'a', _idA, (id) => setState(() => _idA = id)),
          const SizedBox(height: 12),
          choix('Courbe 2', 'b', _idB, (id) => setState(() => _idB = id)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _decalage == 0
                      ? 'Le même jour'
                      : 'Courbe 2 décalée de $_decalage '
                            'jour${_decalage > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: t.accent,
              inactiveTrackColor: t.puce,
              thumbColor: t.accent,
              overlayColor: t.accent.withValues(alpha: 0.15),
              trackHeight: 6,
            ),
            child: Slider(
              value: _decalage.toDouble(),
              min: 0,
              max: decalageMax.toDouble(),
              divisions: decalageMax,
              onChanged: (v) => setState(() => _decalage = v.round()),
            ),
          ),
          ChoixPilules<int>(
            options: const [(30, '1 mois'), (91, '3 mois'), (182, '6 mois')],
            valeur: _periode,
            onChoix: (p) => setState(() => _periode = p),
          ),
          const SizedBox(height: 16),
          if (a == null || b == null || a.id == b.id)
            Text(
              'Choisis deux questions différentes.',
              style: TextStyle(color: t.doux),
            )
          else ...[
            _Ressemblance(res: res),
            const SizedBox(height: 12),
            AnimeQuandVisible(
              key: ValueKey('comparer-${a.id}-${b.id}-$_decalage-$_periode'),
              builder: (context, avance) => Courbes(
                debut: debut,
                a: _courbe(a, _periode),
                couleurA: t.meilleure,
                nomA: a.texte,
                b: _courbe(b, _periode, decalage: _decalage),
                couleurB: AppTheme.courbeB,
                nomB: b.texte,
                t: avance,
                hauteur: 210,
              ),
            ),
            const SizedBox(height: 10),
            LegendeCourbes([
              (a.texte, t.meilleure),
              (
                _decalage == 0 ? b.texte : '${b.texte} (+$_decalage j)',
                AppTheme.courbeB,
              ),
            ]),
            const SizedBox(height: 22),
            const Text(
              'Semaine par semaine',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Un point par semaine : plus il est haut et à droite, plus les '
              'deux ont été bonnes.',
              style: TextStyle(color: t.doux, fontSize: 13),
            ),
            const SizedBox(height: 10),
            AnimeQuandVisible(
              key: ValueKey('nuage-${a.id}-${b.id}-$_decalage-$_periode'),
              builder: (context, avance) => Nuage(
                points: pointsParSemaine(
                  a,
                  _reponses[a.id] ?? const {},
                  b,
                  _reponses[b.id] ?? const {},
                  debut,
                  _aujourdhui,
                  decalage: _decalage,
                ),
                nomX: a.texte,
                nomY: b.texte,
                t: avance,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// La ressemblance des deux courbes, en grand chiffre et en jauge.
class _Ressemblance extends StatelessWidget {
  final ({double r, int jours})? res;

  const _Ressemblance({required this.res});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final r = res;
    if (r == null) {
      return Text(
        'Pas encore assez de jours en commun ($minJoursCourbes au moins).',
        style: TextStyle(color: t.doux),
      );
    }
    final inverse = r.r < 0;
    final force = r.r.abs();
    return Row(
      children: [
        Text(
          '${(force * 100).round()} %',
          style: TextStyle(
            fontFamily: AppTheme.policeTitre,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: inverse ? t.moinsBonne : t.meilleure,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inverse ? 'de ressemblance, à l\'inverse' : 'de ressemblance',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                'sur ${r.jours} jours',
                style: TextStyle(color: t.doux, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une découverte : les deux questions, la phrase, et les deux courbes
/// superposées (la seconde déjà décalée, et retournée si elle va à
/// l'inverse) qui se dessinent quand on s'arrête dessus.
class _CarteDecouverte extends StatelessWidget {
  final Decouverte decouverte;
  final DateTime debut;
  final List<double?> a;
  final List<double?> b;
  final VoidCallback onTap;

  const _CarteDecouverte({
    required this.decouverte,
    required this.debut,
    required this.a,
    required this.b,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final d = decouverte;
    final nomB = d.inverse ? '${d.b.texte} (inversé)' : d.b.texte;
    return CarteRonde(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  phraseDecouverte(d),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Pastille(
                d.fort ? 'Lien fort' : 'Lien net',
                fond: d.fort ? t.accent : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          LegendeCourbes([(d.a.texte, t.meilleure), (nomB, AppTheme.courbeB)]),
          const SizedBox(height: 12),
          AnimeQuandVisible(
            builder: (context, avance) => Courbes(
              debut: debut,
              a: a,
              couleurA: t.meilleure,
              nomA: d.a.texte,
              b: b,
              couleurB: AppTheme.courbeB,
              nomB: nomB,
              t: avance,
              hauteur: 170,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(d.r.abs() * 100).round()} % de ressemblance, sur ${d.jours} '
            'jours. Touche pour comparer.',
            style: TextStyle(color: t.doux, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Une question : mini-courbe des 3 derniers mois et anneau des réponses.
class _CarteQuestion extends StatelessWidget {
  final Question question;
  final List<double?> courbe;
  final DateTime debut;
  final Bilan bilan;
  final Serie serie;
  final VoidCallback onTap;

  const _CarteQuestion({
    required this.question,
    required this.courbe,
    required this.debut,
    required this.bilan,
    required this.serie,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return CarteRonde(
      onTap: onTap,
      child: AnimeQuandVisible(
        builder: (context, avance) => Row(
          children: [
            Anneau(question: question, bilan: bilan, t: avance, taille: 74),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          question.texte,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (serie.actuelle >= 2) PastilleSerie(serie.actuelle),
                      Icon(Icons.chevron_right_rounded, color: t.doux),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Courbes(
                    debut: debut,
                    a: courbe,
                    couleurA: t.meilleure,
                    nomA: question.texte,
                    t: avance,
                    hauteur: 48,
                    mini: true,
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

/// Intertitre de section.
class _Section extends StatelessWidget {
  final String texte;
  final Key? cle;

  const _Section(this.texte, {this.cle});

  @override
  Widget build(BuildContext context) => Padding(
    key: cle,
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
    child: Text(texte, style: Theme.of(context).textTheme.titleLarge),
  );
}
