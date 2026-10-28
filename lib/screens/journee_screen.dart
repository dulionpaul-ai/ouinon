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
import '../widgets/grille_journee.dart';
import '../widgets/vivant.dart';
import 'edition_tache_screen.dart';
import 'reglages_screen.dart';

/// Onglet 2, Aujourd'hui (maquette validée par Paul le 28/10/2026), en
/// vert d'eau : en haut, ce qui est arrivé de la to-do et reste « à
/// placer » ; en dessous, le planning de la journée, en entier dans
/// l'écran (jamais de défilement).
///
/// - Toucher une chose à placer la case au premier moment libre ; on peut
///   aussi la glisser sur une heure. « Caser pour moi » case tout.
/// - Toucher un bloc le coche « fait » (le toucher encore le décoche).
/// - Glisser un bloc le déplace (sans appui long) ; le glisser en haut,
///   sur « À placer », lui enlève son heure.
/// - Toucher une heure vide : un rendez-vous à cette heure.
///
/// Chaque geste a son animation, sa vibration et son « Annuler ».
class JourneeScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const JourneeScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<JourneeScreen> createState() => _JourneeScreenState();
}

class _JourneeScreenState extends State<JourneeScreen> {
  List<AFaire> _liste = const [];
  List<Tache> _taches = const [];
  List<Creneau> _creneaux = const [];
  ({int debut, int fin}) _journee = (
    debut: Preferences.debutJourneeParDefaut,
    fin: Preferences.finJourneeParDefaut,
  );

