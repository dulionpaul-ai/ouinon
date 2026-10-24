import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/donnees_test.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planification.dart';
import '../utils/version.dart';
import '../widgets/rond.dart';

/// Réglages : autorisation des notifications, essai d'une notification,
/// et ce que l'appli fait (ou pas) de tes réponses.
class ReglagesScreen extends StatefulWidget {
  final Base base;

  const ReglagesScreen({super.key, required this.base});

  @override
  State<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends State<ReglagesScreen>
    with WidgetsBindingObserver {
  bool? _autorisees;
  bool? _precise;
  bool _bilan = true;
  bool _rappelPlanning = true;
  int _heureRappel = Preferences.heureRappelPlanningParDefaut;
  ({int debut, int fin}) _journee = (
    debut: Preferences.debutJourneeParDefaut,
    fin: Preferences.finJourneeParDefaut,
  );
  NotifsPlanning _notifsPlanning = NotifsPlanning.debutEtFin;
  int _reponsesTest = 0;
  NotifPrevue? _prochaine;
  int? _enAttente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifie();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour des réglages d'Android : on revérifie et on reprogramme.
  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) _verifie(replanifier: true);
  }

  Future<void> _verifie({bool replanifier = false}) async {
    bool? ok;
    bool? precise;
    int? enAttente;
    try {
      ok = await Notifications.instance.autorisees();
      precise = await Notifications.instance.heurePrecise();
      if (replanifier) {
        await Notifications.instance.replanifie(widget.base);
      }
      enAttente = await Notifications.instance.enAttente();
    } catch (_) {}
    final bilan = await Preferences.bilanDimanche();
    final rappelPlanning = await Preferences.rappelPlanning();
    final heureRappel = await Preferences.heureRappelPlanning();
    final journee = await Preferences.journee();
    final notifsPlanning = await Preferences.notifsPlanning();
    final reponsesTest = await widget.base.nombreReponsesTest();
    final maintenant = DateTime.now();
    final plan = planifie(
      questions: await widget.base.questions(),
      repondues: await widget.base.reponduesDepuis(jourDe(maintenant)),
      maintenant: maintenant,
    );
    if (!mounted) return;
    setState(() {
      _autorisees = ok;
      _precise = precise;
      _enAttente = enAttente;
      _prochaine = plan.notifs.isEmpty ? null : plan.notifs.first;
      _bilan = bilan;
      _rappelPlanning = rappelPlanning;
      _heureRappel = heureRappel;
      _journee = journee;
      _notifsPlanning = notifsPlanning;
      _reponsesTest = reponsesTest;
    });
  }

  Future<void> _ajouteTest() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter 6 mois de test ?'),
        content: const Text(
          'Des réponses inventées pour tes questions et un planning '
          'inventé, sur les 6 derniers mois, pour essayer les graphiques. '
          'Tes vraies réponses ne sont pas touchées, et tu pourras effacer '
          'les données de test.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ajoutees = await ajouteDonneesTest(widget.base);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$ajoutees données de test ajoutées.')),
    );
    await _verifie(replanifier: true);
  }

  Future<void> _effaceTest() async {
    final effacees = await widget.base.effaceReponsesTest();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$effacees données de test effacées.')),
    );
    await _verifie(replanifier: true);
  }

  Future<void> _changeBilan(bool oui) async {
    setState(() => _bilan = oui);
    await Preferences.activeBilan(oui);
    try {
      await Notifications.instance.replanifie(widget.base);
    } catch (_) {}
  }

  Future<void> _changeRappelPlanning(bool oui) async {
    setState(() => _rappelPlanning = oui);
    await Preferences.activeRappelPlanning(oui);
    try {
      await Notifications.instance.replanifie(widget.base);
    } catch (_) {}
  }

  /// Cadran d'heure (sans clavier, 24 h) ; nul si annulé.
  Future<int?> _heure(int depart) async {
    final choisie = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: TimeOfDay(hour: depart ~/ 60, minute: depart % 60),
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    return choisie == null ? null : choisie.hour * 60 + choisie.minute;
  }

  Future<void> _choisitJournee({required bool debut}) async {
    final minutes = await _heure(debut ? _journee.debut : _journee.fin);
    if (minutes == null || !mounted) return;
    final nouvelle = debut
        ? (debut: minutes, fin: _journee.fin)
        : (debut: _journee.debut, fin: minutes);
    if (nouvelle.fin <= nouvelle.debut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit venir après le début.')),
      );
      return;
    }
    setState(() => _journee = nouvelle);
    await Preferences.changeJournee(debut: nouvelle.debut, fin: nouvelle.fin);
  }

  Future<void> _changeNotifsPlanning(NotifsPlanning mode) async {
    setState(() => _notifsPlanning = mode);
    await Preferences.changeNotifsPlanning(mode);
    try {
      await Notifications.instance.replanifie(widget.base);
    } catch (_) {}
  }

  Future<void> _choisitHeureRappel() async {
    final minutes = await _heure(_heureRappel);
    if (minutes == null || !mounted) return;
    setState(() => _heureRappel = minutes);
    await Preferences.changeHeureRappelPlanning(minutes);
    try {
      await Notifications.instance.replanifie(widget.base);
    } catch (_) {}
  }

  Future<void> _autoriseHeurePrecise() async {
    try {
      await Notifications.instance.demandeHeurePrecise();
    } catch (_) {}
  }

  Future<void> _autorise() async {
    try {
      await Notifications.instance.demandeAutorisation();
      await Notifications.instance.replanifie(widget.base);
    } catch (_) {}
    await _verifie();
  }

  Future<void> _essaie() async {
    final questions = [
      for (final q in await widget.base.questions())
        if (q.active) q,
    ];
    if (!mounted) return;
    final messager = ScaffoldMessenger.of(context);
    if (questions.isEmpty) {
      messager.showSnackBar(
        const SnackBar(content: Text('Aucune question active.')),
      );
      return;
    }
    try {
      await Notifications.instance.essaie(questions.first);
      messager.showSnackBar(
        const SnackBar(
          content: Text(
            'Notification envoyée : réponds avec ses boutons, la réponse '
            'compte pour aujourd\'hui.',
          ),
        ),
      );
    } catch (_) {
      messager.showSnackBar(
        const SnackBar(content: Text('Notification impossible.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doux = TextStyle(color: Teintes.de(context).doux, height: 1.35);
    Widget bloc(String titre, List<Widget> contenu) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CarteRonde(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...contenu,
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: [
          bloc('Notifications', [
            Text(switch (_autorisees) {
              true => 'Autorisées.',
              false => 'Bloquées : sans elles, tu ne reçois pas tes questions.',
              null => 'Chaque question arrive en notification à son heure.',
            }, style: doux),
            const SizedBox(height: 14),
            if (_autorisees != true) ...[
              FilledButton(
                onPressed: _autorise,
                child: const Text('Autoriser les notifications'),
              ),
            ],
            const SizedBox(height: 14),
            Text(switch (_precise) {
              true =>
                'Heure précise autorisée : les questions arrivent à '
                    'l\'heure.',
              false =>
                'Heure précise non autorisée : les questions peuvent arriver '
                    'avec des heures de retard.',
              null => '',
            }, style: doux),
            if (_precise == false) ...[
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _autoriseHeurePrecise,
                child: const Text('Autoriser l\'heure précise'),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _prochaine == null
                  ? 'Aucune question programmée.'
                  : 'Prochaine question : ${_prochaine!.question.texte} '
                        '${dateCourte(_prochaine!.quand).toLowerCase()} à '
                        // Espace insécable : « 9 h » ne se coupe pas.
                        '${heureFr(_prochaine!.quand.hour * 60 + _prochaine!.quand.minute).replaceAll(' ', '\u00a0')}.',
              style: doux.copyWith(
                color: Teintes.de(context).texte,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_enAttente != null) ...[
              const SizedBox(height: 4),
              Text(
                '$_enAttente notification${_enAttente! > 1 ? 's' : ''} '
                'programmée${_enAttente! > 1 ? 's' : ''} sur le téléphone.',
                style: doux,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Une question déjà répondue dans l\'appli n\'envoie pas de '
              'notification ce jour-là.',
              style: doux,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _essaie,
              style: FilledButton.styleFrom(
                backgroundColor: Teintes.de(context).accent,
                foregroundColor: Teintes.de(context).surAccent,
              ),
              child: const Text('Essayer une notification'),
            ),
          ]),
          bloc('Préparer demain', [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chaque soir, un rappel pour préparer ta journée de '
                    'demain, avec le point sur aujourd\'hui.',
                    style: doux,
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  key: const ValueKey('interrupteur-rappel'),
                  value: _rappelPlanning,
                  activeThumbColor: Teintes.de(context).surAccent,
                  activeTrackColor: Teintes.de(context).accent,
                  onChanged: _changeRappelPlanning,
                ),
              ],
            ),
            if (_rappelPlanning) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _choisitHeureRappel,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text('À ${heureFr(_heureRappel)}'),
                ),
              ),
            ],
          ]),
          bloc('Planning', [
            Text(
              'Ta journée : « Remplir ma journée » place ta liste entre ces '
              'deux heures.',
              style: doux,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('debut-journee'),
                    onPressed: () => _choisitJournee(debut: true),
                    child: Text('De ${heureFr(_journee.debut)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('fin-journee'),
                    onPressed: () => _choisitJournee(debut: false),
                    child: Text('À ${heureFr(_journee.fin)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Notifications d\'une chose prévue : au début (« C\'est '
              'l\'heure ») et à la fin (« C\'est fait ? »), ou une seule.',
              style: doux,
            ),
            const SizedBox(height: 10),
            ChoixPilules<NotifsPlanning>(
              options: const [
                (NotifsPlanning.debutEtFin, 'Les deux'),
                (NotifsPlanning.debut, 'Début'),
                (NotifsPlanning.fin, 'Fin'),
              ],
              valeur: _notifsPlanning,
              onChoix: _changeNotifsPlanning,
            ),
          ]),
          bloc('Bilan du dimanche', [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Le dimanche à 20 h, ta semaine en quelques lignes : '
                    'tes réponses, ta meilleure série, ta découverte la '
                    'plus forte et ton planning.',
                    style: doux,
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  key: const ValueKey('interrupteur-bilan'),
                  value: _bilan,
                  activeThumbColor: Teintes.de(context).surAccent,
                  activeTrackColor: Teintes.de(context).accent,
                  onChanged: _changeBilan,
                ),
              ],
            ),
          ]),
          bloc('Données de test', [
            Text(
              _reponsesTest == 0
                  ? 'Pour essayer : 6 mois de réponses et de planning '
                        'inventés, et une liste à faire, effaçables d\'un '
                        'coup.'
                  : '$_reponsesTest données de test en ce moment. Tes '
                        'vraies réponses sont à part.',
              style: doux,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _ajouteTest,
              style: FilledButton.styleFrom(
                backgroundColor: Teintes.de(context).accent,
                foregroundColor: Teintes.de(context).surAccent,
              ),
              child: const Text('Ajouter 6 mois de test'),
            ),
            if (_reponsesTest > 0) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _effaceTest,
                child: const Text('Effacer les données de test'),
              ),
            ],
          ]),
          bloc('Tes réponses', [
            Text(
              'Tout reste sur ce téléphone : pas de compte, pas de serveur, '
              'aucun envoi. Si tu désinstalles l\'appli, tes réponses sont '
              'effacées.',
              style: doux,
            ),
          ]),
          bloc('À savoir', [
            Text(
              'Ouinon montre ce qui va souvent ensemble dans tes réponses. '
              'Ce ne sont pas des causes, et l\'appli ne donne aucun conseil '
              'de santé.',
              style: doux,
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              versionLisible(),
              textAlign: TextAlign.center,
              style: doux,
            ),
          ),
        ],
      ),
    );
  }
}
