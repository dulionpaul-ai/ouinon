import 'dart:async';

import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/preferences.dart';
import '../models/a_faire.dart';
import '../models/creneau.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/deux_moi.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../widgets/grille_journee.dart';
import 'edition_tache_screen.dart';

/// « Préparer demain », en deux étapes (revue du 25/10/2026, sur le modèle
/// des rituels de planification des applis du moment) :
/// 1. **Choisir** dans la to-do ce qu'on fait ce jour-là ; une jauge dit
///    en direct si ça rentre dans le temps libre ;
/// 2. **Caser** : glisser chaque chose sur une heure, ou « Caser pour
///    moi ». En terminant, ce qui reste est casé tout seul ; ce qui ne
///    rentre pas retourne dans la to-do.
///
/// Une chose casée prend une heure, avec ses deux notifications (« C'est
/// l'heure », puis « C'est fait ? »).
class PreparerScreen extends StatefulWidget {
  final Base base;

  /// Le jour préparé (demain, ou aujourd'hui).
  final DateTime jour;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  /// L'onglet « Planifier » du Décideur (26/10/2026) : pas d'étape de
  /// choix, toute la to-do au-dessus de la journée, on glisse.
  final bool onglet;

  const PreparerScreen({
    super.key,
    required this.base,
    required this.jour,
    this.maintenant = DateTime.now,
    this.onglet = false,
  });

  @override
  State<PreparerScreen> createState() => _PreparerScreenState();
}

class _PreparerScreenState extends State<PreparerScreen> {
  int _etape = 0;
  List<AFaire> _liste = const [];
  List<Tache> _taches = const [];
  List<Creneau> _creneaux = const [];
  ({int debut, int fin}) _journee = (
    debut: Preferences.debutJourneeParDefaut,
    fin: Preferences.finJourneeParDefaut,
  );
  bool _charge = false;

  final _defile = ScrollController();
  final _cleListe = GlobalKey();
  Timer? _defilement;
  double _vitesse = 0;

