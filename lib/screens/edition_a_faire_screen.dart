import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/a_faire.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../widgets/rond.dart';

/// Ajout ou modification d'une chose de la liste « À faire » : quoi,
/// combien de temps, « Important ? », « Urgent ? » et une date limite
/// facultative (qui rend urgent quand elle approche).
class EditionAFaireScreen extends StatefulWidget {
  final Base base;

  /// Nulle pour une nouvelle chose.
  final AFaire? aFaire;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const EditionAFaireScreen({
    super.key,
    required this.base,
    this.aFaire,
    this.maintenant = DateTime.now,
  });

  @override
  State<EditionAFaireScreen> createState() => _EditionAFaireScreenState();
}

class _EditionAFaireScreenState extends State<EditionAFaireScreen> {
  late final TextEditingController _texte;
  late int _duree;
  late bool _important;
  late bool _urgent;
  DateTime? _echeance;
  String? _erreur;

  bool get _nouvelle => widget.aFaire == null;
  DateTime get _aujourdhui => jourDe(widget.maintenant());

  @override
  void initState() {
    super.initState();
    final a = widget.aFaire;
    _texte = TextEditingController(text: a?.texte ?? '');
    _duree = a?.duree ?? 30;
    _important = a?.important ?? false;
    _urgent = a?.urgent ?? false;
    _echeance = a?.echeance;
  }

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  AFaire get _brouillon =>
      (widget.aFaire ?? AFaire(texte: '', creeLe: _aujourdhui)).copie(
        texte: _texte.text.trim(),
        duree: _duree,
        important: _important,
        urgent: _urgent,
        echeance: () => _echeance,
      );

  Future<void> _enregistre() async {
    if (_texte.text.trim().isEmpty) {
      setState(() => _erreur = 'Écris ce qu\'il y a à faire.');
      return;
    }
    await widget.base.enregistreAFaire(_brouillon);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _faite() async {
    await widget.base.marqueFaite(widget.aFaire!.id!, _aujourdhui);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _supprime() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer de la liste ?'),
        content: Text('« ${widget.aFaire!.texte} » sera effacé.'),
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
    await widget.base.supprimeAFaire(widget.aFaire!.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _choisitDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _echeance ?? ajouteJours(_aujourdhui, 7),
      firstDate: _aujourdhui,
      lastDate: ajouteJours(_aujourdhui, 365),
    );
    if (date != null && mounted) setState(() => _echeance = jourDe(date));
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final theme = Theme.of(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    final brouillon = _brouillon;
    final dimanche = ajouteJours(_aujourdhui, 7 - _aujourdhui.weekday);
    final demain = ajouteJours(_aujourdhui, 1);
    Widget titre(String texte) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Text(texte, style: theme.textTheme.titleMedium),
    );
    String? devientUrgent;
    if (_echeance != null && !brouillon.urgentLe(_aujourdhui)) {
      final le = ajouteJours(_echeance!, -AFaire.joursUrgence);
      devientUrgent = 'Devient urgent le ${dateCourte(le).toLowerCase()}';
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_nouvelle ? 'À faire' : 'Modifier'),
        actions: [
          if (!_nouvelle)
            IconButton(
              tooltip: 'Retirer de la liste',
              onPressed: _supprime,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Row(
          children: [
            if (!_nouvelle) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _faite,
                  child: const Text('C\'est fait'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton(
                onPressed: _enregistre,
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          titre('Quoi'),
          TextField(
            controller: _texte,
            autofocus: _nouvelle,
            textCapitalization: TextCapitalization.sentences,
            maxLength: Tache.longueurMax,
            onChanged: (_) => setState(() => _erreur = null),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Ex. : Papiers, Appeler le garage',
              counterText: '',
            ),
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
              child: Text(_erreur!, style: TextStyle(color: t.moinsBonne)),
            ),
          titre('Combien de temps'),
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
          // Important et Urgent sur une seule ligne (demande de Paul du
          // 25/10/2026).
          Row(
            children: [
              Expanded(
                child: PiluleChoix(
                  'Important',
                  key: const ValueKey('important'),
                  centree: true,
                  choisie: _important,
                  onTap: () => setState(() => _important = !_important),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PiluleChoix(
                  'Urgent',
                  key: const ValueKey('urgent'),
                  centree: true,
                  choisie: _urgent || brouillon.urgentLe(_aujourdhui),
                  onTap: () => setState(() => _urgent = !_urgent),
                ),
              ),
            ],
          ),
          titre('Date limite'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PiluleChoix(
                'Aucune',
                choisie: _echeance == null,
                onTap: () => setState(() => _echeance = null),
              ),
              PiluleChoix(
                'Demain',
                choisie: _echeance == demain,
                onTap: () => setState(() => _echeance = demain),
              ),
              if (dimanche != demain)
                PiluleChoix(
                  'Cette semaine',
                  choisie: _echeance == dimanche,
                  onTap: () => setState(() => _echeance = dimanche),
                ),
              PiluleChoix(
                _echeance != null &&
                        _echeance != demain &&
                        _echeance != dimanche
                    ? dateCourte(_echeance!)
                    : 'Choisir…',
                choisie:
                    _echeance != null &&
                    _echeance != demain &&
                    _echeance != dimanche,
                onTap: _choisitDate,
              ),
            ],
          ),
          if (!_urgent && brouillon.urgentLe(_aujourdhui))
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: Text('Urgent : la date limite est proche.', style: doux),
            ),
          if (devientUrgent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: Text(
                devientUrgent.endsWith('.') ? devientUrgent : '$devientUrgent.',
                style: doux,
              ),
            ),
        ],
      ),
    );
  }
}
