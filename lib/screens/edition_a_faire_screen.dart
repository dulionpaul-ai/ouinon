import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/base.dart';
import '../models/a_faire.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/dictee.dart';
import '../utils/planning.dart';
import '../utils/recherche.dart';
import '../widgets/rond.dart';

/// Ajout ou modification d'une chose de la to-do, sur une seule page
/// (demande de Paul du 26/10/2026) : titre, durée, Important / Urgent et
/// une heure imposée facultative. (Une date limite déjà donnée est gardée
/// telle quelle.)
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
  int? _heure;
  String? _erreur;

  /// Le reste de la liste, pour signaler les doublons en tapant.
  List<AFaire> _liste = const [];

  /// Dictée en cours (micro dans le titre).
  SpeechToText? _voix;
  bool _ecoute = false;

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
    _heure = a?.heure;
    widget.base.liste().then((l) {
      if (mounted) setState(() => _liste = l);
    });
  }

  @override
  void dispose() {
    _voix?.stop();
    _texte.dispose();
    super.dispose();
  }

  /// Le micro (Paul, 27/10/2026) : « me couper les ongles et ça prendra
  /// environ 15 minutes » remplit le titre et la durée.
  Future<void> _dicte() async {
    final voix = _voix ??= SpeechToText();
    if (_ecoute) {
      await voix.stop();
      if (mounted) setState(() => _ecoute = false);
      return;
    }
    bool pret;
    try {
      pret = await voix.initialize(
        onStatus: (etat) {
          if ((etat == 'done' || etat == 'notListening') && mounted) {
            setState(() => _ecoute = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _ecoute = false);
        },
      );
    } catch (_) {
      pret = false;
    }
    if (!mounted) return;
    if (!pret) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La dictée n\'est pas disponible sur ce téléphone.'),
        ),
      );
      return;
    }
    setState(() => _ecoute = true);
    await voix.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: 'fr_FR',
      ),
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          _erreur = null;
          if (r.finalResult) {
            final d = lisDictee(r.recognizedWords);
            _texte.text = d.texte;
            if (d.duree != null) _duree = d.duree!;
            _ecoute = false;
          } else {
            _texte.text = r.recognizedWords;
          }
        });
      },
    );
  }

  /// Ouvre la chose qui existe déjà, à la place de celle-ci.
  void _ouvreExistante(AFaire a) => Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => EditionAFaireScreen(
        base: widget.base,
        aFaire: a,
        maintenant: widget.maintenant,
      ),
    ),
  );

  AFaire get _brouillon =>
      (widget.aFaire ?? AFaire(texte: '', creeLe: _aujourdhui)).copie(
        texte: _texte.text.trim(),
        duree: _duree,
        important: _important,
        urgent: _urgent,
        echeance: () => _echeance,
        heure: () => _heure,
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

  /// Cadran d'heure (sans clavier, 24 h).
  Future<void> _choisitHeure() async {
    final depart = _heure ?? 9 * 60;
    final choisie = await showTimePicker(
      context: context,
      helpText: 'À quelle heure ?',
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: TimeOfDay(hour: depart ~/ 60, minute: depart % 60),
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    if (choisie != null && mounted) {
      setState(() => _heure = choisie.hour * 60 + choisie.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final theme = Theme.of(context);
    final brouillon = _brouillon;
    Widget titre(String texte) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Text(texte, style: theme.textTheme.titleMedium),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_nouvelle ? 'Ajouter' : 'Modifier'),
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
          titre('Titre'),
          TextField(
            controller: _texte,
            autofocus: _nouvelle,
            textCapitalization: TextCapitalization.sentences,
            maxLength: Tache.longueurMax,
            onChanged: (_) => setState(() => _erreur = null),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Ex. : Papiers, Appeler le garage',
              counterText: '',
              suffixIcon: IconButton(
                key: const ValueKey('micro'),
                tooltip: _ecoute ? 'Arrêter la dictée' : 'Dicter',
                onPressed: _dicte,
                icon: Icon(
                  _ecoute ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _ecoute ? t.accent : t.doux,
                ),
              ),
            ),
          ),
          // Ce qui existe déjà avec les mêmes mots : pas de doublon.
          if (ressemblantes(
                _texte.text,
                _liste,
                sauf: widget.aFaire?.id,
              ).take(3).toList()
              case final pareilles when pareilles.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
              child: Text(
                'Déjà dans ta liste :',
                style: TextStyle(color: t.accent, fontSize: 13),
              ),
            ),
            for (final a in pareilles)
              InkWell(
                key: ValueKey('existante-${a.id}'),
                onTap: () => _ouvreExistante(a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.texte,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      Text(
                        dureeFr(a.duree),
                        style: TextStyle(color: t.doux, fontSize: 13),
                      ),
                      Icon(Icons.chevron_right_rounded, color: t.doux),
                    ],
                  ),
                ),
              ),
          ],
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
              child: Text(_erreur!, style: TextStyle(color: t.moinsBonne)),
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
          titre('Heure imposée'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PiluleChoix(
                'Aucune',
                key: const ValueKey('heure-aucune'),
                choisie: _heure == null,
                onTap: () => setState(() => _heure = null),
              ),
              PiluleChoix(
                _heure == null ? 'Choisir…' : 'À ${heureFr(_heure!)}',
                key: const ValueKey('heure-choisir'),
                choisie: _heure != null,
                onTap: _choisitHeure,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
            child: Text(
              _heure == null
                  ? 'Tu la caseras où tu veux en planifiant.'
                  : 'En planifiant, elle se pose à ${heureFr(_heure!)}.',
              style: TextStyle(color: t.doux, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