  DateTime get _jour => jourDe(widget.jour);
  bool get _demain => _jour.isAfter(jourDe(widget.maintenant()));

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
    final liste = await widget.base.liste();
    final taches = await widget.base.tachesDu(_jour);
    final creneaux = await widget.base.creneauxDu(_jour);
    final journee = await Preferences.journee();
    if (!mounted) return;
    setState(() {
      _liste = liste;
      _taches = taches;
      _creneaux = creneaux;
      _journee = journee;
      _charge = true;
    });
  }

  /// Passages de ce jour tirés de la to-do : id de la chose → passage.
  Map<int, Tache> get _casees => {
    for (final t in _taches)
      if (t.listeId != null && t.etat != Tache.pasFait) t.listeId!: t,
  };

  bool _choisie(AFaire a) =>
      a.choisiePour == _jour || _casees.containsKey(a.id);

  List<AFaire> get _ordonnee =>
      ordreDePlacement(_liste, _jour, avecJamais: true);

  List<AFaire> get _choisies => [
    for (final a in _ordonnee)
      if (_choisie(a)) a,
  ];

  /// Ce qui reste à caser : ce qui a été choisi, ou, dans l'onglet
  /// Planifier, toute la to-do.
  List<AFaire> get _aCaser => [
    for (final a in widget.onglet ? _ordonnee : _choisies)
      if (!_casees.containsKey(a.id)) a,
  ];

  List<Tache> get _rendezVous => [
    for (final t in _taches)
      if (t.imperatif) t,
  ];

  int get _libre => tempsLibre(
    jour: _jour,
    prevues: _rendezVous,
    debutJournee: _journee.debut,
    finJournee: _journee.fin,
    maintenant: widget.maintenant(),
    creneaux: _creneaux,
  );

  Future<void> _bascule(AFaire a) async {
    if (_choisie(a)) {
      final casee = _casees[a.id];
      if (casee != null) await widget.base.supprimeTache(casee.id!);
      await widget.base.choisitPour(a.id!, null);
    } else {
      await widget.base.choisitPour(a.id!, _jour);
    }
  }

  /// Une chose posée dans la journée ; avec une heure imposée, elle va à
  /// cette heure-là, où qu'on la lâche.
  Future<void> _pose(AFaire a, int debut) => widget.base.enregistreTache(
    Tache(
      jour: _jour,
      debut: a.heure ?? debut,
      duree: a.duree,
      texte: a.texte,
      listeId: a.id,
      quadrant: a.caseLe(_jour).index,
    ),
  );

  /// Case tout ce qui reste ; rend ce qui ne rentre pas. Les heures
  /// imposées d'abord, à leur heure.
  Future<List<AFaire>> _caseLeReste() async {
    final aPlacer = [
      for (final a in _aCaser)
        if (!widget.onglet || a.caseLe(_jour) != Case.peutEtreJamais) a,
    ];
    for (final a in aPlacer) {
      if (a.heure != null) await _pose(a, a.heure!);
    }
    final taches = await widget.base.tachesDu(_jour);
    final proposition = remplitJournee(
      jour: _jour,
      prevues: taches,
      aPlacer: [
        for (final a in aPlacer)
          if (a.heure == null) a,
      ],
      debutJournee: _journee.debut,
      finJournee: _journee.fin,
      maintenant: widget.maintenant(),
      creneaux: _creneaux,
      avecJamais: true,
    );
    for (final t in proposition.placees) {
      await widget.base.enregistreTache(t);
    }
    return proposition.horsJournee;
  }

  Future<void> _casePourMoi() async {
    final hors = await _caseLeReste();
    if (!mounted || hors.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ne rentre pas : ${hors.map((a) => a.texte).join(', ')}.',
        ),
      ),
    );
  }

  Future<void> _termine() async {
    final hors = widget.onglet ? <AFaire>[] : await _caseLeReste();
    for (final a in hors) {
      await widget.base.choisitPour(a.id!, null);
    }
    if (!mounted) return;
    if (hors.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ça ne rentre pas'),
          content: Text(
            '${hors.map((a) => '« ${a.texte} »').join(', ')} '
            '${hors.length > 1 ? 'retournent' : 'retourne'} dans ta to-do.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('D\'accord'),
            ),
          ],
        ),
      );
    }
    if (!mounted) return;
    final taches = await widget.base.tachesDu(widget.jour);
    if (!mounted) return;
    final messager = ScaffoldMessenger.of(context);
    if (!widget.onglet) Navigator.pop(context);
    messager.showSnackBar(
      SnackBar(
        content: Text(
          taches.isEmpty
              ? 'Rien de prévu pour l\'instant.'
              : 'C\'est prêt : ${resumeJournee(taches)}.',
        ),
      ),
    );
  }

  void _rendezVousA({int? debut, Tache? tache}) => Navigator.push(
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

  Future<void> _actions(Tache tache) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(context, 'modifier'),
            ),
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: Text(
                tache.imperatif
                    ? 'Supprimer le rendez-vous'
                    : 'Enlever l\'heure',
              ),
              onTap: () => Navigator.pop(context, 'retirer'),
            ),
          ],
        ),
      ),
    );
    if (choix == 'modifier') _rendezVousA(tache: tache);
    if (choix == 'retirer') await widget.base.supprimeTache(tache.id!);
  }

  // Pendant un glisser, la page défile près du haut et du bas.
  void _glisse(Offset global) {
    final boite = _cleListe.currentContext?.findRenderObject() as RenderBox?;
    if (boite == null) return;
    final haut = boite.localToGlobal(Offset.zero).dy;
    final bas = haut + boite.size.height;
    _vitesse = global.dy < haut + 70
        ? -10
        : global.dy > bas - 70
        ? 10
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

  /// « Lun. 26 oct. · Garage C3 à 9 h · Enfants dès 17 h ».
  String get _contraintes => [
    dateCourte(_jour),
    for (final r in _rendezVous) '${r.texte} à ${heureFr(r.debut)}',
    for (final c in _creneaux) '${c.texte} dès ${heureFr(c.debut)}',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    if (widget.onglet) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: !_charge ? const SizedBox() : _demainSansDefiler(context),
        ),
        bottomNavigationBar: _charge
            ? Padding(
                // Au-dessus de la barre d'onglets (déjà comptée dans le
                // bas de l'écran).
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: _bas(context),
                ),
              )
            : null,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _etape == 0 ? 'Fermer' : 'Retour',
                    onPressed: () => _etape == 0
                        ? Navigator.pop(context)
                        : setState(() => _etape = 0),
                    icon: Icon(
                      _etape == 0
                          ? Icons.close_rounded
                          : Icons.arrow_back_rounded,
                      color: t.doux,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Étape ${_etape + 1} sur 2',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.doux,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: !_charge
                  ? const SizedBox()
                  : _etape == 0
                  ? _choisir(context)
                  : _caser(context),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _charge ? _bas(context) : null,
    );
  }

  Widget _titre(String titre, String sousTitre) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GrandTitreSimple(titre),
        const SizedBox(height: 4),
        Text(sousTitre, style: TextStyle(color: Teintes.de(context).doux)),
      ],
    ),
  );

  Widget _choisir(BuildContext context) {
    final t = Teintes.de(context);
    final liste = _ordonnee;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _titre(
          _demain ? 'Demain, je fais…' : 'Aujourd\'hui, je fais…',
          _contraintes,
        ),
        if (liste.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Ta to-do est vide : ajoute d\'abord ce que tu as à faire.',
              style: TextStyle(color: t.doux),
            ),
          ),
        for (final a in liste)
          _LigneChoix(
            key: ValueKey('choix-${a.id}'),
            aFaire: a,
            jour: _jour,
            aujourdhui: jourDe(widget.maintenant()),
            choisie: _choisie(a),
            onTap: () => _bascule(a),
          ),
      ],
    );
  }

  /// La page « Demain » (onglet) : tout tient dans l'écran, sans défiler
  /// (Paul, 26/10/2026) ; on tire une chose vers le bas pour la poser.
  Widget _demainSansDefiler(BuildContext context) {
    final t = Teintes.de(context);
    final aCaser = _aCaser;
    var heureDebut = _journee.debut ~/ 60;
    var heureFin = (_journee.fin - 1) ~/ 60;
    for (final x in _taches) {
      if (x.debut ~/ 60 < heureDebut) heureDebut = x.debut ~/ 60;
      if ((x.fin - 1) ~/ 60 > heureFin) {
        heureFin = ((x.fin - 1) ~/ 60).clamp(0, 23);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 6),
          child: Row(
            children: [
              const Expanded(child: GrandTitreSimple('Demain')),
              if (aCaser.isNotEmpty)
                TextButton.icon(
                  onPressed: _casePourMoi,
                  style: TextButton.styleFrom(foregroundColor: t.accent),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Caser pour moi'),
                ),
            ],
          ),
        ),
        if (aCaser.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              itemCount: aCaser.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _Puce(
                key: ValueKey('acaser-${aCaser[i].id}'),
                aFaire: aCaser[i],
                onGlisse: (_) {},
                onFinGlisse: () {},
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 20, 0),
            child: LayoutBuilder(
              builder: (context, contraintes) {
                final heures = heureFin - heureDebut + 1;
                final h = ((contraintes.maxHeight - 14) / heures).clamp(
                  18.0,
                  64.0,
                );
                return ClipRect(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GrilleJournee(
                      taches: _taches,
                      creneaux: _creneaux,
                      heureDebut: heureDebut,
                      heureFin: heureFin,
                      heure: h,
                      onPoseAFaire: _pose,
                      onDeplace: (tache, debut) => widget.base.enregistreTache(
                        tache.copie(debut: debut),
                      ),
                      onDuree: (tache, duree) => widget.base.enregistreTache(
                        tache.copie(duree: duree),
                      ),
                      onTapTache: _actions,
                      onTapCreneau: (_) {},
                      onTapVide: (debut) => _rendezVousA(debut: debut),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _caser(BuildContext context) {
    final t = Teintes.de(context);
    final aCaser = _aCaser;
    final m = widget.maintenant();
    var heureDebut = 8, heureFin = 23;
    for (final (d, f) in [
      for (final x in _taches) (x.debut, x.fin),
      for (final c in _creneaux) (c.debut, c.fin),
    ]) {
      if (d ~/ 60 < heureDebut) heureDebut = d ~/ 60;
      if ((f - 1) ~/ 60 > heureFin) heureFin = ((f - 1) ~/ 60).clamp(0, 23);
    }
    return ListView(
      key: _cleListe,
      controller: _defile,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _titre(
          widget.onglet ? 'Planifier demain' : 'Quand ?',
          aCaser.isEmpty
              ? 'Tout est casé. Appui long sur un bloc pour le déplacer.'
              : 'Appui long sur une chose, puis glisse-la sur une heure.',
        ),
        // Dans l'onglet Planifier : toute la to-do sur deux lignes qui
        // défilent de côté, pour laisser la place à la journée.
        if (aCaser.isNotEmpty && widget.onglet) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rang in [0, 1])
                  Padding(
                    padding: EdgeInsets.only(bottom: rang == 0 ? 8 : 0),
                    child: Row(
                      children: [
                        for (final (i, a) in aCaser.indexed)
                          if (i % 2 == rang)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _Puce(
                                key: ValueKey('acaser-${a.id}'),
                                aFaire: a,
                                onGlisse: _glisse,
                                onFinGlisse: _finGlisse,
                              ),
                            ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _casePourMoi,
                style: TextButton.styleFrom(foregroundColor: t.accent),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Caser pour moi'),
              ),
            ),
          ),
        ],
        if (aCaser.isNotEmpty && !widget.onglet)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final a in aCaser)
                  _Puce(
                    key: ValueKey('acaser-${a.id}'),
                    aFaire: a,
                    onGlisse: _glisse,
                    onFinGlisse: _finGlisse,
                  ),
                TextButton.icon(
                  onPressed: _casePourMoi,
                  style: TextButton.styleFrom(foregroundColor: t.accent),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Caser pour moi'),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
          child: GrilleJournee(
            taches: _taches,
            creneaux: _creneaux,
            heureDebut: heureDebut,
            heureFin: heureFin,
            heure: 40,
            maintenant: _demain ? null : m.hour * 60 + m.minute,
            onPoseAFaire: _pose,
            onDeplace: (tache, debut) =>
                widget.base.enregistreTache(tache.copie(debut: debut)),
            onDuree: (tache, duree) =>
                widget.base.enregistreTache(tache.copie(duree: duree)),
            onTapTache: _actions,
            onTapCreneau: (_) {},
            onTapVide: (debut) => _rendezVousA(debut: debut),
            onGlisse: _glisse,
            onFinGlisse: _finGlisse,
          ),
        ),
      ],
    );
  }

  Widget _bas(BuildContext context) {
    final t = Teintes.de(context);
    final contenu = _etape == 0 && !widget.onglet
        ? _jauge(context)
        : _boutonsCaser(context);
    return Container(
      decoration: BoxDecoration(
        color: Teintes.de(context).carte,
        border: Border(top: BorderSide(color: t.puce)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: contenu,
        ),
      ),
    );
  }

  Widget _jauge(BuildContext context) {
    final t = Teintes.de(context);
    final choisi = _choisies.fold(0, (s, a) => s + a.duree);
    final libre = _libre;
    final etat = remplissage(choisi, libre);
    final couleur = switch (etat) {
      Remplissage.rentre => t.accent,
      Remplissage.juste => t.moyenne,
      Remplissage.tropPlein => t.moinsBonne,
    };
    final message = switch (etat) {
      _ when choisi == 0 => 'Coche ce que tu veux faire.',
      Remplissage.rentre => 'Ça rentre, il reste ${dureeFr(libre - choisi)}.',
      Remplissage.juste => 'C\'est juste.',
      Remplissage.tropPlein =>
        'Trop plein : ${dureeFr(choisi - libre)} de trop.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Choisi : ${dureeFr(choisi)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'sur ${dureeFr(libre)} de libre',
              style: TextStyle(color: t.doux, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: libre == 0
                ? (choisi > 0 ? 1 : 0)
                : (choisi / libre).clamp(0, 1),
            minHeight: 10,
            color: couleur,
            backgroundColor: t.puce,
          ),
        ),
        const SizedBox(height: 8),
        Text(message, style: TextStyle(color: t.doux, fontSize: 13)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() => _etape = 1),
          child: const Text('Suivant : caser dans la journée'),
        ),
      ],
    );
  }

  Widget _boutonsCaser(BuildContext context) {
    final t = Teintes.de(context);
    return Row(
      children: [
        Flexible(
          child: TextButton.icon(
            onPressed: () => _rendezVousA(),
            style: TextButton.styleFrom(foregroundColor: t.accent),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Rendez-vous', overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _termine,
            style: widget.onglet
                ? FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.surAccent,
                  )
                : null,
            child: Text(widget.onglet ? 'Valider demain' : 'Terminer'),
          ),
        ),
      ],
    );
  }
}

