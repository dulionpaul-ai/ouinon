import 'dart:async';

import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../models/a_faire.dart';
import '../models/creneau.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../widgets/boutons_reponse.dart';
import '../widgets/cases.dart';
import '../widgets/grille_journee.dart';
import '../widgets/rond.dart';
import 'edition_a_faire_screen.dart';
import 'edition_creneau_screen.dart';
import 'edition_tache_screen.dart';

/// Les trois vues de l'onglet « À faire ».
enum VuePlanning { enFond, aujourdhui, demain }

/// L'onglet « À faire », calqué sur le tableau blanc de Paul (photo du
/// 24/10/2026) :
/// - **En fond** : la matrice d'Eisenhower, où il pioche chaque soir ce
///   qu'il fera le lendemain (un toucher coche, un appui long modifie) ;
/// - **Demain** (et **Aujourd'hui**) : en haut le bac « À placer » (sa
///   colonne rouge), dessous la journée heure par heure (sa colonne des
///   heures) ; il glisse les choses du bac sur les heures (ses flèches),
///   ou laisse « Remplir » les placer. Les créneaux fixes (« Enfants
///   17 h – 23 h ») y sont grisés.
///
/// Ce qui n'est pas fait revient de lui-même en fond ; les impératifs
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
  List<Creneau> _creneaux = const [];
  Map<int, Tache> _placees = const {};
  ({int debut, int fin}) _journee = (
    debut: Preferences.debutJourneeParDefaut,
    fin: Preferences.finJourneeParDefaut,
  );

  /// Part faite habituelle (dès 14 jours de planning répondus).
  double? _partHabituelle;
  bool _charge = false;

  final _defile = ScrollController();
  final _cleListe = GlobalKey();
  Timer? _defilement;
  double _vitesse = 0;

  DateTime get _aujourdhui => jourDe(widget.maintenant());
  DateTime get _demainJour => ajouteJours(_aujourdhui, 1);
  bool get _demain => _vue == VuePlanning.demain;
  DateTime get _jour => _demain ? _demainJour : _aujourdhui;
  List<Tache> get _taches => _demain ? _lendemain : _duJour;
  List<Creneau> get _creneauxDuJour => [
    for (final c in _creneaux)
      if (c.revientLe(_jour.weekday)) c,
  ];

  /// Le bac : les choses choisies pour ce jour, pas encore placées.
  List<AFaire> get _bac => [
    for (final a in ordreDePlacement(_liste, _jour, avecJamais: true))
      if (a.choisiePour == _jour && !_placees.containsKey(a.id)) a,
  ];

  List<AFaire> get _choisiesDemain => [
    for (final a in _liste)
      if (a.choisiePour == _demainJour) a,
  ];

  @override
  void initState() {
    super.initState();
    widget.base.changements.addListener(_recharge);
    _recharge();
  }

  @override
  void dispose() {
    widget.base.changements.removeListener(_recharge);
    _defilement?.cancel();
    _defile.dispose();
    super.dispose();
  }

  Future<void> _recharge() async {
    final duJour = await widget.base.tachesDu(_aujourdhui);
    final lendemain = await widget.base.tachesDu(_demainJour);
    final liste = await widget.base.liste();
    final creneaux = await widget.base.creneaux();
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
      _creneaux = creneaux;
      _placees = placees;
      _journee = journee;
      _partHabituelle = jours >= 14 ? partFaite(passees) : null;
      _charge = true;
    });
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

  // Pendant un glisser, la page défile quand on approche du haut ou du
  // bas de l'écran.
  void _glisse(Offset global) {
    final boite = _cleListe.currentContext?.findRenderObject() as RenderBox?;
    if (boite == null) return;
    final haut = boite.localToGlobal(Offset.zero).dy;
    final bas = haut + boite.size.height;
    _vitesse = global.dy < haut + 90
        ? -12
        : global.dy > bas - 150
        ? 12
        : 0;
    if (_vitesse == 0) {
      _finGlisse();
      return;
    }
    _defilement ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_defile.hasClients) return;
      final p = _defile.position;
      final cible = (p.pixels + _vitesse).clamp(
        p.minScrollExtent,
        p.maxScrollExtent,
      );
      if (cible != p.pixels) _defile.jumpTo(cible);
    });
  }

  void _finGlisse() {
    _defilement?.cancel();
    _defilement = null;
  }

  void _ouvreTache({Tache? tache, int? debut}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionTacheScreen(
        base: widget.base,
        tache: tache,
        jour: _jour,
        debut: debut,
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

  void _ouvreCreneau({Creneau? creneau, int? debut}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionCreneauScreen(
        base: widget.base,
        creneau: creneau,
        debut: debut ?? 17 * 60,
      ),
    ),
  );

  /// « + » dans une journée : un impératif ou un créneau fixe.
  Future<void> _ajoute({int? debut}) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_rounded),
              title: const Text('Un impératif'),
              subtitle: const Text('Une fois, à heure fixe (rendez-vous…)'),
              onTap: () => Navigator.pop(context, 'imperatif'),
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Un créneau fixe'),
              subtitle: const Text('Revient chaque semaine (enfants…)'),
              onTap: () => Navigator.pop(context, 'creneau'),
            ),
          ],
        ),
      ),
    );
    if (choix == 'imperatif') _ouvreTache(debut: debut);
    if (choix == 'creneau') _ouvreCreneau(debut: debut);
  }

  Future<void> _choisit(AFaire a) async {
    final pourDemain = a.choisiePour == _demainJour;
    await widget.base.choisitPour(a.id!, pourDemain ? null : _demainJour);
  }

  Future<void> _pose(AFaire a, int debut) async {
    await widget.base.enregistreTache(
      Tache(
        jour: _jour,
        debut: debut,
        duree: a.duree,
        texte: a.texte,
        listeId: a.id,
        quadrant: a.caseLe(_jour).index,
      ),
    );
  }

  Future<void> _repond(Tache tache, int? etat) async {
    await widget.base.repondTache(tache.id!, etat);
    if (etat != null) {
      try {
        await Notifications.instance.retireTache(tache.id!);
      } catch (_) {}
    }
  }

  Future<void> _remet(List<Tache> taches) async {
    for (final t in taches) {
      await widget.base.enregistreTache(
        Tache(
          jour: _demainJour,
          debut: t.debut,
          duree: t.duree,
          texte: t.texte,
        ),
      );
    }
  }

  /// Toucher un bloc : répondre (aujourd'hui), modifier ou retirer.
  Future<void> _actions(Tache tache) async {
    final t = Teintes.de(context);
    final repondable = !tache.jour.isAfter(_aujourdhui);
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
              const SizedBox(height: 4),
              Text(
                '${plageFr(tache)} · ${dureeFr(tache.duree)}',
                style: TextStyle(color: t.doux),
              ),
              if (repondable) ...[
                const SizedBox(height: 14),
                BoutonsReponse(
                  question: reponsesTache,
                  choix: tache.etat,
                  onChoix: (c) => Navigator.pop(
                    context,
                    c == null ? 'efface' : (c == Tache.fait ? 'fait' : 'pas'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Modifier'),
                onTap: () => Navigator.pop(context, 'modifier'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.undo_rounded),
                title: Text(
                  tache.imperatif
                      ? 'Retirer du planning'
                      : 'Remettre dans le bac',
                ),
                onTap: () => Navigator.pop(context, 'retirer'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (choix) {
      case 'fait':
        await _repond(tache, Tache.fait);
      case 'pas':
        await _repond(tache, Tache.pasFait);
      case 'efface':
        await _repond(tache, null);
      case 'modifier':
        _ouvreTache(tache: tache);
      case 'retirer':
        await widget.base.supprimeTache(tache.id!);
    }
  }

  /// « Piocher » : choisir dans la matrice ce qui va dans le bac du jour.
  Future<void> _pioche() async {
    final jour = _jour;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _Pioche(
        base: widget.base,
        liste: _liste,
        jour: jour,
        placees: _placees,
      ),
    );
  }

  /// « Remplir » : place tout le bac dans les trous de la journée.
  Future<void> _remplit() async {
    final proposition = remplitJournee(
      jour: _jour,
      prevues: _taches,
      aPlacer: _bac,
      debutJournee: _journee.debut,
      finJournee: _journee.fin,
      maintenant: widget.maintenant(),
      creneaux: _creneauxDuJour,
      avecJamais: true,
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
    if (_vue == VuePlanning.enFond) {
      return 'Ta matrice. Touche ce que tu fais demain.';
    }
    final n = _taches.length;
    final b = _bac.length;
    return '${dateCourte(_jour)} · $n placée${n > 1 ? 's' : ''} · '
        '$b à placer';
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final fond = _vue == VuePlanning.enFond;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: _cleListe,
          controller: _defile,
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
                          VuePlanning.enFond => 'En fond',
                          VuePlanning.aujourdhui => 'Aujourd\'hui',
                          VuePlanning.demain => 'Demain',
                        }),
                      ),
                      const SizedBox(width: 12),
                      BoutonPlus(
                        infobulle: fond
                            ? 'Ajouter en fond'
                            : 'Impératif ou créneau fixe',
                        onPressed: fond ? _ouvreAFaire : _ajoute,
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
                (VuePlanning.enFond, 'En fond'),
                (VuePlanning.aujourdhui, 'Aujourd\'hui'),
                (VuePlanning.demain, 'Demain'),
              ],
              valeur: _vue,
              onChoix: (v) => setState(() => _vue = v),
            ),
            const SizedBox(height: 14),
            if (_charge) ...(fond ? _vueFond(context) : _vueJour(context)),
          ],
        ),
      ),
    );
  }

  List<Widget> _vueFond(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    final parCase = <Case, List<AFaire>>{};
    for (final a in ordreDePlacement(_liste, _aujourdhui, avecJamais: true)) {
      (parCase[a.caseLe(_aujourdhui)] ??= []).add(a);
    }
    final choisies = _choisiesDemain;
    final minutes = choisies.fold(0, (s, a) => s + a.duree);
    Widget cellule(Case c) => Expanded(
      child: _CaseChoix(
        laCase: c,
        liste: parCase[c] ?? const [],
        demain: _demainJour,
        aujourdhui: _aujourdhui,
        placees: _placees,
        onChoix: _choisit,
        onModifie: _ouvreAFaire,
      ),
    );
    return [
      if (_liste.isEmpty)
        CarteRonde(
          padding: const EdgeInsets.all(22),
          child: Text(
            'Note ici tout ce que tu as en tête, avec le temps que ça '
            'prend : c\'est ta colonne « en fond ». Chaque soir, touche ce '
            'que tu fais demain, puis place-le dans ta journée.',
            style: doux,
          ),
        )
      else ...[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cellule(Case.dabord),
              const SizedBox(width: 8),
              cellule(Case.aPlanifier),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cellule(Case.viteFait),
              const SizedBox(width: 8),
              cellule(Case.peutEtreJamais),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '← Urgent',
                  style: TextStyle(color: t.doux, fontSize: 12),
                ),
              ),
              Text(
                'Pas urgent →',
                style: TextStyle(color: t.doux, fontSize: 12),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Text(
            'Touche pour choisir pour demain, appui long pour modifier.',
            style: doux.copyWith(fontSize: 13),
          ),
        ),
        FilledButton.icon(
          onPressed: () => setState(() => _vue = VuePlanning.demain),
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.surAccent,
            minimumSize: const Size.fromHeight(56),
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(
            choisies.isEmpty
                ? 'Préparer demain'
                : 'Préparer demain · ${choisies.length} choisie'
                      '${choisies.length > 1 ? 's' : ''} · ${dureeFr(minutes)}',
          ),
        ),
      ],
      const SizedBox(height: 12),
      _carteAjout(context, 'Ajouter en fond', _ouvreAFaire),
    ];
  }

  List<Widget> _vueJour(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    final bac = _bac;
    final creneaux = _creneauxDuJour;
    final libre = tempsLibre(
      jour: _jour,
      prevues: _taches,
      debutJournee: _journee.debut,
      finJournee: _journee.fin,
      maintenant: widget.maintenant(),
      creneaux: creneaux,
    );
    final restes = _demain ? _restes : const <Tache>[];
    // 8 h – 23 h comme sur le tableau, élargi si une chose déborde.
    var heureDebut = 8, heureFin = 23;
    for (final (d, f) in [
      for (final x in _taches) (x.debut, x.fin),
      for (final c in creneaux) (c.debut, c.fin),
    ]) {
      if (d ~/ 60 < heureDebut) heureDebut = d ~/ 60;
      if ((f - 1) ~/ 60 > heureFin) heureFin = ((f - 1) ~/ 60).clamp(0, 23);
    }
    final m = widget.maintenant();
    return [
      CarteRonde(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'À placer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                PiluleChoix('Piocher', onTap: _pioche),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: bac.isEmpty ? null : _remplit,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.surAccent,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Remplir'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (bac.isEmpty)
              Text(
                _taches.any((x) => !x.imperatif)
                    ? 'Tout est placé.'
                    : _liste.isEmpty
                    ? 'Rien en fond pour l\'instant : ajoute ce que tu as à '
                          'faire dans « En fond ».'
                    : 'Rien de choisi. Pioche dans « En fond » ce que tu '
                          'fais ${_demain ? 'demain' : 'aujourd\'hui'}.',
                style: doux,
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in bac)
                    _PuceBac(
                      key: ValueKey('bac-${a.id}'),
                      aFaire: a,
                      jour: _jour,
                      onGlisse: _glisse,
                      onFinGlisse: _finGlisse,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Appui long sur une chose, puis glisse-la sur une heure.',
                style: doux.copyWith(fontSize: 13),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              [
                'De ${heureFr(_journee.debut)} à ${heureFr(_journee.fin)} : '
                    '${dureeFr(libre)} de libre.',
                if (_partHabituelle case final p?)
                  'En général, tu fais ${(p * 100).round()} % de ce que tu '
                      'prévois.',
              ].join(' '),
              style: doux.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      GrilleJournee(
        key: ValueKey('grille-$_vue'),
        taches: _taches,
        creneaux: creneaux,
        heureDebut: heureDebut,
        heureFin: heureFin,
        maintenant: _demain ? null : m.hour * 60 + m.minute,
        onPoseAFaire: _pose,
        onDeplace: (tache, debut) =>
            widget.base.enregistreTache(tache.copie(debut: debut)),
        onDuree: (tache, duree) =>
            widget.base.enregistreTache(tache.copie(duree: duree)),
        onTapTache: _actions,
        onTapCreneau: (c) => _ouvreCreneau(creneau: c),
        onTapVide: (debut) => _ajoute(debut: debut),
        onGlisse: _glisse,
        onFinGlisse: _finGlisse,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
        child: Text(
          'Touche un bloc pour répondre ou le modifier ; appui long pour le '
          'déplacer ; tire son bas pour changer la durée. Touche une heure '
          'vide pour un impératif ou un créneau fixe.',
          style: doux.copyWith(fontSize: 13),
        ),
      ),
      if (restes.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
          child: Text(
            'Pas fait aujourd\'hui',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
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
            ],
          ),
        ),
      ],
    ];
  }

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

