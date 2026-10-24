import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../widgets/rond.dart';
import 'aujourdhui_screen.dart';
import 'planning_screen.dart';
import 'questions_screen.dart';
import 'stats_screen.dart';

/// Écran principal : quatre onglets (Jour, Demain, Stats, Questions).
/// Reprogramme les notifications à l'ouverture, au retour dans l'appli et
/// après chaque modification.
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen>
    with WidgetsBindingObserver {
  static const _cleBienvenue = 'bienvenue_vue';
  static const _cleHeurePrecise = 'heure_precise_demandee';

  Base? _base;
  Object? _erreur;
  int _onglet = 0;
  Timer? _attente;

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
      unawaited(_replanifie());
      WidgetsBinding.instance.addPostFrameCallback((_) => _bienvenue());
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _base?.changements.removeListener(_aChange);
    _attente?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat != AppLifecycleState.resumed) return;
    // Des réponses ont pu arriver par les notifications.
    _base?.signaleChangement();
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

  Future<void> _bienvenue() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_cleBienvenue) ?? false) {
      await _heurePrecise(prefs);
      return;
    }
    if (!mounted) return;
    final autoriser = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bienvenue dans Ouinon'),
        content: const Text(
          'Chaque question arrive en notification, à son heure. Tu réponds '
          'directement avec les boutons, sans ouvrir l\'appli.\n\n'
          'Pour commencer, 4 questions sont prêtes : tu peux les changer '
          'dans l\'onglet Questions.\n\n'
          'Tout reste sur ton téléphone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Autoriser les notifications'),
          ),
        ],
      ),
    );
    await prefs.setBool(_cleBienvenue, true);
    if (autoriser ?? false) {
      try {
        await Notifications.instance.demandeAutorisation();
      } catch (_) {}
      await _replanifie();
      await _heurePrecise(prefs);
    }
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
                    'Impossible d\'ouvrir tes réponses. Redémarre l\'appli.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: [
          AujourdhuiScreen(base: base),
          PlanningScreen(base: base),
          StatsScreen(base: base),
          QuestionsScreen(base: base),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: BarreOnglets(
        index: _onglet,
        libelles: const ['Jour', 'Demain', 'Stats', 'Questions'],
        onChoix: (i) => setState(() => _onglet = i),
      ),
    );
  }
}