/// Titre d'étape en Unbounded.
class GrandTitreSimple extends StatelessWidget {
  final String texte;

  const GrandTitreSimple(this.texte, {super.key});

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      texte,
      maxLines: 1,
      style: TextStyle(
        fontFamily: AppTheme.policeTitre,
        fontSize: 27,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: Teintes.de(context).texte,
      ),
    ),
  );
}

/// Une chose de la to-do à cocher pour le jour préparé.
class _LigneChoix extends StatelessWidget {
  final AFaire aFaire;
  final DateTime jour;
  final DateTime aujourdhui;
  final bool choisie;
  final VoidCallback onTap;

  const _LigneChoix({
    super.key,
    required this.aFaire,
    required this.jour,
    required this.aujourdhui,
    required this.choisie,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      checked: choisie,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.puce)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: choisie ? t.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: choisie ? null : Border.all(color: t.doux, width: 2),
                ),
                child: choisie
                    ? Icon(Icons.check_rounded, size: 17, color: t.surAccent)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aFaire.texte,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (etiquettes(aFaire, jour, depuis: aujourdhui)
                        case final e?)
                      Text(e, style: TextStyle(color: t.doux, fontSize: 13)),
                  ],
                ),
              ),
              Text(
                dureeFr(aFaire.duree),
                style: TextStyle(color: t.doux, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Important · Urgent · limite ven. » (nulle si rien). L'urgence est
/// celle du `jour` préparé ; la date limite se dit depuis `depuis`
/// (aujourd'hui).
String? etiquettes(AFaire a, DateTime jour, {DateTime? depuis}) {
  final ref = depuis ?? jour;
  final morceaux = [
    if (a.important) 'Important',
    if (a.urgentLe(jour)) 'Urgent',
    if (a.echeance case final e?)
      e.isBefore(ref)
          ? 'en retard'
          : switch (ecartJours(ref, e)) {
              0 => 'limite aujourd\'hui',
              1 => 'limite demain',
              _ => 'limite ${dateCourte(e).toLowerCase()}',
            },
  ];
  return morceaux.isEmpty ? null : morceaux.join(' · ');
}

/// Une chose à caser, à glisser (appui long).
class _Puce extends StatelessWidget {
  final AFaire aFaire;
  final void Function(Offset) onGlisse;
  final VoidCallback onFinGlisse;

  const _Puce({
    super.key,
    required this.aFaire,
    required this.onGlisse,
    required this.onFinGlisse,
  });

  Widget _puce(BuildContext context, {bool soulevee = false}) {
    final t = Teintes.de(context);
    return Container(
      height: 40,
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
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              aFaire.texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: soulevee ? t.surAccent : t.texte,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            aFaire.heure == null
                ? dureeFr(aFaire.duree)
                : 'à ${heureFr(aFaire.heure!)} · ${dureeFr(aFaire.duree)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: soulevee ? t.surAccent : t.doux,
            ),
          ),
        ],
      ),
    );
  }

  @override
  // Sans appui long : on tire la chose vers le bas pour l'emporter ; de
  // côté, la ligne défile.
  Widget build(BuildContext context) => Draggable<Object>(
    data: aFaire,
    affinity: Axis.vertical,
    onDragUpdate: (d) => onGlisse(d.globalPosition),
    onDragEnd: (_) => onFinGlisse(),
    onDraggableCanceled: (_, _) => onFinGlisse(),
    feedback: Material(
      type: MaterialType.transparency,
      child: _puce(context, soulevee: true),
    ),
    childWhenDragging: Opacity(opacity: 0.3, child: _puce(context)),
    child: _puce(context),
  );
}
