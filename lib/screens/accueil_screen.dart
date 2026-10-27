import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../utils/jour.dart';
import 'bilan_screen.dart';
import 'choisir_screen.dart';
import 'intro_screen.dart';
import 'passage_screen.dart';
import 'rapport_screen.dart';
import 'reglages_screen.dart';
import 'stats_screen.dart';

/// L'accueil (refait avec Paul le 26/10/2026) : plus d'onglets ni de
/// rôles. La journée tourne seule avec les notifications ; le soir, on
/// ouvre l'appli sur « Bonsoir. » et on prépare demain en deux étapes
/// (l'ascenseur monte à l'étage du Décideur). « Mon suivi » et les
/// Réglages sont à côté.
///
/// Reprogramme les notifications à l'ouverture, au retour dans l'appli et
/// après chaque modification.
class AccueilScreen extends StatefulWidget {
  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const AccueilScreen({super.key, this.maintenant = DateTime.now});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen>
    with WidgetsBindingObserver {
  static const _cleBienvenue = 'bienvenue_vue';
  static const _cleHeurePrecise = 'heure_precise_demandee';

  Base? _base;
  Object? _erreur;
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
      Notifications.instance.ouverture.addListener(_ouvreDepuisNotif);
      WidgetsBinding.instance.addPostFrameCallback((_) => _ouvreDepuisNotif());
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
    Notifications.instance.ouverture.removeListener(_ouvreDepuisNotif);
    _attente?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat != AppLifecycleState.resumed) return;
    // Des réponses ont pu arriver par les notifications.
    _base?.signaleChangement();
  }

  /// « Préparer demain » : l'ascenseur monte à l'étage du Décideur et
  /// ses portes s'ouvrent sur l'étape 1.
  Future<void> _preparer() async {
    final base = _base;
    if (base == null) return;
    final demain = ajouteJours(jourDe(widget.maintenant()), 1);
    await PassageScreen.joue(
      context,
      versLeSoir: true,
      destination: ChoisirScreen(
        base: base,
        jour: demain,
        maintenant: widget.maintenant,
      ),
    );
  }

  void _vers(Widget ecran) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));

  /// Rappel du soir touché : « Préparer demain » ; compte rendu touché :
  /// le compte rendu du jour.
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
    unawaited(_preparer());
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

  /// Premier lancement, ou première ouverture depuis les deux toi :
  /// l'intro, puis les notifications.
  Future<void> _bienvenue() async {
    final prefs = await SharedPreferences.getInstance();
    if (await DeuxMoi.actifs()) {
      await _heurePrecise(prefs);
      return;
    }
    if (!mounted) return;
    final autoriser = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const IntroScreen()),
    );
    await prefs.setBool(_cleBienvenue, true);
    if (autoriser ?? false) {
      try {
        await Notifications.instance.demandeAutorisation();
      } catch (_) {}
      await _replanifie();
      await _heurePrecise(prefs);
    } else {
      await _replanifie();
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
    return Theme(
      data: AppTheme.soir(),
      child: BilanScreen(
        base: base,
        maintenant: widget.maintenant,
        onPreparer: _preparer,
        onSuivi: () => _vers(StatsScreen(base: base)),
        onReglages: () => _vers(ReglagesScreen(base: base)),
      ),
    );
  }
}
