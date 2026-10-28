import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/creneau.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../widgets/rond.dart';

/// Ajout ou modification d'un créneau fixe (« Enfants 17 h – 23 h ») :
/// texte, début, fin, jours où il revient.
class EditionCreneauScreen extends StatefulWidget {
  final Base base;

  /// Nul pour un nouveau créneau.
  final Creneau? creneau;

  /// Début proposé pour un nouveau créneau.
  final int debut;

  const EditionCreneauScreen({
    super.key,
    required this.base,
    this.creneau,
    this.debut = 17 * 60,
  });

  @override
  State<EditionCreneauScreen> createState() => _EditionCreneauScreenState();
}

class _EditionCreneauScreenState extends State<EditionCreneauScreen> {
  late final TextEditingController _texte;
  late int _debut;
  late int _fin;
  late int _jours;
  String? _erreur;

  bool get _nouveau => widget.creneau == null;

  @override
  void initState() {
    super.initState();
    final c = widget.creneau;
    _texte = TextEditingController(text: c?.texte ?? '');
    _debut = c?.debut ?? widget.debut;
    _fin = c?.fin ?? (widget.debut + 120).clamp(0, 24 * 60);
    _jours = c?.jours ?? Creneau.tousLesJours;
  }

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _heure({required bool debut}) async {
    final depart = debut ? _debut : _fin;
    final choisie = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: TimeOfDay(hour: depart ~/ 60 % 24, minute: depart % 60),
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    if (choisie == null || !mounted) return;
    final minutes = choisie.hour * 60 + choisie.minute;
    setState(() {
      if (debut) {
        _debut = minutes;
      } else {
        // Minuit en fin : jusqu'au bout de la journée.
        _fin = minutes == 0 ? 24 * 60 : minutes;
      }
    });
  }

  Future<void> _enregistre() async {
    final texte = _texte.text.trim();
    final erreur = texte.isEmpty
        ? 'Donne un nom au créneau.'
        : _fin <= _debut
        ? 'La fin doit venir après le début.'
        : _jours == 0
        ? 'Choisis au moins un jour.'
        : null;
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    final c = (widget.creneau ?? Creneau(texte: '', debut: 0, fin: 0)).copie(
      texte: texte,
      debut: _debut,
      fin: _fin,
      jours: _jours,
    );
    await widget.base.enregistreCreneau(c);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _supprime() async {
    await widget.base.supprimeCreneau(widget.creneau!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final theme = Theme.of(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    Widget titre(String texte) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Text(texte, style: theme.textTheme.titleMedium),
    );
    Widget heure(String libelle, int minutes, VoidCallback onTap, Key cle) =>
        Expanded(
          child: CarteRonde(
            key: cle,
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelle, style: doux),
                const SizedBox(height: 4),
                Text(
                  heureFr(minutes % (24 * 60)),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(_nouveau ? 'Créneau fixe' : 'Modifier'),
        actions: [
          if (!_nouveau)
            IconButton(
              tooltip: 'Supprimer le créneau',
              onPressed: _supprime,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: FilledButton(
          onPressed: _enregistre,
          child: const Text('Enregistrer'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          titre('Quoi'),
          TextField(
            controller: _texte,
            autofocus: _nouveau,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            onChanged: (_) => setState(() => _erreur = null),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Ex. : Enfants, Travail, Repas',
              counterText: '',
            ),
          ),
          titre('Quand'),
          Row(
            children: [
              heure(
                'Début',
                _debut,
                () => _heure(debut: true),
                const ValueKey('creneau-debut'),
              ),
              const SizedBox(width: 10),
              heure(
                'Fin',
                _fin,
                () => _heure(debut: false),
                const ValueKey('creneau-fin'),
              ),
            ],
          ),
          titre('Jours'),
          CarteRonde(
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, contraintes) {
                    final taille = ((contraintes.maxWidth - 6 * 4) / 7).clamp(
                      30.0,
                      44.0,
                    );
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 7; i++)
                          JourRond(
                            key: ValueKey('jour$i'),
                            index: i,
                            taille: taille,
                            choisi: _jours & (1 << i) != 0,
                            onTap: () => setState(() => _jours ^= 1 << i),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final (masque, libelle) in const [
                      (0x7F, 'Tous'),
                      (0x1F, 'Semaine'),
                      (0x60, 'Week-end'),
                    ]) ...[
                      Expanded(
                        child: PiluleChoix(
                          libelle,
                          centree: true,
                          choisie: _jours == masque,
                          onTap: () => setState(() => _jours = masque),
                        ),
                      ),
                      if (masque != 0x60) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
              child: Text(_erreur!, style: TextStyle(color: t.moinsBonne)),
            ),
        ],
      ),
    );
  }
}
