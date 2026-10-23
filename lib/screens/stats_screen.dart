import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../utils/jour.dart';
import '../utils/stats.dart';
import '../theme/app_theme.dart';
import '../widgets/barres.dart';
import '../widgets/rond.dart';
import 'fiche_question_screen.dart';

/// Les stats, centrées sur les croisements (demande de Paul du
/// 23/10/2026) : un croiseur libre de deux questions, les liens les plus
/// nets trouvés tout seuls, puis une ligne par question.
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
  static const _liensMontres = 5;

  List<Question> _questions = const [];
  Map<int, Reponses> _reponses = const {};
  List<Lien> _liens = const [];
  bool _tousLesLiens = false;

  /// Le croiseur : « si » A, « alors » B, le même jour ou le lendemain.
  int? _idA;
  int? _idB;
  int _decalage = 0;

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
    if (!mounted) return;
    final trouves = liens(questions, reponses);
    setState(() {
      _questions = questions;
      _reponses = reponses;
      _liens = trouves;
      final ids = {for (final q in questions) q.id};
      // Au départ : le lien le plus net, sinon les deux premières.
      if (!ids.contains(_idA) || !ids.contains(_idB) || _idA == _idB) {
        if (trouves.isNotEmpty) {
          _idA = trouves.first.a.id;
          _idB = trouves.first.b.id;
          _decalage = trouves.first.decalage;
        } else if (questions.length >= 2) {
          _idA = questions[0].id;
          _idB = questions[1].id;
        } else {
          _idA = _idB = null;
        }
      }
    });
  }

  Question? _question(int? id) {
    for (final q in _questions) {
      if (q.id == id) return q;
    }
    return null;
  }

  void _montre(Lien l) => setState(() {
    _idA = l.a.id;
    _idB = l.b.id;
    _decalage = l.decalage;
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux);
    final aujourdhui = jourDe(widget.maintenant());
    final liensMontres = _tousLesLiens
        ? _liens
        : _liens.take(_liensMontres).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 22, 6, 18),
              child: GrandTitre('Stats'),
            ),
            const _Section('Croiser deux questions'),
            if (_questions.length < 2)
              CarteRonde(
                child: Text(
                  'Il faut au moins deux questions pour les croiser.',
                  style: doux,
                ),
              )
            else
              _croiseur(context),
            const SizedBox(height: 22),
            const _Section('Les liens les plus nets'),
            if (_liens.isEmpty)
              CarteRonde(
                child: Text(
                  'Ils apparaissent après $minJoursCommuns jours de réponses, '
                  'quand un écart net se dessine.',
                  style: doux,
                ),
              )
            else ...[
              for (final l in liensMontres)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CarteLien(lien: l, onTap: () => _montre(l)),
                ),
              if (_liens.length > _liensMontres)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _tousLesLiens = !_tousLesLiens),
                    child: Text(
                      _tousLesLiens
                          ? 'Voir moins'
                          : 'Voir les ${_liens.length} liens',
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 22),
            const _Section('Par question, 30 jours'),
            CarteRonde(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final q in _questions)
                    _LigneQuestion(
                      question: q,
                      bilan: bilan(
                        q,
                        _reponses[q.id] ?? const {},
                        debut: ajouteJours(aujourdhui, -29),
                        fin: aujourdhui,
                      ),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
              child: Text(
                'Des coïncidences observées, pas des causes.',
                style: doux.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Choix de A, de B et du décalage, puis une barre de B par réponse de A.
  Widget _croiseur(BuildContext context) {
    final t = Teintes.de(context);
    final a = _question(_idA);
    final b = _question(_idB);
    Widget choix(
      String titre,
      String cle,
      int? valeur,
      ValueChanged<int> onChoix,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: TextStyle(color: t.doux, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        // Toutes les questions visibles, sur plusieurs lignes au besoin.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final q in _questions)
              PiluleChoix(
                q.texte,
                key: ValueKey('$cle-${q.id}'),
                choisie: q.id == valeur,
                onTap: () => onChoix(q.id!),
              ),
          ],
        ),
      ],
    );
    final lignes = a == null || b == null
        ? const <Bilan>[]
        : croisement(
            a,
            b,
            _decalage,
            _reponses[a.id] ?? const {},
            _reponses[b.id] ?? const {},
          );
    final total = lignes.fold(0, (n, l) => n + l.total);
    return CarteRonde(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          choix('Quand', 'a', _idA, (id) => setState(() => _idA = id)),
          const SizedBox(height: 12),
          choix('Regarder', 'b', _idB, (id) => setState(() => _idB = id)),
          const SizedBox(height: 12),
          ChoixPilules<int>(
            options: const [(0, 'Le même jour'), (1, 'Le lendemain')],
            valeur: _decalage,
            onChoix: (d) => setState(() => _decalage = d),
          ),
          const SizedBox(height: 16),
          if (a == null || b == null || a.id == b.id)
            Text(
              'Choisis deux questions différentes.',
              style: TextStyle(color: t.doux),
            )
          else if (total == 0)
            Text(
              'Pas encore de jours où les deux ont une réponse.',
              style: TextStyle(color: t.doux),
            )
          else ...[
            for (var i = 0; i < a.nbReponses; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LigneCroisement(
                  libelle: a.reponses[i],
                  couleur: AppTheme.couleurReponse(context, i, a.nbReponses),
                  question: b,
                  bilan: lignes[i],
                ),
              ),
            _Legende(question: b),
            const SizedBox(height: 6),
            Text(
              'Sur $total jour${total > 1 ? 's' : ''}.',
              style: TextStyle(color: t.doux, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// « Si A = telle réponse » : la barre des réponses de B ces jours-là.
class _LigneCroisement extends StatelessWidget {
  final String libelle;
  final Color couleur;
  final Question question;
  final Bilan bilan;

  const _LigneCroisement({
    required this.libelle,
    required this.couleur,
    required this.question,
    required this.bilan,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                libelle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              bilan.total == 0
                  ? '—'
                  : '${(100 * bilan.partMeilleure!).round()} % '
                        '« ${question.reponses[0]} »',
              style: TextStyle(color: t.doux, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        BarreBilan(question: question, bilan: bilan, hauteur: 16),
      ],
    );
  }
}

/// Les couleurs des réponses d'une question, dans l'ordre des barres.
class _Legende extends StatelessWidget {
  final Question question;

  const _Legende({required this.question});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (var i = question.nbReponses - 1; i >= 0; i--)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.couleurReponse(
                    context,
                    i,
                    question.nbReponses,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                question.reponses[i],
                style: TextStyle(color: t.doux, fontSize: 13),
              ),
            ],
          ),
      ],
    );
  }
}

