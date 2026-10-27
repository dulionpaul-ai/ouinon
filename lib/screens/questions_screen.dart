import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/question.dart';
import '../theme/theme.dart';
import '../utils/date_fr.dart';
import '../utils/version.dart';
import 'question_screen.dart';

/// Écran 1 du cahier, « Mes questions » (validé par Paul le 27/10/2026) :
/// la liste des questions, chacune avec son heure et ses jours ; « + »
/// pour en créer une ; toucher une question pour la modifier ou la
/// supprimer. On y répond par les notifications.
///
/// Reprogramme les notifications à l'ouverture, au retour dans l'appli et
/// après chaque modification.
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen>
    with WidgetsBindingObserver {
  static const _cleNotifsDemandees = 'notifs_demandees';

  Base? _base;
  Object? _erreur;
  List<Question> _questions = const [];
  bool _charge = false;

  /// Faux si Android ne laisse pas sonner à l'heure pile.
  bool _heurePile = true;
  Timer? _attente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ouvre();
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
    if (etat == AppLifecycleState.resumed) _base?.signaleChangement();
  }

  Future<void> _ouvre() async {
    try {
      final base = await Base.ouvrir();
      if (!mounted) return;
      _base = base;
      base.changements.addListener(_aChange);
      await _recharge();
      unawaited(_replanifie());
      await _premiereFois();
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  Future<void> _recharge() async {
    final base = _base;
    if (base == null) return;
    final questions = await base.questions();
    bool pile;
    try {
      pile = await Notifications.instance.heurePrecise();
    } catch (_) {
      pile = true;
    }
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _heurePile = pile;
      _charge = true;
    });
  }

  /// Plusieurs changements d'affilée : une seule reprogrammation.
  void _aChange() {
    _recharge();
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

  /// À la toute première ouverture : demander les notifications.
  Future<void> _premiereFois() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_cleNotifsDemandees) ?? false) return;
    await prefs.setBool(_cleNotifsDemandees, true);
    try {
      await Notifications.instance.demandeAutorisation();
    } catch (_) {}
    await _replanifie();
  }

  Future<void> _ouvreQuestion([Question? q]) async {
    final base = _base;
    if (base == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionScreen(base: base, question: q),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_erreur != null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Impossible d\'ouvrir tes questions. Redémarre l\'appli.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mes questions')),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('nouvelle-question'),
        tooltip: 'Nouvelle question',
        onPressed: _ouvreQuestion,
        child: const Icon(Icons.add),
      ),
      body: !_charge
          ? const SizedBox()
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (!_heurePile)
                  _Bandeau(
                    onTap: () async {
                      await Notifications.instance.demandeHeurePrecise();
                    },
                  ),
                const Divider(),
                if (_questions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 28),
                    child: Text(
                      'Aucune question. Touche + pour en créer une.',
                      style: TextStyle(color: Couleurs.gris, fontSize: 16),
                    ),
                  ),
                for (final q in _questions) ...[
                  _LigneQuestion(
                    key: ValueKey('question-${q.id}'),
                    question: q,
                    onTap: () => _ouvreQuestion(q),
                  ),
                  const Divider(),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text(
                    versionLisible(),
                    style: const TextStyle(color: Couleurs.gris, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Une question : son texte, puis « 21 h · Tous les jours » (ou « En
/// pause » sans aucun jour).
class _LigneQuestion extends StatelessWidget {
  final Question question;
  final VoidCallback onTap;

  const _LigneQuestion({
    super.key,
    required this.question,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final enPause = q.jours == 0 || !q.active;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.texte,
                    style: TextStyle(
                      fontSize: 18,
                      color: enPause ? Couleurs.gris : Couleurs.encre,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enPause
                        ? 'En pause · aucun jour'
                        : '${heureFr(q.heure)} · ${joursFr(q.jours)}',
                    style: const TextStyle(color: Couleurs.gris, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    q.reponses.join(' / '),
                    style: const TextStyle(color: Couleurs.gris, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Couleurs.gris),
          ],
        ),
      ),
    );
  }
}

/// Android retarde les questions sans l'autorisation « Alarmes et
/// rappels » : un bandeau propose de l'ouvrir.
class _Bandeau extends StatelessWidget {
  final VoidCallback onTap;

  const _Bandeau({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF4D6),
    child: InkWell(
      key: const ValueKey('heure-pile'),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Text(
          'Les questions peuvent arriver en retard. Touche ici pour '
          'autoriser l\'heure pile (« Alarmes et rappels »).',
          style: TextStyle(color: Couleurs.encre, fontSize: 14),
        ),
      ),
    ),
  );
}
