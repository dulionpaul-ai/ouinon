import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../models/a_faire.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../widgets/bloc_tache.dart';
import '../widgets/cases.dart';
import '../widgets/rond.dart';
import 'edition_a_faire_screen.dart';
import 'edition_tache_screen.dart';

/// Les trois vues de l'onglet « À faire ».
enum VuePlanning { liste, aujourdhui, demain }

/// L'onglet « À faire » (idées de Paul du 24/10/2026) :
/// - **Liste** : tout ce qu'il y a à faire, avec le temps que ça prend,
///   rangé dans les 4 cases d'Eisenhower ;
/// - **Demain** (et **Aujourd'hui**) : la journée en blocs horaires. On y
///   pose ses impératifs, puis « Remplir ma journée » place la liste dans
///   les trous ; ou on place une chose d'un toucher.
///
/// Ce qui n'est pas fait revient de lui-même « à placer » ; les impératifs
/// pas faits se remettent au lendemain d'un toucher.
class PlanningScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  /// Vue au départ.
  final VuePlanning vue;

  const PlanningScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
    this.vue = VuePlanning.demain,
  });

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  late VuePlanning _vue = widget.vue;
  List<Tache> _duJour = const [];
  List<Tache> _lendemain = const [];
  List<AFaire> _liste = const [];
  Map<int, Tache> _placees = const {};
  ({int debut, int fin}) _journee = (
    debut: Preferences.debutJourneeParDefaut,
    fin: Preferences.finJourneeParDefaut,
  );

  /// Part faite habituelle (dès 14 jours de planning répondus).
  double? _partHabituelle;
  bool _charge = false;
  final _clesCases = {for (final c in Case.values) c: GlobalKey()};

  DateTime get _aujourdhui => jourDe(widget.maintenant());
  bool get _demain => _vue == VuePlanning.demain;
  DateTime get _jour => _demain ? ajouteJours(_aujourdhui, 1) : _aujourdhui;
  List<Tache> get _taches => _demain ? _lendemain : _duJour;

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
    final duJour = await widget.base.tachesDu(_aujourdhui);
    final lendemain = await widget.base.tachesDu(ajouteJours(_aujourdhui, 1));
    final liste = await widget.base.liste();
    final placees = await widget.base.placees(_aujourdhui);
    final journee = await Preferences.journee();
    final passees = [
      for (final t in await widget.base.taches())
        if (t.jour.isBefore(_aujourdhui)) t,
    ];
    final jours = reponsesPlanning(passees).length;
    if (!mounted) return;
    setState(() {
      _duJour = duJour;
      _lendemain = lendemain;
      _liste = liste;
      _placees = placees;
      _journee = journee;
      _partHabituelle = jours >= 14 ? partFaite(passees) : null;
      _charge = true;
    });
  }

  /// Les choses de la liste pas encore placées, dans l'ordre où « Remplir
  /// ma journée » les prendrait (« Peut-être jamais » à la fin).
  List<AFaire> get _aPlacer {
    final libres = [
      for (final a in _liste)
        if (!_placees.containsKey(a.id)) a,
    ];
    final ordre = ordreDePlacement(libres, _jour);
    return [
      ...ordre,
      for (final a in libres)
        if (!ordre.contains(a)) a,
    ];
  }

  /// Impératifs d'aujourd'hui pas faits (ou passés sans réponse), pas déjà
  /// prévus demain.
  List<Tache> get _restes {
    final prevus = {for (final t in _lendemain) t.texte};
    return [
      for (final t in _duJour)
        if (t.imperatif &&
            !prevus.contains(t.texte) &&
            (t.etat == Tache.pasFait ||
                (t.etat == null && !t.quand.isAfter(widget.maintenant()))))
          t,
    ];
  }

  void _ouvreTache([Tache? tache]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionTacheScreen(
        base: widget.base,
        tache: tache,
        jour: _jour,
        maintenant: widget.maintenant,
      ),
    ),
  );

  void _ouvreAFaire([AFaire? a]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionAFaireScreen(
        base: widget.base,
        aFaire: a,
        maintenant: widget.maintenant,
      ),
    ),
  );

  Future<void> _repond(Tache tache, int? etat) async {
    await widget.base.repondTache(tache.id!, etat);
    if (etat != null) {
      try {
        await Notifications.instance.retireTache(tache.id!);
      } catch (_) {}
    }
  }

  Future<void> _remet(List<Tache> taches) async {
    final demain = ajouteJours(_aujourdhui, 1);
    for (final t in taches) {
      await widget.base.enregistreTache(
        Tache(jour: demain, debut: t.debut, duree: t.duree, texte: t.texte),
      );
    }
  }

  /// Place une chose de la liste au premier créneau libre de la journée.
  Future<void> _place(AFaire a) async {
    final debut = premierCreneau(
      a.duree,
      [
        for (final t in _taches)
          if (t.etat != Tache.pasFait) t,
      ],
      depuis: premierDebut(_jour, _journee.debut, widget.maintenant()),
      finJournee: _journee.fin,
    );
    final messager = ScaffoldMessenger.of(context);
    if (debut == null) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            'Pas de créneau de ${dureeFr(a.duree)} entre '
            '${heureFr(_journee.debut)} et ${heureFr(_journee.fin)}.',
          ),
        ),
      );
      return;
    }
    final placee = await widget.base.enregistreTache(
      Tache(
        jour: _jour,
        debut: debut,
        duree: a.duree,
        texte: a.texte,
        listeId: a.id,
        quadrant: a.caseLe(_jour).index,
      ),
    );
    messager.showSnackBar(
      SnackBar(
        content: Text('« ${a.texte} » placé à ${heureFr(debut)}.'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () => widget.base.supprimeTache(placee.id!),
        ),
      ),
    );
  }

  /// « Remplir ma journée » : la proposition, à valider.
  Future<void> _remplit() async {
    final proposition = remplitJournee(
      jour: _jour,
      prevues: _taches,
      aPlacer: _aPlacer,
      debutJournee: _journee.debut,
      finJournee: _journee.fin,
      maintenant: widget.maintenant(),
    );
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _Proposition(proposition: proposition, demain: _demain),
    );
    if (ok != true) return;
    for (final t in proposition.placees) {
      await widget.base.enregistreTache(t);
    }
  }

  String _resume() {
    if (_vue == VuePlanning.liste) {
      final n = _liste.length;
      if (n == 0) return 'Rien pour l\'instant.';
      final minutes = _liste.fold(0, (s, a) => s + a.duree);
      return '$n chose${n > 1 ? 's' : ''} · ${dureeFr(minutes)} en tout';
    }
    final taches = _taches;
    final date = dateCourte(_jour);
    if (taches.isEmpty) return '$date · Rien de prévu pour l\'instant.';
    final n = taches.length;
    final minutes = taches.fold(0, (s, t) => s + t.duree);
    final debut = taches.map((t) => t.debut).reduce((a, b) => a < b ? a : b);
    final fin = taches.map((t) => t.fin).reduce((a, b) => a > b ? a : b);
    return '$date · $n chose${n > 1 ? 's' : ''} · ${dureeFr(minutes)} · de '
        '${heureFr(debut)} à ${heureFr(fin % (24 * 60))}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final liste = _vue == VuePlanning.liste;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 22, 6, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GrandTitre(switch (_vue) {
                          VuePlanning.liste => 'À faire',
                          VuePlanning.aujourdhui => 'Aujourd\'hui',
                          VuePlanning.demain => 'Demain',
                        }),
                      ),
                      const SizedBox(width: 12),
                      BoutonPlus(
                        infobulle: liste
                            ? 'Ajouter à la liste'
                            : 'Ajouter un impératif',
                        onPressed: liste ? _ouvreAFaire : _ouvreTache,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_resume(), style: TextStyle(color: t.doux)),
                ],
              ),
            ),
            ChoixPilules<VuePlanning>(
              options: const [
                (VuePlanning.liste, 'Liste'),
                (VuePlanning.aujourdhui, 'Aujourd\'hui'),
                (VuePlanning.demain, 'Demain'),
              ],
              valeur: _vue,
              onChoix: (v) => setState(() => _vue = v),
            ),
            const SizedBox(height: 14),
            if (_charge) ...(liste ? _vueListe(context) : _vueJour(context)),
          ],
        ),
      ),
    );
  }

  List<Widget> _vueListe(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    final parCase = <Case, List<AFaire>>{};
    for (final a in ordreDePlacement(_liste, _aujourdhui)) {
      (parCase[a.caseLe(_aujourdhui)] ??= []).add(a);
    }
    for (final a in _liste) {
      if (a.caseLe(_aujourdhui) == Case.peutEtreJamais) {
        (parCase[Case.peutEtreJamais] ??= []).add(a);
      }
    }
    return [
      if (_liste.isEmpty)
        CarteRonde(
          padding: const EdgeInsets.all(22),
          child: Text(
            'Note ici tout ce que tu as à faire, avec le temps que ça '
            'prend. Dis si c\'est important, si c\'est urgent : l\'appli '
            'le range dans une des 4 cases, puis le place dans ta journée.',
            style: doux,
          ),
        )
      else
        CarteRonde(
          child: Matrice(
            parCase: parCase,
            onChoix: (c) {
              final contexte = _clesCases[c]!.currentContext;
              if (contexte != null) {
                Scrollable.ensureVisible(
                  contexte,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          ),
        ),
      const SizedBox(height: 10),
      for (final c in Case.values)
        if (parCase[c] case final liste?) ...[
          Padding(
            key: _clesCases[c],
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: couleurCase(context, c),
                    shape: BoxShape.circle,
                    border: c == Case.peutEtreJamais
                        ? Border.all(color: t.doux)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.nom,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  dureeFr(liste.fold(0, (s, a) => s + a.duree)),
                  style: TextStyle(color: t.doux, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          CarteRonde(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final a in liste)
                  _LigneAFaire(
                    key: ValueKey('a-faire-${a.id}'),
                    aFaire: a,
                    placee: _placees[a.id],
                    aujourdhui: _aujourdhui,
                    onTap: () => _ouvreAFaire(a),
                  ),
              ],
            ),
          ),
        ],
      const SizedBox(height: 12),
      _carteAjout(context, 'Ajouter à la liste', _ouvreAFaire),
    ];
  }

  List<Widget> _vueJour(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    final aPlacer = _aPlacer;
    final aRemplir = [
      for (final a in aPlacer)
        if (a.caseLe(_jour) != Case.peutEtreJamais) a,
    ];
    final libre = tempsLibre(
      jour: _jour,
      prevues: _taches,
      debutJournee: _journee.debut,
      finJournee: _journee.fin,
      maintenant: widget.maintenant(),
    );
    final restes = _demain ? _restes : const <Tache>[];
    final nb = aRemplir.length;
    return [
      CarteRonde(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Remplir ma journée',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              [
                'De ${heureFr(_journee.debut)} à ${heureFr(_journee.fin)} : '
                    '${dureeFr(libre)} de libre.',
                nb == 0
                    ? 'Rien à placer depuis ta liste.'
                    : '$nb chose${nb > 1 ? 's' : ''} à placer '
                          '(${dureeFr(aRemplir.fold(0, (s, a) => s + a.duree))}).',
                if (_partHabituelle case final p?)
                  'En général, tu fais ${(p * 100).round()} % de ce que tu '
                      'prévois.',
              ].join(' '),
              style: doux,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: nb == 0 ? null : _remplit,
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.surAccent,
              ),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Remplir'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (_taches.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
          child: Text(
            _demain
                ? 'Pose d\'abord tes impératifs de demain (rendez-vous, heures '
                      'fixes) avec +, puis laisse l\'appli remplir le reste.'
                : 'Rien de prévu aujourd\'hui. Un oubli ? Ajoute-le, le '
                      'rappel suivra.',
            style: doux,
          ),
        ),
      ...blocsDuJour(
        _taches,
        onTap: _ouvreTache,
        onChoix: _demain ? null : _repond,
      ),
      const SizedBox(height: 10),
      _carteAjout(context, 'Ajouter un impératif', _ouvreTache),
      if (aPlacer.isNotEmpty) ...[
        _intertitre(context, 'À placer'),
        CarteRonde(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final a in aPlacer)
                _LigneAFaire(
                  key: ValueKey('a-placer-${a.id}'),
                  aFaire: a,
                  aujourdhui: _jour,
                  onTap: () => _ouvreAFaire(a),
                  action: PiluleChoix(
                    'Placer',
                    key: ValueKey('placer-${a.id}'),
                    onTap: () => _place(a),
                  ),
                ),
            ],
          ),
        ),
      ],
      if (restes.isNotEmpty) ...[
        _intertitre(context, 'Pas fait aujourd\'hui'),
        CarteRonde(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in restes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.texte,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${plageFr(r)} · '
                              '${r.etat == null ? 'sans réponse' : 'pas fait'}',
                              style: doux.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PiluleChoix(
                        'Remettre demain',
                        key: ValueKey('remettre-${r.id}'),
                        onTap: () => _remet([r]),
                      ),
                    ],
                  ),
                ),
              if (restes.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _remet(restes),
                    child: const Text('Tout remettre demain'),
                  ),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _intertitre(BuildContext context, String texte) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
    child: Text(texte, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _carteAjout(BuildContext context, String texte, VoidCallback onTap) =>
      CarteRonde(
        onTap: onTap,
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Teintes.de(context).texte),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                texte,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Une chose de la liste : texte, durée, date limite, où elle est placée,
/// depuis quand elle attend ; et une action à droite (« Placer »).
class _LigneAFaire extends StatelessWidget {
  final AFaire aFaire;
  final Tache? placee;
  final DateTime aujourdhui;
  final VoidCallback onTap;
  final Widget? action;

  const _LigneAFaire({
    super.key,
    required this.aFaire,
    this.placee,
    required this.aujourdhui,
    required this.onTap,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = aFaire;
    final laCase = a.caseLe(aujourdhui);
    final age = ecartJours(a.creeLe, aujourdhui);
    final retard = a.echeance != null && a.echeance!.isBefore(aujourdhui);
    final p = placee;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
        child: Row(
          children: [
            if (action != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: couleurCase(context, laCase),
                  shape: BoxShape.circle,
                  border: laCase == Case.peutEtreJamais
                      ? Border.all(color: t.doux)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.texte,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Pastille(dureeFr(a.duree)),
                      if (a.echeance case final e?)
                        Pastille(
                          retard
                              ? 'En retard'
                              : switch (ecartJours(aujourdhui, e)) {
                                  0 => 'Limite aujourd\'hui',
                                  1 => 'Limite demain',
                                  _ => 'Limite ${dateCourte(e).toLowerCase()}',
                                },
                          fond: retard ? t.moinsBonne : null,
                        ),
                      if (p != null)
                        Pastille(
                          '${p.jour == aujourdhui ? 'Aujourd\'hui' : 'Demain'} '
                          '${heureFr(p.debut)}',
                          fond: t.accent,
                        ),
                      if (age >= 7) Pastille('Depuis $age j'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            action ?? Icon(Icons.chevron_right_rounded, color: t.doux),
          ],
        ),
      ),
    );
  }
}

/// La proposition de « Remplir ma journée », à valider.
class _Proposition extends StatelessWidget {
  final ({List<Tache> placees, List<AFaire> horsJournee}) proposition;
  final bool demain;

  const _Proposition({required this.proposition, required this.demain});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final p = proposition;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              p.placees.isEmpty
                  ? 'Rien ne rentre'
                  : 'Proposition pour ${demain ? 'demain' : 'aujourd\'hui'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              p.placees.isEmpty
                  ? 'Pas de créneau assez long dans ta journée.'
                  : 'Dans les trous, avec un quart d\'heure de marge. Tu '
                        'pourras tout déplacer ensuite.',
              style: TextStyle(color: t.doux),
            ),
            const SizedBox(height: 14),
            for (final tache in p.placees)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        heureFr(tache.debut),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: couleurCase(
                          context,
                          Case.values[tache.quadrant ??
                              Case.peutEtreJamais.index],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tache.texte,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(dureeFr(tache.duree), style: TextStyle(color: t.doux)),
                  ],
                ),
              ),
            if (p.horsJournee.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ne rentre pas : '
                '${p.horsJournee.map((a) => a.texte).join(', ')}.',
                style: TextStyle(color: t.moyenne, height: 1.35),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: p.placees.isEmpty
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('Placer tout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