  DateTime get _jour => jourDe(widget.maintenant());

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
    });
  }

  /// Arrivé de la to-do, pas encore à une heure.
  List<AFaire> get _aPlacer => [
    for (final a in ordreDePlacement(_liste, _jour, avecJamais: true))
      if (a.choisiePour == _jour && !_taches.any((t) => t.listeId == a.id)) a,
  ];

  Tache _tache(AFaire a, int debut) => Tache(
    jour: _jour,
    debut: a.heure ?? debut,
    duree: a.duree,
    texte: a.texte,
    listeId: a.id,
    quadrant: a.caseLe(_jour).index,
  );

  /// Une chose posée à une heure (glissée sur la journée).
  Future<void> _pose(AFaire a, int debut) async {
    final t = await widget.base.enregistreTache(_tache(a, debut));
    if (!mounted) return;
    annonce(
      context,
      '« ${a.texte} » à ${heureFr(t.debut)}',
      annuler: () => widget.base.supprimeTache(t.id!),
    );
  }

  /// Une chose touchée : à son heure imposée, sinon au premier moment
  /// libre (sinon au prochain quart d'heure).
  Future<void> _case(AFaire a) async {
    final now = widget.maintenant();
    var debut = a.heure;
    if (debut == null) {
      final p = remplitJournee(
        jour: _jour,
        prevues: _taches,
        aPlacer: [a],
        debutJournee: _journee.debut,
        finJournee: _journee.fin,
        maintenant: now,
        creneaux: _creneaux,
        avecJamais: true,
      );
      debut = p.placees.isNotEmpty
          ? p.placees.first.debut
          : (((now.hour * 60 + now.minute) + 14) ~/ 15 * 15).clamp(
              0,
              24 * 60 - 15,
            );
    }
    await _pose(a, debut);
  }

  /// « Caser pour moi » : les heures imposées d'abord, puis le reste au
  /// premier moment libre ; dit ce qui ne rentre pas.
  Future<void> _caseTout() async {
    final aPlacer = _aPlacer;
    final posees = <Tache>[];
    for (final a in aPlacer) {
      if (a.heure != null) {
        posees.add(await widget.base.enregistreTache(_tache(a, a.heure!)));
      }
    }
    final taches = await widget.base.tachesDu(_jour);
    final p = remplitJournee(
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
    for (final t in p.placees) {
      posees.add(await widget.base.enregistreTache(t));
    }
    if (!mounted) return;
    annonce(
      context,
      p.horsJournee.isEmpty
          ? 'Journée casée'
          : 'Ne rentre pas : ${p.horsJournee.map((a) => a.texte).join(', ')}',
      annuler: posees.isEmpty
          ? null
          : () async {
              for (final t in posees) {
                await widget.base.supprimeTache(t.id!);
              }
            },
    );
  }

  /// Toucher un bloc : fait, ou plus fait.
  Future<void> _coche(Tache tache) async {
    final avant = tache.etat;
    final etat = avant == Tache.fait ? null : Tache.fait;
    await widget.base.repondTache(tache.id!, etat);
    if (etat != null) {
      try {
        await Notifications.instance.retireTache(tache.id!);
      } catch (_) {}
    }
    if (!mounted) return;
    annonce(
      context,
      etat == Tache.fait
          ? 'Fait : ${tache.texte}'
          : 'Plus fait : ${tache.texte}',
      annuler: () => widget.base.repondTache(tache.id!, avant),
    );
  }

  /// Un bloc glissé sur « À placer » : il perd son heure (un rendez-vous
  /// est supprimé).
  Future<void> _enleve(Tache tache) async {
    await widget.base.supprimeTache(tache.id!);
    if (!mounted) return;
    annonce(
      context,
      tache.imperatif
          ? 'Rendez-vous supprimé : ${tache.texte}'
          : '« ${tache.texte} » à placer',
      annuler: () => widget.base.enregistreTache(tache),
    );
  }

  void _rendezVousA(int debut) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionTacheScreen(
        base: widget.base,
        jour: _jour,
        debut: debut,
        maintenant: widget.maintenant,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final aPlacer = _aPlacer;
    final reste = _taches.where((x) => x.etat == null).toList();
    final resteMin = [
      ...reste.map((x) => x.duree),
      ...aPlacer.map((a) => a.duree),
    ].fold(0, (s, d) => s + d);
    final nbReste = reste.length + aPlacer.length;
    final now = widget.maintenant();
    var heureDebut = _journee.debut ~/ 60;
    var heureFin = ((_journee.fin - 1) ~/ 60).clamp(0, 23);
    for (final (d, f) in [
      for (final x in _taches) (x.debut, x.fin),
      for (final c in _creneaux) (c.debut, c.fin),
    ]) {
      if (d ~/ 60 < heureDebut) heureDebut = d ~/ 60;
      if ((f - 1) ~/ 60 > heureFin) heureFin = ((f - 1) ~/ 60).clamp(0, 23);
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EnTete(
                date: nbReste == 0
                    ? dateCourte(_jour)
                    : '${dateCourte(_jour)} · $nbReste à faire · '
                          '${dureeFr(resteMin)}',
                titre: 'Aujourd\'hui',
                actions: [
                  BoutonRond(
                    icone: Icons.tune_rounded,
                    aide: 'Réglages et stats',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReglagesScreen(base: widget.base),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // « À placer » reçoit aussi un bloc qu'on y remonte.
              DragTarget<Object>(
                onWillAcceptWithDetails: (d) => d.data is Tache,
                onAcceptWithDetails: (d) => _enleve(d.data as Tache),
                builder: (context, candidats, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: candidats.isNotEmpty
                        ? t.accent.withValues(alpha: 0.12)
                        : null,
                    borderRadius: BorderRadius.circular(t.rayon),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Etiquette(
                        'À placer',
                        detail: aPlacer.isEmpty
                            ? null
                            : '${aPlacer.length} · '
                                  '${dureeFr(aPlacer.fold(0, (s, a) => s + a.duree))}',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: aPlacer.isEmpty
                            ? Text(
                                _taches.isEmpty
                                    ? 'Rien pour aujourd\'hui : glisse des '
                                          'choses depuis la to-do.'
                                    : 'Tout est casé.',
                                style: TextStyle(color: t.doux, fontSize: 14),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final a in aPlacer)
                                    Apparition(
                                      key: ValueKey('acaser-${a.id}'),
                                      child: _Puce(
                                        aFaire: a,
                                        onTap: () => _case(a),
                                      ),
                                    ),
                                  _BoutonCaser(onTap: _caseTout),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Toute la journée tient dans ce qui reste de l'écran.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final heures = heureFin - heureDebut + 1;
                    final h = ((c.maxHeight - 16) / heures).clamp(16.0, 64.0);
                    return ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: GrilleJournee(
                          taches: _taches,
                          creneaux: _creneaux,
                          heureDebut: heureDebut,
                          heureFin: heureFin,
                          heure: h,
                          maintenant: now.hour * 60 + now.minute,
                          onPoseAFaire: _pose,
                          onDeplace: (tache, debut) => widget.base
                              .enregistreTache(tache.copie(debut: debut)),
                          onDuree: (tache, duree) => widget.base
                              .enregistreTache(tache.copie(duree: duree)),
                          onTapTache: _coche,
                          onTapCreneau: (_) {},
                          onTapVide: _rendezVousA,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une chose à placer : on la touche (casée au premier moment libre) ou
/// on la glisse sur une heure.
class _Puce extends StatelessWidget {
  final AFaire aFaire;
  final VoidCallback onTap;

  const _Puce({required this.aFaire, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = aFaire;
    Widget puce({bool levee = false}) => Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: levee ? t.accent.withValues(alpha: 0.2) : t.carte,
        border: Border.all(color: levee ? t.accent : t.barre),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              a.texte,
              style: TextStyle(color: t.texte, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dureeFr(a.duree).replaceAll(' ', ' '),
            style: TextStyle(
              fontFamily: AppTheme.policeMono,
              fontSize: 11,
              color: t.doux,
            ),
          ),
        ],
      ),
    );
    return Draggable<Object>(
      data: a,
      feedback: Material(
        type: MaterialType.transparency,
        child: puce(levee: true),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: puce()),
      child: GestureDetector(onTap: onTap, child: puce()),
    );
  }
}

class _BoutonCaser extends StatelessWidget {
  final VoidCallback onTap;

  const _BoutonCaser({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const ValueKey('caser-pour-moi'),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.14),
            border: Border.all(color: t.accent),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: t.accent),
              const SizedBox(width: 6),
              Text(
                'Caser pour moi',
                style: TextStyle(
                  color: t.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
