import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../utils/deux_moi.dart';
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
  // Les onglets, dans l'ordre du chemin (Paul, 26/10/2026) : on liste,
  // on fait, on regarde.
  static const _todo = 0;
  static const _aujourdhui = 1;

  int _onglet = _todo;

  /// L'onglet de départ suit qui est là, une fois ; ensuite, celui qu'on
  /// a choisi.
  bool _ongletPose = false;
  Timer? _attente;
  Moi _moi = Moi.repos;
  Timer? _horloge;

  /// Après l'intro, ou quand on change de toi à la main : ce toi-là,
  /// quelle que soit l'heure, jusqu'à ce qu'on quitte l'appli.
  Moi? _force;

  /// Les deux toi sont actifs (intro vue).
  bool _actifs = false;

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
      // Qui est là : revu chaque minute.
      _horloge = Timer.periodic(const Duration(minutes: 1), (_) => _majMoi());
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
    _horloge?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.paused) _force = null;
    if (etat != AppLifecycleState.resumed) return;
    // Des réponses ont pu arriver par les notifications.
    _base?.signaleChangement();
    _majMoi();
  }

  /// Qui est là maintenant (les deux toi actifs une fois l'intro vue) ;
  /// au premier passage de la journée dans l'appli, l'ascenseur.
  Future<void> _majMoi() async {
    final base = _base;
    if (base == null) return;
    final now = widget.maintenant();
    final actifs = await DeuxMoi.actifs();
    if (!mounted) return;
    if (actifs != _actifs) setState(() => _actifs = actifs);
    final moi =
        _force ??
        (_actifs ? moiA(now, jour: await Preferences.journee()) : Moi.repos);
    if (!mounted) return;
    final jour = jourDe(now);
    if (moi != Moi.executant || await DeuxMoi.reveilVu(jour)) {
      if (!mounted) return;
      if (moi != _moi || !_ongletPose) {
        setState(() {
          _moi = moi;
          if (!_ongletPose) {
            _onglet = moi == Moi.executant ? _aujourdhui : _todo;
          }
          _ongletPose = true;
        });
      }
      return;
    }
    // Premier passage de la journée : l'ascenseur descend chez
    // l'Exécutant, qui apparaît portes fermées.
    await DeuxMoi.marqueReveil(jour);
    if (!mounted) return;
    await PassageScreen.joue(
      context,
      versLeSoir: false,
      auMilieu: () => setState(() {
        _moi = moi;
        _onglet = _aujourdhui;
        _ongletPose = true;
      }),
    );
  }

  /// Changer de toi à la main (demande de Paul du 26/10/2026) : de
  /// l'Exécutant au Décideur, sinon vers l'Exécutant ; en ascenseur.
  Future<void> _bascule() async {
    final vers = _moi == Moi.executant ? Moi.decideur : Moi.executant;
    await PassageScreen.joue(
      context,
      versLeSoir: vers == Moi.decideur,
      auMilieu: () => setState(() {
        _force = vers;
        _moi = vers;
        _onglet = vers == Moi.decideur ? _todo : _aujourdhui;
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
    setState(() => _onglet = _todo);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(
          data: AppTheme.soir(),
          child: PreparerScreen(
            base: base,
            jour: ajouteJours(jourDe(widget.maintenant()), 1),
            maintenant: widget.maintenant,
          ),
        ),
      ),
    );
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
      await _majMoi();
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
    await DeuxMoi.marqueReveil(jourDe(widget.maintenant()));
    if (!mounted) return;
    await PassageScreen.joue(
      context,
      versLeSoir: true,
      auMilieu: () => setState(() {
        _actifs = true;
        _force = Moi.decideur;
        _moi = Moi.decideur;
        _onglet = _todo;
        _ongletPose = true;
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
    final executant = _moi == Moi.executant && _onglet == _aujourdhui;
    final ecran = Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: [
          TodoScreen(
            base: base,
            moi: _moi,
            onBascule: _actifs ? _bascule : null,
            maintenant: widget.maintenant,
          ),
          AujourdhuiScreen(
            base: base,
            moi: _moi,
            onBascule: _actifs ? _bascule : null,
            maintenant: widget.maintenant,
          ),
          StatsScreen(base: base),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: BarreOnglets(
        index: _onglet,
        libelles: const ['To-do', 'Aujourd\'hui', 'Stats'],
        onChoix: (i) => setState(() {
          _onglet = i;
          _ongletPose = true;
        }),
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
