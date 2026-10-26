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
  // Les onglets, dans l'ordre du chemin (Paul, 26/10/2026) : on liste,
  // on fait, on regarde.
  static const _todo = 0;
  static const _aujourdhui = 1;

  int _onglet = _todo;

  /// L'onglet de départ est posé une fois, à l'ouverture ; ensuite, c'est
  /// celui qu'on choisit.
  bool _ongletPose = false;
  Timer? _attente;

  /// Les deux toi sont actifs (intro vue).
  bool _actifs = false;

  /// Le toi suit l'onglet (Paul, 26/10/2026) : Aujourd'hui, l'Exécutant ;
  /// To-do et Stats, le Décideur.
  static Moi _moiDe(int onglet, bool actifs) => !actifs
      ? Moi.repos
      : onglet == _aujourdhui
      ? Moi.executant
      : Moi.decideur;

  Moi get _moi => _moiDe(_onglet, _actifs);

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

  /// À l'ouverture : l'onglet de départ suit l'heure (pendant la journée,
  /// Aujourd'hui ; sinon, la To-do), avec l'ascenseur au premier passage
  /// de la journée.
  Future<void> _premierOnglet() async {
    final actifs = await DeuxMoi.actifs();
    if (!mounted) return;
    final jour = await Preferences.journee();
    if (!mounted) return;
    final now = widget.maintenant();
    final m = now.hour * 60 + now.minute;
    final onglet = actifs && dansPlage(m, jour) ? _aujourdhui : _todo;
    setState(() => _actifs = actifs);
    if (!_ongletPose) await _vaVers(onglet);
  }

  /// Toute arrivée d'ascenseur (fin de service, « Modifier ma journée »)
  /// met l'onglet du toi d'arrivée : la To-do chez le Décideur, Aujourd'hui
  /// chez l'Exécutant.
  void _arrivee() {
    if (!_actifs || !mounted) return;
    final versLeSoir = arriveeAscenseur.value.versLeSoir;
    unawaited(
      DeuxMoi.marquePassage(
        jourDe(widget.maintenant()),
        versLeSoir: versLeSoir,
      ),
    );
    final onglet = versLeSoir ? _todo : _aujourdhui;
    if ((_moi == Moi.decideur) != versLeSoir) {
      setState(() {
        _onglet = onglet;
        _ongletPose = true;
      });
    }
  }

  /// Change d'onglet ; si le toi change et que c'est la première fois de
  /// la journée dans ce sens, en ascenseur (le nouvel onglet apparaît
  /// portes fermées).
  Future<void> _vaVers(int onglet) async {
    final avant = _ongletPose ? _moi : null;
    final apres = _moiDe(onglet, _actifs);
    final jour = jourDe(widget.maintenant());
    final versLeSoir = apres == Moi.decideur;
    if (!_actifs ||
        apres == avant ||
        await DeuxMoi.passageVu(jour, versLeSoir: versLeSoir)) {
      if (mounted) {
        setState(() {
          _onglet = onglet;
          _ongletPose = true;
        });
      }
      return;
    }
    await DeuxMoi.marquePassage(jour, versLeSoir: versLeSoir);
    if (!mounted) return;
    await PassageScreen.joue(
      context,
      versLeSoir: versLeSoir,
      auMilieu: () => setState(() {
        _onglet = onglet;
        _ongletPose = true;
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
    final aujourdhui = jourDe(widget.maintenant());
    await DeuxMoi.marquePassage(aujourdhui, versLeSoir: true);
    if (!mounted) return;
    await PassageScreen.joue(
      context,
      versLeSoir: true,
      auMilieu: () => setState(() {
        _actifs = true;
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
            moi: _moiDe(_todo, _actifs),
            maintenant: widget.maintenant,
          ),
          AujourdhuiScreen(
            base: base,
            moi: _moiDe(_aujourdhui, _actifs),
            maintenant: widget.maintenant,
          ),
          StatsScreen(base: base),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: BarreOnglets(
        index: _onglet,
        libelles: const ['To-do', 'Aujourd\'hui', 'Stats'],
        onChoix: _vaVers,
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
