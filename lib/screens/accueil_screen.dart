import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../utils/deux_moi.dart';
import '../widgets/arrivee.dart';
import '../widgets/rond.dart';
import 'aujourdhui_screen.dart';
import '../utils/jour.dart';
import 'intro_screen.dart';
import 'passage_screen.dart';
import 'preparer_screen.dart';
import 'rapport_screen.dart';
import 'stats_screen.dart';
import 'todo_screen.dart';

/// Écran principal : trois onglets (To-do, Aujourd'hui, Stats ; revue du
/// 25/10/2026, ordre revu le 26/10/2026). Le rappel du soir ouvre « Préparer demain ».
///
/// Les deux toi (26/10/2026) : pendant la journée, Aujourd'hui passe en
/// écran rétro (celui qui exécute) ; le soir, l'appli prend l'accent ambre
/// (celui qui décide). Le premier passage de la journée se fait en
/// ascenseur.
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
  // Deux rôles séparés (Paul, 26/10/2026). Le Décideur a ses onglets :
  // on liste, on planifie, on regarde. L'Exécutant a sa journée.
  static const _todo = 0;
  static const _planifier = 1;

  /// L'onglet du Décideur.
  int _onglet = _todo;
  Timer? _attente;

  /// Les deux toi sont actifs (intro vue).
  bool _actifs = false;

  /// Le rôle actif, gardé d'une ouverture à l'autre ; on en change par
  /// l'ascenseur.
  Moi _role = Moi.decideur;

  Moi get _moi => _actifs ? _role : Moi.repos;

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
      arriveeAscenseur.addListener(_arrivee);
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _base?.changements.removeListener(_aChange);
    Notifications.instance.ouverture.removeListener(_ouvreDepuisNotif);
    arriveeAscenseur.removeListener(_arrivee);
    _attente?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat != AppLifecycleState.resumed) return;
    // Des réponses ont pu arriver par les notifications.
    _base?.signaleChangement();
  }

  /// À l'ouverture : le rôle qu'on avait en partant.
  Future<void> _premierOnglet() async {
    final actifs = await DeuxMoi.actifs();
    final role = await DeuxMoi.role();
    if (!mounted) return;
    setState(() {
      _actifs = actifs;
      _role = role;
    });
  }

  /// Toute arrivée d'ascenseur (bouton Ascenseur, fin de service) met le
  /// rôle d'arrivée.
  void _arrivee() {
    if (!_actifs || !mounted) return;
    final role = arriveeAscenseur.value.versLeSoir
        ? Moi.decideur
        : Moi.executant;
    if (role != _role) {
      setState(() {
        _role = role;
        _onglet = _todo;
      });
    }
    unawaited(DeuxMoi.changeRole(role));
  }

  /// Le bouton Ascenseur : on passe à l'autre rôle (les portes se ferment
  /// sur l'un, s'ouvrent sur l'autre).
  Future<void> _ascenseur() async {
    final vers = _role == Moi.decideur ? Moi.executant : Moi.decideur;
    await PassageScreen.joue(
      context,
      versLeSoir: vers == Moi.decideur,
      auMilieu: () => setState(() {
        _role = vers;
        _onglet = _todo;
      }),
    );
  }

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
    // Le rappel du soir : chez le Décideur, sur Planifier.
    setState(() {
      _role = Moi.decideur;
      _onglet = _planifier;
    });
    unawaited(DeuxMoi.changeRole(Moi.decideur));
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
      await _premierOnglet();
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
    // Puis l'ascenseur monte chez le Décideur, sur sa to-do : il n'y a
    // encore rien à exécuter.
    await DeuxMoi.changeRole(Moi.decideur);
    if (!mounted) return;
    await PassageScreen.joue(
      context,
      versLeSoir: true,
      auMilieu: () => setState(() {
        _actifs = true;
        _role = Moi.decideur;
        _onglet = _todo;
      }),
    );
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
    final executant = _moi == Moi.executant;
    final demain = ajouteJours(jourDe(widget.maintenant()), 1);
    final ecran = Scaffold(
      body: IndexedStack(
        // Les écrans des deux rôles restent tous dans l'arbre : passer de
        // l'un à l'autre ne fait rien perdre.
        index: executant ? 3 : _onglet,
        children: [
          TodoScreen(
            base: base,
            moi: _actifs ? Moi.decideur : Moi.repos,
            maintenant: widget.maintenant,
          ),
          PreparerScreen(
            key: ValueKey('planifier-${cleJour(demain)}'),
            base: base,
            jour: demain,
            maintenant: widget.maintenant,
            onglet: true,
          ),
          StatsScreen(base: base),
          AujourdhuiScreen(
            base: base,
            moi: _actifs ? Moi.executant : Moi.repos,
            maintenant: widget.maintenant,
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: BarreOnglets(
        index: executant ? 0 : _onglet,
        libelles: executant
            ? const ['Ma journée']
            : const ['To-do', 'Planifier', 'Stats'],
        onChoix: (i) {
          if (!executant) setState(() => _onglet = i);
        },
        // L'ascenseur, toujours au même endroit, bien visible.
        ascenseur: _actifs
            ? BoutonAscenseur(versLeSoir: executant, onTap: _ascenseur)
            : null,
      ),
    );
    // Même arbre dans tous les modes : changer de toi ou d'onglet ne fait
    // rien perdre (pages, saisie en cours).
    return Theme(
      data: executant
          ? AppTheme.jour()
          : _moi == Moi.decideur
          ? AppTheme.soir()
          : AppTheme.sombre(),
      child: ecran,
    );
  }
}
