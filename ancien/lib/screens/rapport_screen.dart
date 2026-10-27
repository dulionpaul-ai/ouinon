import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/preferences.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/deux_moi.dart';
import '../utils/planning.dart';
import '../widgets/retro.dart';
import 'passage_screen.dart';

/// Le compte rendu de fin de journée (idée de Paul du 26/10/2026), sur
/// l'écran rétro : ce qui est fait sur ce qui était prévu, ce qui revient
/// dans la to-do, et un mot pour le toi du soir. « Fin de service »
/// passe au soir, en ascenseur.
class RapportScreen extends StatefulWidget {
  final Base base;
  final DateTime jour;

  const RapportScreen({super.key, required this.base, required this.jour});

  @override
  State<RapportScreen> createState() => _RapportScreenState();
}

class _RapportScreenState extends State<RapportScreen> {
  final _mot = TextEditingController();
  List<Tache> _taches = const [];
  int _questions = 0;
  int _repondues = 0;
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _recharge();
  }

  @override
  void dispose() {
    _mot.dispose();
    super.dispose();
  }

  Future<void> _recharge() async {
    final jour = widget.jour;
    final taches = await widget.base.tachesDu(jour);
    final questions = [
      for (final q in await widget.base.questions())
        if (q.active && q.revientLe(jour.weekday)) q,
    ];
    final reponses = await widget.base.reponsesDuJour(jour);
    final mot = await DeuxMoi.motDuJour(jour);
    if (!mounted) return;
    setState(() {
      _taches = taches..sort((a, b) => a.debut.compareTo(b.debut));
      _questions = questions.length;
      _repondues = questions.where((q) => reponses.containsKey(q.id)).length;
      if (mot != null && _mot.text.isEmpty) _mot.text = mot;
      _charge = true;
    });
  }

  Future<void> _finDeService() async {
    await DeuxMoi.changeMotDuJour(widget.jour, _mot.text);
    if (!mounted) return;
    await PassageScreen.joue(context, versLeSoir: true, retireDessous: true);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.retro(),
    child: Builder(builder: _corps),
  );

  Widget _corps(BuildContext context) {
    final t = Teintes.de(context);
    final jour = widget.jour;
    final reviennent = [
      for (final x in _taches)
        if (!x.imperatif && x.etat != Tache.fait) x,
    ];
    final petit = styleMono(12, couleur: t.doux);
    return Scaffold(
      backgroundColor: t.fond,
      body: FondRetro(
        child: SafeArea(
          child: !_charge
              ? const SizedBox()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: t.doux),
                        ),
                        Expanded(
                          child: Text('COMPTE RENDU', style: styleRetro(24)),
                        ),
                        Text(
                          '${joursCourts[jour.weekday - 1].toUpperCase()} '
                          '${jour.day.toString().padLeft(2, '0')}/'
                          '${jour.month.toString().padLeft(2, '0')}',
                          style: styleRetro(22),
                        ),
                      ],
                    ),
                    Divider(color: t.puce),
                    const SizedBox(height: 18),
                    Text(
                      _taches.isEmpty
                          ? 'RIEN N\'ÉTAIT PRÉVU.'
                          : scoreJournee(_taches).toUpperCase(),
                      style: styleRetro(46),
                    ),
                    if (_taches.isNotEmpty)
                      Text(
                        'de ce que le décideur avait prévu',
                        style: styleMono(14, couleur: t.doux),
                      ),
                    const SizedBox(height: 18),
                    for (final x in _taches) _ligne(context, x),
                    if (_questions > 0)
                      _rangee(
                        context,
                        'QUESTIONS',
                        '$_repondues/$_questions',
                        t.texte,
                      ),
                    if (reviennent.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text('REMONTÉ AU DÉCIDEUR', style: petit),
                      const SizedBox(height: 6),
                      for (final x in reviennent)
                        Text(
                          '› ${x.texte.toUpperCase()} : REVIENT DANS LA TO-DO',
                          style: styleMono(14),
                        ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      'UN MOT POUR LE DÉCIDEUR ? (FACULTATIF)',
                      style: petit,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('mot-soir'),
                      controller: _mot,
                      maxLength: 120,
                      maxLines: 2,
                      minLines: 1,
                      style: styleMono(15),
                      cursorColor: t.texte,
                      decoration: InputDecoration(
                        hintText: '> Ex. : le garage a pris plus longtemps',
                        hintStyle: styleMono(14, couleur: t.puce),
                        counterText: '',
                        filled: false,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: t.puce),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: t.texte),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    BoutonRetro(
                      '[ FIN DE SERVICE ]',
                      plein: true,
                      onTap: _finDeService,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _ligne(BuildContext context, Tache x) {
    final t = Teintes.de(context);
    final (marque, droite, couleur) = switch (x.etat) {
      Tache.fait => ('[x]', dureeFr(x.duree).toUpperCase(), t.texte),
      Tache.pasFait => ('[-]', 'PAS FAIT', t.moinsBonne),
      _ => ('[ ]', 'SANS RÉPONSE', t.moyenne),
    };
    return _rangee(
      context,
      '$marque ${x.texte.toUpperCase()}',
      droite,
      couleur,
    );
  }

  Widget _rangee(
    BuildContext context,
    String gauche,
    String droite,
    Color couleur,
  ) {
    final t = Teintes.de(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.puce)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(gauche, style: styleMono(14, couleur: couleur)),
          ),
          const SizedBox(width: 8),
          Text(droite, style: styleMono(13, couleur: couleur)),
        ],
      ),
    );
  }
}
