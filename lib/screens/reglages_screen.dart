import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planification.dart';
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
    });
  }

  Future<void> _changeBilan(bool oui) async {
    setState(() => _bilan = oui);
    await Preferences.activeBilan(oui);
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
          bloc('Bilan du dimanche', [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Le dimanche à 20 h, ta semaine en quelques lignes : '
                    'tes réponses, ta meilleure série, et ce qui va avec ta '
                    'question principale.',
                    style: doux,
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _bilan,
                  activeThumbColor: Teintes.de(context).surAccent,
                  activeTrackColor: Teintes.de(context).accent,
                  onChanged: _changeBilan,
                ),
              ],
            ),
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
              'Ouinon 1.0.0',
              textAlign: TextAlign.center,
              style: doux,
            ),
          ),
        ],
      ),
    );
  }
}
