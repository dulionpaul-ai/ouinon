import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/donnees_test.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/version.dart';
import 'creneaux_screen.dart';
import 'stats_screen.dart';

/// Réglages, en lignes simples, sans doublon avec les onglets (ménage du
/// 28/10/2026) : les statistiques, ta journée (heures, créneaux fixes),
/// les notifications, les données de test.
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
  int _reponsesTest = 0;
  String _creneaux = '';

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
    try {
      ok = await Notifications.instance.autorisees();
      precise = await Notifications.instance.heurePrecise();
      if (replanifier) {
        await Notifications.instance.replanifie(widget.base);
      }
    } catch (_) {}
    final bilan = await Preferences.bilanDimanche();
    final rappelPlanning = await Preferences.rappelPlanning();
    final heureRappel = await Preferences.heureRappelPlanning();
    final journee = await Preferences.journee();
    final reponsesTest = await widget.base.nombreReponsesTest();
    final creneaux = await widget.base.creneaux();
    if (!mounted) return;
    setState(() {
      _autorisees = ok;
      _precise = precise;
      _bilan = bilan;
      _rappelPlanning = rappelPlanning;
      _heureRappel = heureRappel;
      _journee = journee;
      _reponsesTest = reponsesTest;
      _creneaux = [
        for (final c in creneaux)
          '${c.texte} ${heureFr(c.debut)} – ${heureFr(c.fin % (24 * 60))}',
      ].join(' · ');
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

  void _ouvre(Widget ecran) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ecran),
  ).then((_) => _verifie());

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final doux = TextStyle(color: t.doux, height: 1.35, fontSize: 13);
    Switch interrupteur(String cle, bool valeur, ValueChanged<bool> f) =>
        Switch(
          key: ValueKey(cle),
          value: valeur,
          activeThumbColor: t.surAccent,
          activeTrackColor: t.accent,
          onChanged: f,
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: [
          _Section('Suivi', [
            _Ligne(
              cle: const ValueKey('statistiques'),
              titre: 'Statistiques',
              sousTitre: 'Toutes tes questions : courbes, groupes, liens',
              onTap: () => _ouvre(StatsScreen(base: widget.base)),
            ),
          ]),
          _Section('Ma journée', [
            _Ligne(
              cle: const ValueKey('debut-journee'),
              titre: 'Début de la journée',
              valeur: heureFr(_journee.debut),
              onTap: () => _choisitJournee(debut: true),
            ),
            _Ligne(
              cle: const ValueKey('fin-journee'),
              titre: 'Fin de la journée',
              valeur: heureFr(_journee.fin),
              sousTitre: '« Caser pour moi » place entre ces heures.',
              onTap: () => _choisitJournee(debut: false),
            ),
            _Ligne(
              titre: 'Créneaux fixes',
              sousTitre: _creneaux.isEmpty
                  ? 'Ex. : enfants de 17 h à 23 h'
                  : _creneaux,
              onTap: () => _ouvre(CreneauxScreen(base: widget.base)),
            ),
          ]),
          _Section('Notifications', [
            if (_autorisees != true)
              _Ligne(
                titre: _autorisees == false
                    ? 'Bloquées : tu ne reçois rien.'
                    : 'Notifications',
                bas: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _autorise,
                    child: const Text('Autoriser les notifications'),
                  ),
                ),
              ),
            if (_precise == false)
              _Ligne(
                titre:
                    'Heure précise non autorisée : les notifications peuvent '
                    'arriver en retard.',
                bas: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _autoriseHeurePrecise,
                    child: const Text('Autoriser l\'heure précise'),
                  ),
                ),
              ),
            // Un seul réglage pour le rappel du soir : l'interrupteur, et
            // son heure en touchant la ligne.
            _Ligne(
              cle: const ValueKey('rappel-soir'),
              titre: 'Rappel du soir',
              valeur: _rappelPlanning ? heureFr(_heureRappel) : null,
              sousTitre: 'Pour remplir ta to-do',
              onTap: _rappelPlanning ? _choisitHeureRappel : null,
              fin: interrupteur(
                'interrupteur-rappel',
                _rappelPlanning,
                _changeRappelPlanning,
              ),
            ),
            _Ligne(
              titre: 'Bilan du dimanche',
              sousTitre: 'Le dimanche à 20 h, ta semaine en quelques lignes',
              fin: interrupteur('interrupteur-bilan', _bilan, _changeBilan),
            ),
            _Ligne(titre: 'Essayer une notification', onTap: _essaie),
          ]),
          _Section('Données de test', [
            _Ligne(
              titre: 'Ajouter 6 mois de test',
              sousTitre: _reponsesTest == 0
                  ? 'Réponses, planning et to-do inventés, pour essayer.'
                  : '$_reponsesTest données de test en ce moment.',
              onTap: _ajouteTest,
            ),
            if (_reponsesTest > 0)
              _Ligne(titre: 'Effacer les données de test', onTap: _effaceTest),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(
              'Tout reste sur ce téléphone : pas de compte, pas de serveur, '
              'aucun envoi. Ouinon montre ce qui va souvent ensemble dans tes '
              'réponses : ce ne sont pas des causes, et l\'appli ne donne '
              'aucun conseil de santé.\n\n${versionLisible()}',
              textAlign: TextAlign.center,
              style: doux,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un groupe de réglages : un petit titre, puis des lignes séparées par
/// un trait, dans une seule carte.
class _Section extends StatelessWidget {
  final String titre;
  final List<Widget> lignes;

  const _Section(this.titre, this.lignes);

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              titre,
              style: TextStyle(
                color: t.doux,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: t.carte,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, l) in lignes.indexed) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, indent: 18, color: t.puce),
                  l,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de réglage : titre, petit texte, valeur à droite ou
/// interrupteur, et touchable si elle mène quelque part.
class _Ligne extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final String? valeur;
  final Widget? fin;
  final Widget? bas;
  final VoidCallback? onTap;
  final Key? cle;

  const _Ligne({
    required this.titre,
    this.sousTitre,
    this.valeur,
    this.fin,
    this.bas,
    this.onTap,
    this.cle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return InkWell(
      key: cle,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sousTitre != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sousTitre!,
                          style: TextStyle(color: t.doux, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                if (valeur != null)
                  Text(
                    valeur!,
                    style: TextStyle(
                      color: t.doux,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ?fin,
                if (onTap != null && fin == null)
                  Icon(Icons.chevron_right_rounded, color: t.doux),
              ],
            ),
            ?bas,
          ],
        ),
      ),
    );
  }
}