/// Une case de la matrice : son nom, son temps, et ses choses à cocher
/// pour demain.
class _CaseChoix extends StatelessWidget {
  final Case laCase;
  final List<AFaire> liste;
  final DateTime demain;
  final DateTime aujourdhui;
  final Map<int, Tache> placees;
  final ValueChanged<AFaire> onChoix;
  final ValueChanged<AFaire> onModifie;

  const _CaseChoix({
    required this.laCase,
    required this.liste,
    required this.demain,
    required this.aujourdhui,
    required this.placees,
    required this.onChoix,
    required this.onModifie,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final minutes = liste.fold(0, (s, a) => s + a.duree);
    return Container(
      decoration: BoxDecoration(
        color: t.carte,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: couleurCase(context, laCase),
                    shape: BoxShape.circle,
                    border: laCase == Case.peutEtreJamais
                        ? Border.all(color: t.doux, width: 2)
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      laCase.nom,
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (liste.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    dureeFr(minutes),
                    style: TextStyle(
                      color: t.doux,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 8),
            child: Text(
              laCase.detail,
              style: TextStyle(color: t.doux, fontSize: 11),
            ),
          ),
          if (liste.isEmpty)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                'Rien',
                style: TextStyle(color: t.doux, fontSize: 13),
              ),
            ),
          for (final a in liste)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ItemChoix(
                key: ValueKey('fond-${a.id}'),
                aFaire: a,
                choisie: a.choisiePour == demain,
                placee: placees[a.id],
                aujourdhui: aujourdhui,
                onTap: () => onChoix(a),
                onLongPress: () => onModifie(a),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une chose de la matrice : cochée en citron quand elle est choisie pour
/// demain.
class _ItemChoix extends StatelessWidget {
  final AFaire aFaire;
  final bool choisie;
  final Tache? placee;
  final DateTime aujourdhui;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ItemChoix({
    super.key,
    required this.aFaire,
    required this.choisie,
    required this.placee,
    required this.aujourdhui,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = aFaire;
    final p = placee;
    final infos = [
      dureeFr(a.duree),
      if (p != null)
        '${p.jour == aujourdhui ? 'aujourd\'hui' : 'demain'} ${heureFr(p.debut)}'
      else if (a.echeance case final e?)
        e.isBefore(aujourdhui)
            ? 'en retard'
            : switch (ecartJours(aujourdhui, e)) {
                0 => 'limite aujourd\'hui',
                1 => 'limite demain',
                _ => 'limite ${dateCourte(e).toLowerCase()}',
              }
      else if (ecartJours(a.creeLe, aujourdhui) >= 7)
        'depuis ${ecartJours(a.creeLe, aujourdhui)} j',
    ].join(' · ');
    return Semantics(
      button: true,
      selected: choisie,
      child: Material(
        color: choisie ? t.puce : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: choisie ? t.accent : t.puce, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: choisie ? t.accent : Colors.transparent,
                    border: choisie
                        ? null
                        : Border.all(color: t.doux, width: 2),
                  ),
                  child: choisie
                      ? Icon(Icons.check_rounded, size: 14, color: t.surAccent)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.texte,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        infos,
                        style: TextStyle(
                          color: p != null
                              ? t.accent
                              : a.echeance != null &&
                                    a.echeance!.isBefore(aujourdhui)
                              ? t.moinsBonne
                              : t.doux,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une chose du bac, à glisser sur une heure (appui long).
class _PuceBac extends StatelessWidget {
  final AFaire aFaire;
  final DateTime jour;
  final void Function(Offset) onGlisse;
  final VoidCallback onFinGlisse;

  const _PuceBac({
    super.key,
    required this.aFaire,
    required this.jour,
    required this.onGlisse,
    required this.onFinGlisse,
  });

  Widget _puce(BuildContext context, {bool soulevee = false}) {
    final t = Teintes.de(context);
    final laCase = aFaire.caseLe(jour);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: ShapeDecoration(
        color: soulevee ? t.accent : t.puce,
        shape: const StadiumBorder(),
        shadows: soulevee
            ? const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!soulevee) ...[
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
            const SizedBox(width: 8),
          ],
          Text(
            aFaire.texte,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: soulevee ? t.surAccent : t.texte,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dureeFr(aFaire.duree),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: soulevee ? t.surAccent : t.doux,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Object>(
      data: aFaire,
      hapticFeedbackOnStart: true,
      onDragUpdate: (d) => onGlisse(d.globalPosition),
      onDragEnd: (_) => onFinGlisse(),
      onDraggableCanceled: (_, _) => onFinGlisse(),
      feedback: Material(
        type: MaterialType.transparency,
        child: Transform.rotate(
          angle: -0.05,
          child: _puce(context, soulevee: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _puce(context)),
      child: _puce(context),
    );
  }
}

/// « Piocher » : la matrice en liste, à cocher pour le bac du jour.
class _Pioche extends StatefulWidget {
  final Base base;
  final List<AFaire> liste;
  final DateTime jour;
  final Map<int, Tache> placees;

  const _Pioche({
    required this.base,
    required this.liste,
    required this.jour,
    required this.placees,
  });

  @override
  State<_Pioche> createState() => _PiocheState();
}

class _PiocheState extends State<_Pioche> {
  late final Map<int, bool> _choisies = {
    for (final a in widget.liste) a.id!: a.choisiePour == widget.jour,
  };

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final libres = [
      for (final a in ordreDePlacement(
        widget.liste,
        widget.jour,
        avecJamais: true,
      ))
        if (!widget.placees.containsKey(a.id)) a,
    ];
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
              'Piocher en fond',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Coche ce qui va dans le bac.',
              style: TextStyle(color: t.doux),
            ),
            const SizedBox(height: 10),
            if (libres.isEmpty)
              Text('Rien en fond.', style: TextStyle(color: t.doux)),
            for (final a in libres)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _choisies[a.id] ?? false,
                activeColor: t.accent,
                checkColor: t.surAccent,
                secondary: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: couleurCase(context, a.caseLe(widget.jour)),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  a.texte,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(dureeFr(a.duree)),
                onChanged: (oui) {
                  setState(() => _choisies[a.id!] = oui ?? false);
                  widget.base.choisitPour(
                    a.id!,
                    oui == true ? widget.jour : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// La proposition de « Remplir », à valider.
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
