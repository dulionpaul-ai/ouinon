import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../theme/app_theme.dart';
import '../utils/jour.dart';
import '../widgets/vivant.dart';
import 'journee_screen.dart';
import 'questions_du_jour_screen.dart';
import 'rapport_screen.dart';
import 'todo_screen.dart';

/// L'appli en trois onglets (maquette validée par Paul le 28/10/2026),
/// dans cet ordre : To-do (orange : la matrice d'Eisenhower, on glisse
/// vers la droite pour faire aujourd'hui), Aujourd'hui (vert d'eau : ce
/// qui est à placer et le planning de la journée), Questions (celles du
/// jour). Les stats et le reste sont dans les Réglages (roue dentée en
/// haut de chaque onglet). Changer de page la fait arriver en glissant,
/// avec un trait qui balaie l'écran.
///
/// Reprogramme les notifications à l'ouverture, au retour dans l'appli et
/// après chaque modification. Le rappel du soir ouvre la to-do.
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

  static const todo = 0;

  /// Ce qui attend aujourd'hui (pastille de l'onglet).
  int _attend = 0;

  static const _onglets = [
    (
      libelle: 'To-do',
      icone: Icons.grid_view_rounded,
      couleur: AppTheme.orange,
    ),
    (
      libelle: 'Aujourd\'hui',
      icone: Icons.wb_sunny_outlined,
      couleur: AppTheme.vertDeau,
    ),
    (
      libelle: 'Questions',
      icone: Icons.radio_button_checked_rounded,
      couleur: AppTheme.orange,
    ),
  ];

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
  late final _courbe = CurvedAnimation(
    parent: _arrivee,
    curve: Curves.easeOutCubic,
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
      base.changements.addListener(_compte);
      unawaited(_compte());
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
    _base?.changements.removeListener(_compte);
    Notifications.instance.ouverture.removeListener(_ouvreDepuisNotif);
    _attente?.cancel();
    _courbe.dispose();
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

  /// Ce qui attend aujourd'hui : les choses à placer et celles prévues
  /// sans réponse.
  Future<void> _compte() async {
    final base = _base;
    if (base == null) return;
    final jour = jourDe(widget.maintenant());
    final liste = await base.liste();
    final taches = await base.tachesDu(jour);
    final placees = {for (final t in taches) t.listeId};
    final n =
        taches.where((t) => t.etat == null).length +
        liste
            .where((a) => a.choisiePour == jour && !placees.contains(a.id))
            .length;
    if (mounted && n != _attend) setState(() => _attend = n);
  }

  /// Rappel du soir touché : la to-do ; compte rendu touché : le compte
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
    _va(todo);
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
    final theme = Theme.of(context);
    Widget page(int i, Widget ecran) => Theme(
      data: AppTheme.avecAccent(theme, _onglets[i].couleur),
      child: ecran,
    );
    return Scaffold(
      // Chaque changement de page la fait arriver : elle glisse du côté
      // de l'onglet touché et s'éclaire ; un trait balaie l'écran.
      body: Stack(
        children: [
          // Fondu et glissé sans reconstruire les pages à chaque image.
          FadeTransition(
            opacity: Tween(begin: 0.25, end: 1.0).animate(_courbe),
            child: AnimatedBuilder(
              animation: _courbe,
              builder: (context, enfant) => Transform.translate(
                offset: Offset(_sens * 36 * (1 - _courbe.value), 0),
                child: enfant,
              ),
              child: IndexedStack(
                // Toutes les pages restent dans l'arbre : passer de l'une à
                // l'autre ne fait rien perdre.
                index: _onglet,
                children: [
                  page(
                    0,
                    RepaintBoundary(
                      child: TodoScreen(
                        base: base,
                        maintenant: widget.maintenant,
                      ),
                    ),
                  ),
                  page(
                    1,
                    RepaintBoundary(
                      child: JourneeScreen(
                        base: base,
                        maintenant: widget.maintenant,
                      ),
                    ),
                  ),
                  page(
                    2,
                    RepaintBoundary(
                      child: QuestionsDuJourScreen(
                        base: base,
                        maintenant: widget.maintenant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: page(_onglet, Balayage(key: ValueKey('balayage-$_onglet'))),
          ),
        ],
      ),
      bottomNavigationBar: BarreEspace(
        index: _onglet,
        onglets: _onglets,
        pastilles: [null, _attend, null],
        onChoix: _va,
      ),
    );
  }
}