/// Un lien trouvé : les deux réponses en pastilles, puis « avec » et
/// « sans » en barres.
class _CarteLien extends StatelessWidget {
  final Lien lien;
  final VoidCallback onTap;

  const _CarteLien({required this.lien, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = lien.a;
    final b = lien.b;
    final vert = AppTheme.couleurReponse(context, 0, 2);
    return CarteRonde(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pastille('${a.texte} ${a.reponses[0]}', fond: vert),
              Icon(Icons.arrow_forward_rounded, size: 18, color: t.doux),
              Pastille('${b.texte} ${b.reponses[0]}', fond: vert),
              Pastille(lien.decalage == 0 ? 'même jour' : 'lendemain'),
            ],
          ),
          const SizedBox(height: 14),
          _BarreComparaison(
            libelle: 'Avec',
            part: lien.avec,
            couleur: vert,
            jours: lien.joursAvec,
          ),
          const SizedBox(height: 8),
          _BarreComparaison(
            libelle: 'Sans',
            part: lien.sans,
            couleur: t.doux,
            jours: lien.joursSans,
          ),
        ],
      ),
    );
  }
}

class _BarreComparaison extends StatelessWidget {
  final String libelle;
  final double part;
  final Color couleur;
  final int jours;

  const _BarreComparaison({
    required this.libelle,
    required this.part,
    required this.couleur,
    required this.jours,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      label: '$libelle : ${(part * 100).round()} %, sur $jours jours',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              libelle,
              style: TextStyle(color: t.doux, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: t.puce)),
                    FractionallySizedBox(
                      widthFactor: part.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: ColoredBox(color: couleur),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${(part * 100).round()} %',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une question : son nom et sa barre des 30 derniers jours.
class _LigneQuestion extends StatelessWidget {
  final Question question;
  final Bilan bilan;
  final VoidCallback onTap;

  const _LigneQuestion({
    required this.question,
    required this.bilan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                question.texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BarreBilan(question: question, bilan: bilan, hauteur: 12),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                '${bilan.total}',
                textAlign: TextAlign.right,
                style: TextStyle(color: t.doux, fontSize: 13),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.doux),
          ],
        ),
      ),
    );
  }
}

/// Intertitre de section.
class _Section extends StatelessWidget {
  final String texte;

  const _Section(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
    child: Text(texte, style: Theme.of(context).textTheme.titleLarge),
  );
}
