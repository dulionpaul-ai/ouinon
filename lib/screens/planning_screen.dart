import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../widgets/bloc_tache.dart';
import '../widgets/rond.dart';
import 'edition_tache_screen.dart';

/// Le planning (demande de Paul du 24/10/2026) : le soir, on prépare la
/// journée du lendemain, chose par chose, avec l'heure et la durée ; les
/// rappels suivent. Aujourd'hui reste visible (on peut y répondre ou
/// ajouter un oubli) ; ce qui n'a pas été fait aujourd'hui se remet au
/// lendemain d'un toucher.
class PlanningScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const PlanningScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  bool _demain = true;
  List<Tache> _taches = const [];

  /// Pas faites (ou sans réponse) aujourd'hui, pas encore remises demain.
  List<Tache> _restes = const [];
  bool _charge = false;

  DateTime get _aujourdhui => jourDe(widget.maintenant());
  DateTime get _jour => _demain ? ajouteJours(_aujourdhui, 1) : _aujourdhui;

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
    final aujourdhui = await widget.base.tachesDu(_aujourdhui);
    final demain = await widget.base.tachesDu(ajouteJours(_aujourdhui, 1));
    if (!mounted) return;
    final prevus = {for (final t in demain) t.texte};
    setState(() {
      _taches = _demain ? demain : aujourdhui;
      _restes = [
        for (final t in aujourdhui)
          if (!prevus.contains(t.texte) &&
              (t.etat == Tache.pasFait ||
                  (t.etat == null && !t.quand.isAfter(widget.maintenant()))))
            t,
      ];
      _charge = true;
    });
  }

  void _ouvre([Tache? tache]) => Navigator.push(
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

  String _resume() {
    if (_taches.isEmpty) return 'Rien de prévu pour l\'instant.';
    final n = _taches.length;
    final minutes = _taches.fold(0, (s, t) => s + t.duree);
    final debut = _taches.map((t) => t.debut).reduce((a, b) => a < b ? a : b);
    final fin = _taches.map((t) => t.fin).reduce((a, b) => a > b ? a : b);
    return '$n chose${n > 1 ? 's' : ''} · ${dureeFr(minutes)} · de '
        '${heureFr(debut)} à ${heureFr(fin % (24 * 60))}';
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
              padding: const EdgeInsets.fromLTRB(6, 22, 6, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GrandTitre(_demain ? 'Demain' : 'Aujourd\'hui'),
                      ),
                      const SizedBox(width: 12),
                      BoutonPlus(
                        infobulle: 'Prévoir quelque chose',
                        onPressed: _ouvre,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${dateCourte(_jour)} · ${_resume()}',
                    style: TextStyle(color: t.doux),
                  ),
                ],
              ),
            ),
            ChoixPilules<bool>(
              options: const [(false, 'Aujourd\'hui'), (true, 'Demain')],
              valeur: _demain,
              onChoix: (d) {
                setState(() => _demain = d);
                _recharge();
              },
            ),
            const SizedBox(height: 14),
            if (_charge && _taches.isEmpty)
              CarteRonde(
                padding: const EdgeInsets.all(22),
                child: Text(
                  _demain
                      ? 'Prépare ta journée de demain : ce que tu dois faire, '
                            'à quelle heure, pour combien de temps. Un rappel '
                            'arrive à l\'heure pile.'
                      : 'Rien de prévu aujourd\'hui. Un oubli ? Ajoute-le, '
                            'le rappel suivra.',
                  style: doux,
                ),
              ),
            ...blocsDuJour(
              _taches,
              onTap: _ouvre,
              onChoix: _demain ? null : _repond,
            ),
            const SizedBox(height: 10),
            CarteRonde(
              onTap: _ouvre,
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: t.texte),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Prévoir quelque chose',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_demain && _restes.isNotEmpty) ...[
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                child: Text(
                  'Pas fait aujourd\'hui',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              CarteRonde(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in _restes)
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
                    if (_restes.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _remet(_restes),
                          child: const Text('Tout remettre demain'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
