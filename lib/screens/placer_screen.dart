import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/preferences.dart';
import '../models/a_faire.dart';
import '../models/creneau.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../widgets/etape.dart';
import '../widgets/grille_journee.dart';
import 'edition_tache_screen.dart';
import 'pret_screen.dart';

/// Le soir, étape 2 sur 2 : placer sur demain (maquette validée par Paul
/// le 26/10/2026). Toute la journée tient dans l'écran, sans défiler ; on
/// pose le doigt sur un aimant et on le glisse à son heure (pas d'appui
/// long), ou « Caser pour moi ». « C'est prêt » case ce qui reste ; ce
/// qui ne rentre pas retourne dans la liste.
class PlacerScreen extends StatefulWidget {
  final Base base;
  final DateTime jour;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const PlacerScreen({
    super.key,
    required this.base,
    required this.jour,
    this.maintenant = DateTime.now,
  });

  @override
  State<PlacerScreen> createState() => _PlacerScreenState();
}

class _PlacerScreenState extends State<PlacerScreen> {
  List<AFaire> _liste = const [];
  List<Tache> _taches = const [];
  List<Creneau> _creneaux = const [];
  ({int debut, int fin}) _journee = (
    debut: Preferences.debutJourneeParDefaut,
    fin: Preferences.finJourneeParDefaut,
  );
  bool _charge = false;

  DateTime get _jour => jourDe(widget.jour);

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
      _charge = true;
    });
  }

  Map<int, Tache> get _casees => {
    for (final t in _taches)
      if (t.listeId != null && t.etat != Tache.pasFait) t.listeId!: t,
  };

  /// Choisies à l'étape 1, pas encore casées.
  List<AFaire> get _aCaser => [
    for (final a in ordreDePlacement(_liste, _jour, avecJamais: true))
      if (a.choisiePour == _jour && !_casees.containsKey(a.id)) a,
  ];

  /// Une chose posée ; avec une heure imposée, elle va à cette heure-là,
  /// où qu'on la lâche.
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

  /// Case tout ce qui reste (les heures imposées d'abord) ; rend ce qui
  /// ne rentre pas.
  Future<List<AFaire>> _caseLeReste() async {
    final aPlacer = _aCaser;
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

  Future<void> _pret() async {
    final hors = await _caseLeReste();
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
            '${hors.length > 1 ? 'retournent' : 'retourne'} dans ta liste.',
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
    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => PretScreen(
          base: widget.base,
          jour: _jour,
          maintenant: widget.maintenant,
        ),
        transitionsBuilder: (_, anim, _, enfant) =>
            FadeTransition(opacity: anim, child: enfant),
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
                    : 'Enlever de la journée',
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

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final aCaser = _aCaser;
    // La journée réglée, élargie à ce qui est déjà prévu ; les créneaux
    // fixes du soir sont coupés au bas de l'écran.
    var heureDebut = _journee.debut ~/ 60;
    var heureFin = math.max(heureDebut, (_journee.fin - 1) ~/ 60);
    for (final x in _taches) {
      heureDebut = math.min(heureDebut, x.debut ~/ 60);
      heureFin = math.max(heureFin, ((x.fin - 1) ~/ 60).clamp(0, 23));
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BarreEtape('Étape 2 sur 2'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TitreEcran(majuscule(nomJour(_jour.weekday))),
                        const SizedBox(height: 2),
                        Text(
                          aCaser.isEmpty
                              ? 'Touche un bloc pour le changer.'
                              : 'Pose le doigt, glisse.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.doux, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  if (aCaser.isNotEmpty)
                    OutlinedButton.icon(
                      key: const ValueKey('caser-pour-moi'),
                      onPressed: _casePourMoi,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.accent,
                        side: BorderSide(color: t.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                      label: const Text('Caser pour moi'),
                    ),
                ],
              ),
            ),
            // Ce qui reste à placer, sur une ligne qui défile de côté ; on
            // tire un aimant vers le bas pour le poser.
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
                  ),
                ),
              ),
            Expanded(
              child: !_charge
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
                      child: LayoutBuilder(
                        builder: (context, contraintes) {
                          final heures = heureFin - heureDebut + 1;
                          final h = ((contraintes.maxHeight - 12) / heures)
                              .clamp(18.0, 64.0);
                          return ClipRect(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: GrilleJournee(
                                taches: _taches,
                                creneaux: _creneaux,
                                heureDebut: heureDebut,
                                heureFin: heureFin,
                                heure: h,
                                onPoseAFaire: _pose,
                                onDeplace: (tache, debut) => widget.base
                                    .enregistreTache(tache.copie(debut: debut)),
                                onDuree: (tache, duree) => widget.base
                                    .enregistreTache(tache.copie(duree: duree)),
                                onTapTache: _actions,
                                onTapCreneau: (_) {},
                                onTapVide: (debut) =>
                                    _rendezVousA(debut: debut),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: BoutonSuite(
                key: const ValueKey('pret'),
                texte: 'C\'est prêt',
                icone: Icons.check_rounded,
                onPressed: _charge ? _pret : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un aimant à placer : il suit le doigt dès qu'on le touche.
class _Puce extends StatelessWidget {
  final AFaire aFaire;

  const _Puce({super.key, required this.aFaire});

  Widget _puce(BuildContext context, {bool souleve = false}) {
    final t = Teintes.de(context);
    final a = aFaire;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: souleve ? t.accent : t.carte,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: souleve ? t.accent : t.barre),
        boxShadow: souleve
            ? const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ]
            : null,
      ),
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              a.texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: souleve ? t.surAccent : t.texte,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            a.heure == null
                ? dureeFr(a.duree)
                : 'à ${heureFr(a.heure!)} · ${dureeFr(a.duree)}',
            style: TextStyle(
              fontSize: 12,
              color: souleve ? t.surAccent : t.doux,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Draggable<Object>(
    data: aFaire,
    // Vers le bas : on l'emporte ; de côté : la ligne défile.
    affinity: Axis.vertical,
    feedback: Material(
      type: MaterialType.transparency,
      child: Transform.rotate(
        angle: -0.05,
        child: _puce(context, souleve: true),
      ),
    ),
    childWhenDragging: Opacity(opacity: 0.3, child: _puce(context)),
    child: _puce(context),
  );
}
