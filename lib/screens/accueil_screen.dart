import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../utils/jour.dart';
import '../widgets/bandeau_jeu.dart';
import '../widgets/rond.dart';
import 'aujourdhui_screen.dart';
import 'preparer_screen.dart';
import 'rapport_screen.dart';
import 'stats_screen.dart';
import 'todo_screen.dart';

/// L'appli complète, style Orbite (Paul, 27/10/2026) : un bandeau en bas
/// mène à toutes les pages, dans cet ordre, aux noms du jeu « Synchro » :
/// Réserve (la to-do), Missions (aujourd'hui), Analyse (questions et
/// stats), Plan de vol (placer la journée de demain). En haut, le bandeau
/// du jeu. Changer de page la fait arriver en glissant.
///
/// Reprogramme les notifications à l'ouverture, au retour dans l'appli et
/// après chaque modification. Le rappel du soir ouvre « Demain ».
class AccueilScreen extends StatefulWidget {
  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  /// Page ouverte au lancement (Aujourd'hui ; les captures en changent).
  final int ongletDeDepart;

  const AccueilScreen({
    super.key,
    this.maintenant = DateTime.now,
    this.ongletDeDepart = 1,
  });

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _cleNotifsDemandees = 'notifs_demandees';
  static const _cleHeurePrecise = 'heure_precise_demandee';

  static const demain = 3;

  Base? _base;
  Object? _erreur;
  late int _onglet = widget.ongletDeDepart;

  /// Sens de la dernière arrivée de page (1 : de la droite).
  int _sens = 1;
  Timer? _attente;

  late final _arrivee = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ouvre();
  }

  Future<void> _ouvre() async {
    try {
      final base = await Base.ouvrir();
      if (!mounted) return;
      setState(() => _base = base);
      base.changements.addListener(_aChange);
      Notifications.instance.ouverture.addListener(_ouvreDepuisNotif);
      WidgetsBinding.instance.addPostFrameCallback((_) => _ouvreDepuisNotif());
      unawaited(_replanifie());
      WidgetsBinding.instance.addPostFrameCallback((_) => _premiereFois());
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _base?.changements.removeListener(_aChange);
    Notifications.instance.ouverture.removeListener(_ouvreDepuisNotif);
    _attente?.cancel();
    _arrivee.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    // Des réponses ont pu arriver par les notifications.
    if (etat == AppLifecycleState.resumed) _base?.signaleChangement();
  }

  void _va(int onglet) {
    if (onglet == _onglet) return;
    setState(() {
      _sens = onglet > _onglet ? 1 : -1;
      _onglet = onglet;
    });
    _arrivee.forward(from: 0);
  }

  /// Rappel du soir touché : « Demain » ; compte rendu touché : le compte
  /// rendu du jour.
  void _ouvreDepuisNotif() {
    final base = _base;
    if (base == null || !mounted) return;
    final ouverture = Notifications.instance.ouverture.value;
    if (ouverture == Notifications.rapport) {
      Notifications.instance.ouverture.value = null;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RapportScreen(base: base, jour: jourDe(widget.maintenant())),
        ),
      );
      return;
    }
    if (ouverture != Notifications.preparer) return;
    Notifications.instance.ouverture.value = null;
    _va(demain);
  }

  /// Plusieurs changements d'affilée : une seule reprogrammation.
  void _aChange() {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 600), _replanifie);
  }

  Future<void> _replanifie() async {
    final base = _base;
    if (base == null) return;
    try {
      await Notifications.instance.replanifie(base);
    } catch (_) {
      // Notifications indisponibles : l'appli reste utilisable.
    }
  }

  /// Première ouverture : demander les notifications, puis l'heure pile.
  Future<void> _premiereFois() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_cleNotifsDemandees) ?? false)) {
      await prefs.setBool(_cleNotifsDemandees, true);
      try {
        await Notifications.instance.demandeAutorisation();
      } catch (_) {}
      await _replanifie();
    }
    await _heurePrecise(prefs);
  }

  /// Une seule fois : proposer l'heure précise (« Alarmes et rappels »).
  /// Sans elle, Android peut retarder les questions de plusieurs heures.
  Future<void> _heurePrecise(SharedPreferences prefs) async {
    if (prefs.getBool(_cleHeurePrecise) ?? false) return;
    bool precise;
    try {
      precise = await Notifications.instance.heurePrecise();
    } catch (_) {
      return;
    }
    if (precise) return;
    await prefs.setBool(_cleHeurePrecise, true);
    if (!mounted) return;
    final autoriser = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Questions à l\'heure pile'),
        content: const Text(
          'Pour que chaque question arrive à son heure, Android demande '
          'une autorisation : « Alarmes et rappels ».\n\n'
          'Sans elle, les questions peuvent arriver avec des heures de '
          'retard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );
    if (autoriser ?? false) {
      try {
        await Notifications.instance.demandeHeurePrecise();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _base;
    if (base == null) {
      return Scaffold(
        body: Center(
          child: _erreur == null
              ? const CircularProgressIndicator()
              : const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Impossible d\'ouvrir tes données. Redémarre l\'appli.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      );
    }
    final jourDemain = ajouteJours(jourDe(widget.maintenant()), 1);
    return Scaffold(
      // Chaque changement de page la fait arriver : elle glisse du côté
      // de l'onglet touché et s'éclaire.
      body: Column(
        children: [
          // Le jeu « Synchro », en haut de chaque page.
          SafeArea(
            bottom: false,
            child: BandeauJeu(base: base, maintenant: widget.maintenant),
          ),
          Expanded(
            // Le contexte du corps : il compte la barre du bas.
            child: Builder(
              builder: (context) => MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: _pages(base, jourDemain),
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: BarreOnglets(
        index: _onglet,
        libelles: const ['Réserve', 'Missions', 'Analyse', 'Plan de vol'],
        onChoix: _va,
      ),
    );
  }

  Widget _pages(Base base, DateTime jourDemain) => AnimatedBuilder(
    animation: _arrivee,
    builder: (context, enfant) {
      final v = Curves.easeOutCubic.transform(_arrivee.value);
      return Opacity(
        opacity: 0.25 + 0.75 * v,
        child: Transform.translate(
          offset: Offset(_sens * 36 * (1 - v), 0),
          child: enfant,
        ),
      );
    },
    child: IndexedStack(
      // Toutes les pages restent dans l'arbre : passer de l'une à
      // l'autre ne fait rien perdre.
      index: _onglet,
      children: [
        TodoScreen(base: base, maintenant: widget.maintenant),
        AujourdhuiScreen(base: base, maintenant: widget.maintenant),
        StatsScreen(base: base),
        PreparerScreen(
          key: ValueKey('demain-${cleJour(jourDemain)}'),
          base: base,
          jour: jourDemain,
          maintenant: widget.maintenant,
          onglet: true,
        ),
      ],
    ),
  );
}
