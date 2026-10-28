import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/a_faire.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../widgets/cases.dart';
import '../widgets/rond.dart';

/// Ajout d'un impératif (rendez-vous, heure fixe) ou modification d'une
/// chose prévue : quoi, quel jour (aujourd'hui ou demain), à quelle
/// heure, pour combien de temps. Une chose tirée de la liste garde son
/// texte (il se change dans la liste) ; la retirer du planning la remet
/// « à placer ».
class EditionTacheScreen extends StatefulWidget {
  final Base base;

  /// Nulle pour une nouvelle chose.
  final Tache? tache;

  /// Jour proposé pour une nouvelle chose.
  final DateTime jour;

  /// Début proposé (heure touchée dans la journée) ; sinon après la
  /// dernière chose prévue.
  final int? debut;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const EditionTacheScreen({
    super.key,
    required this.base,
    this.tache,
    required this.jour,
    this.debut,
    this.maintenant = DateTime.now,
  });

  @override
  State<EditionTacheScreen> createState() => _EditionTacheScreenState();
}

class _EditionTacheScreenState extends State<EditionTacheScreen> {
  late final TextEditingController _texte;
  late DateTime _jour;
  late int _debut;
  late int _duree;
  String? _erreur;
  List<Tache> _memeJour = const [];
  List<({String texte, int duree})> _habitudes = const [];

  /// Cadran de l'heure ouvert : « Enregistrer » est caché.
  bool _choixHeure = false;

  bool get _nouvelle => widget.tache == null;
  bool get _deLaListe => widget.tache?.listeId != null;
  DateTime get _aujourdhui => jourDe(widget.maintenant());

  @override
  void initState() {
    super.initState();
    final t = widget.tache;
    _texte = TextEditingController(text: t?.texte ?? '');
    _jour = t?.jour ?? widget.jour;
    _duree = t?.duree ?? 60;
    _debut = t?.debut ?? widget.debut ?? 9 * 60;
    _chargeJour(proposeHeure: t == null && widget.debut == null);
    if (t == null) {
      widget.base.habitudes().then((h) {
        if (mounted) setState(() => _habitudes = h);
      });
    }
  }

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  /// Les autres choses du jour choisi ; pour une nouvelle chose, l'heure
  /// proposée suit la dernière déjà prévue (à l'heure pile), ou 9 h.
  Future<void> _chargeJour({bool proposeHeure = false}) async {
    final jour = _jour;
    final memeJour = await widget.base.tachesDu(jour);
    if (!mounted || jour != _jour) return;
    setState(() {
      _memeJour = memeJour;
      if (proposeHeure) _debut = _heureProposee(memeJour);
    });
  }

  int _heureProposee(List<Tache> memeJour) {
    var debut = 9 * 60;
    if (memeJour.isNotEmpty) {
      final fin = memeJour.map((t) => t.fin).reduce((a, b) => a > b ? a : b);
      debut = ((fin + 59) ~/ 60) * 60;
    }
    if (_jour == _aujourdhui) {
      final m = widget.maintenant();
      final prochaine = (m.hour + 1) * 60;
      if (debut < prochaine) debut = prochaine;
    }
    return debut.clamp(0, 23 * 60);
  }

  Future<void> _choisitHeure() async {
    setState(() => _choixHeure = true);
    final choisie = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: TimeOfDay(hour: _debut ~/ 60, minute: _debut % 60),
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    if (!mounted) return;
    setState(() {
      _choixHeure = false;
      if (choisie != null) _debut = choisie.hour * 60 + choisie.minute;
    });
  }

  Tache get _brouillon =>
      (widget.tache ?? Tache(jour: _jour, debut: _debut, texte: '')).copie(
        jour: _jour,
        debut: _debut,
        duree: _duree,
        texte: _texte.text.trim(),
      );

  Future<void> _enregistre() async {
    if (_texte.text.trim().isEmpty) {
      setState(() => _erreur = 'Écris ce que tu dois faire.');
      return;
    }
    await widget.base.enregistreTache(_brouillon);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _supprime() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer du planning ?'),
        content: Text(
          _deLaListe
              ? '« ${widget.tache!.texte} » retourne dans ta liste, à placer.'
              : '« ${widget.tache!.texte} » sera effacé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.base.supprimeTache(widget.tache!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final theme = Theme.of(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    final demain = ajouteJours(_aujourdhui, 1);
    final brouillon = _brouillon;
    final croise = chevauchements(brouillon, _memeJour);
    final passee =
        _jour == _aujourdhui && !brouillon.quand.isAfter(widget.maintenant());
    Widget titre(String texte) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Text(texte, style: theme.textTheme.titleMedium),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_nouvelle ? 'Rendez-vous' : 'Modifier'),
        actions: [
          if (!_nouvelle)
            IconButton(
              tooltip: 'Retirer du planning',
              onPressed: _supprime,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: _choixHeure
          ? null
          : SafeArea(
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
            autofocus: _nouvelle,
            readOnly: _deLaListe,
            textCapitalization: TextCapitalization.sentences,
            maxLength: Tache.longueurMax,
            onChanged: (_) => setState(() => _erreur = null),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Ex. : Garage, Rendez-vous, Train',
              counterText: '',
            ),
          ),
          if (widget.tache?.quadrant case final q? when _deLaListe)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: Row(
                children: [
                  Pastille(
                    Case.values[q].nom,
                    fond: couleurCase(context, Case.values[q]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'De ta liste. Le texte se change dans la liste.',
                      style: doux,
                    ),
                  ),
                ],
              ),
            ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
              child: Text(_erreur!, style: TextStyle(color: t.moinsBonne)),
            ),
          if (_habitudes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in _habitudes)
                  PiluleChoix(
                    h.texte,
                    choisie: _texte.text.trim() == h.texte,
                    onTap: () => setState(() {
                      _texte.text = h.texte;
                      _duree = h.duree;
                      _erreur = null;
                    }),
                  ),
              ],
            ),
          ],
          titre('Quand'),
          ChoixPilules<DateTime>(
            options: [(_aujourdhui, 'Aujourd\'hui'), (demain, 'Demain')],
            valeur: _jour,
            onChoix: (j) {
              setState(() => _jour = j);
              _chargeJour(proposeHeure: _nouvelle);
            },
          ),
          const SizedBox(height: 10),
          CarteRonde(
            onTap: _choisitHeure,
            padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Début',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: t.puce,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 20, color: t.texte),
                      const SizedBox(width: 8),
                      Text(
                        heureFr(_debut),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          titre('Durée'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in {...Tache.durees, _duree}.toList()..sort())
                PiluleChoix(
                  dureeFr(d),
                  key: ValueKey('duree-$d'),
                  choisie: d == _duree,
                  onTap: () => setState(() => _duree = d),
                ),
            ],
          ),
          const SizedBox(height: 18),
          CarteRonde(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_jour == _aujourdhui ? 'Aujourd\'hui' : 'Demain'}, '
                  'de ${heureFr(brouillon.debut)} à '
                  '${heureFr(brouillon.fin % (24 * 60))}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  passee
                      ? 'Heure déjà passée : pas de rappel.'
                      : 'Rappel à ${heureFr(_debut)} pile, avec « Pas fait · '
                            'Fait ».',
                  style: doux,
                ),
                for (final autre in croise)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Croise « ${autre.texte} » (${plageFr(autre)}).',
                      style: TextStyle(color: t.moyenne, height: 1.35),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
