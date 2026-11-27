import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/frequence.dart';
import '../utils/jour.dart';

/// Créer ou modifier une question : le texte, son « pourquoi » (affiché
/// dans la notification), 2 ou 3 réponses (la meilleure en haut), l'heure,
/// et « Quand », d'une seule des deux façons : certains jours (aucun : en
/// pause), ou tous les N jours avec sa prochaine fois.
class QuestionScreen extends StatefulWidget {
  final Base base;

  /// Nulle : nouvelle question.
  final Question? question;

  /// Les réponses déjà données (pour la prochaine fois d'une tâche).
  final Reponses reponses;

  /// Aujourd'hui (tests).
  final DateTime Function() maintenant;

  const QuestionScreen({
    super.key,
    required this.base,
    this.question,
    this.reponses = const {},
    this.maintenant = DateTime.now,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  late final _texte = TextEditingController(text: widget.question?.texte);
  late final _pourquoi = TextEditingController(text: widget.question?.pourquoi);
  late final List<TextEditingController> _reponses = [
    for (final r in widget.question?.reponses ?? const ['Fait', 'Pas fait'])
      TextEditingController(text: r),
  ];
  late int _heure = widget.question?.heure ?? 21 * 60;
  late bool _tache = widget.question?.tache ?? false;

  /// Certains jours (gardés même en passant par « Tous les N jours »).
  late int _jours = widget.question?.tache ?? false
      ? 0
      : widget.question?.jours ?? 0;
  late int _intervalle = widget.question?.tache ?? false
      ? widget.question!.intervalle
      : 7;

  /// « Prochaine fois » d'une tâche : celle calculée, tant qu'elle n'est
  /// pas changée.
  late DateTime _prochaine = _calculee();
  bool _prochaineChangee = false;

  /// Les intervalles proposés.
  static const _intervalles = [2, 3, 4, 5, 7, 10, 14, 21, 30, 60, 90];

  DateTime get _aujourdhui => jourDe(widget.maintenant());

  DateTime _calculee() {
    final q = widget.question;
    if (q == null || !q.tache) return _aujourdhui;
    return prochainJour(q, _aujourdhui, widget.reponses) ?? _aujourdhui;
  }

  static const _libelles = {
    2: ['Meilleure', 'Moins bonne'],
    3: ['Meilleure', 'Milieu', 'Moins bonne'],
  };

  @override
  void dispose() {
    _texte.dispose();
    _pourquoi.dispose();
    for (final c in _reponses) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valide =>
      _texte.text.trim().isNotEmpty &&
      _reponses.every((c) => c.text.trim().isNotEmpty);

  Future<void> _choisitHeure() async {
    final choisie = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _heure ~/ 60, minute: _heure % 60),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (choisie != null) {
      setState(() => _heure = choisie.hour * 60 + choisie.minute);
    }
  }

  Future<void> _enregistre() async {
    final ancienne = widget.question;
    final q = Question(
      id: ancienne?.id,
      texte: _texte.text.trim(),
      pourquoi: _pourquoi.text.trim(),
      reponses: [for (final c in _reponses) c.text.trim()],
      heure: _heure,
      jours: _tache ? Question.tousLesJours : _jours,
      intervalle: _tache ? _intervalle : 0,
      depart: !_tache
          ? null
          : _prochaineChangee || ancienne == null || !ancienne.tache
          ? _prochaine
          : ancienne.depart,
    );
    if (ancienne == null) {
      await widget.base.enregistre(q);
    } else if (ancienne.nbReponses != q.nbReponses) {
      if (q.nbReponses == 2 &&
          !await _confirme(
            'Passer à 2 réponses ?',
            'Les « ${ancienne.reponses[1]} » déjà donnés seront effacés.',
            'Passer à 2',
          )) {
        return;
      }
      await widget.base.enregistreAvecNombre(q, ancienne.nbReponses);
    } else {
      await widget.base.enregistre(q);
    }
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _supprime() async {
    final q = widget.question!;
    if (!await _confirme(
      'Supprimer « ${q.texte} » ?',
      'Toutes ses réponses seront effacées. Pour la garder sans qu\'elle '
          'sonne : « Certains jours », sans aucun jour coché.',
      'Supprimer',
    )) {
      return;
    }
    await widget.base.supprime(q.id!);
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirme(String titre, String texte, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titre),
          content: Text(texte),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action, style: TextStyle(color: AppTheme.orange)),
            ),
          ],
        ),
      ) ??
      false;

  /// Intervalle précédent ([sens] = −1) ou suivant (+1).
  void _changeIntervalle(int sens) {
    final i = _intervalles.indexOf(_intervalle);
    final j = ((i < 0 ? 4 : i) + sens).clamp(0, _intervalles.length - 1);
    HapticFeedback.selectionClick();
    setState(() => _intervalle = _intervalles[j]);
  }

  Future<void> _choisitProchaine() async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _prochaine.isBefore(_aujourdhui) ? _aujourdhui : _prochaine,
      firstDate: _aujourdhui,
      lastDate: ajouteJours(_aujourdhui, 366),
    );
    if (choisie != null) {
      setState(() {
        _prochaine = jourDe(choisie);
        _prochaineChangee = true;
      });
    }
  }

  String _prochaineFr() {
    if (_prochaine == _aujourdhui) return 'Aujourd\'hui';
    if (_prochaine == ajouteJours(_aujourdhui, 1)) return 'Demain';
    return '${joursCourts[_prochaine.weekday - 1]} ${dateCourte(_prochaine)}';
  }

  void _ajouteReponse() =>
      setState(() => _reponses.insert(1, TextEditingController(text: 'Moyen')));

  void _retireMilieu() => setState(() => _reponses.removeAt(1).dispose());

  @override
  Widget build(BuildContext context) {
    final nouvelle = widget.question == null;
    final n = _reponses.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(nouvelle ? 'Nouvelle question' : 'Modifier'),
        actions: [
          if (!nouvelle)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _supprime,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _texte,
                autofocus: nouvelle,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(hintText: 'Sport ?'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('pourquoi'),
                controller: _pourquoi,
                maxLength: Question.longueurMaxPourquoi,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Pourquoi ? (dans la notification)',
                  counterText: '',
                  prefixIcon: Icon(
                    Icons.favorite_border_rounded,
                    size: 18,
                    color: AppTheme.vert,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < n; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _reponses[i],
                    maxLength: Question.longueurMaxReponse,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      counterText: '',
                      prefixIcon: Icon(
                        Icons.circle,
                        size: 12,
                        color: AppTheme.couleurReponse(i, n),
                      ),
                      hintText: _libelles[n]![i],
                      suffixIcon: n == 3 && i == 1
                          ? IconButton(
                              tooltip: 'Retirer',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: _retireMilieu,
                            )
                          : null,
                    ),
                  ),
                ),
              if (n == 2)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _ajouteReponse,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Réponse du milieu'),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: _Titre('Heure', bas: 0)),
                  OutlinedButton(
                    onPressed: _choisitHeure,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(120, 44),
                      side: BorderSide(color: AppTheme.trait),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      heureFr(_heure),
                      style: TextStyle(fontSize: 18, color: AppTheme.texte),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Titre('Quand'),
              Row(
                children: [
                  for (final (texte, tache) in const [
                    ('Certains jours', false),
                    ('Tous les N jours', true),
                  ])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: tache ? 6 : 0),
                        child: _Choix(
                          texte: texte,
                          choisi: _tache == tache,
                          onTap: () => setState(() => _tache = tache),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_tache) ...[
                _Titre(joursFr(_jours)),
                _Jours(
                  jours: _jours,
                  onChange: (j) => setState(() => _jours = j),
                ),
              ] else ...[
                Row(
                  children: [
                    const Expanded(child: _Titre('Tous les', bas: 0)),
                    IconButton(
                      tooltip: 'Plus souvent',
                      onPressed: _intervalle == _intervalles.first
                          ? null
                          : () => _changeIntervalle(-1),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        '$_intervalle jours',
                        key: const ValueKey('intervalle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: AppTheme.vert),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Moins souvent',
                      onPressed: _intervalle == _intervalles.last
                          ? null
                          : () => _changeIntervalle(1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(child: _Titre('Prochaine fois', bas: 0)),
                    OutlinedButton(
                      key: const ValueKey('prochaine'),
                      onPressed: _choisitProchaine,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(150, 44),
                        side: BorderSide(color: AppTheme.trait),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        _prochaineFr(),
                        style: TextStyle(fontSize: 16, color: AppTheme.texte),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _valide ? _enregistre : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppTheme.vert.withValues(alpha: 0.22),
                  foregroundColor: AppTheme.vert,
                  side: BorderSide(color: AppTheme.vert),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Enregistrer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un des deux choix de « Quand ».
class _Choix extends StatelessWidget {
  final String texte;
  final bool choisi;
  final VoidCallback onTap;

  const _Choix({
    required this.texte,
    required this.choisi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: choisi,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.vert.withValues(alpha: choisi ? 0.22 : 0),
          border: Border.all(color: choisi ? AppTheme.vert : AppTheme.trait),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          texte,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: choisi ? AppTheme.texte : AppTheme.doux,
            fontWeight: choisi ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _Titre extends StatelessWidget {
  final String texte;
  final double bas;

  const _Titre(this.texte, {this.bas = 8});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bas),
    child: Text(
      texte.toUpperCase(),
      style: TextStyle(color: AppTheme.doux, fontSize: 12, letterSpacing: 1.5),
    ),
  );
}

/// Les 7 jours en ronds, et les raccourcis.
class _Jours extends StatelessWidget {
  final int jours;
  final ValueChanged<int> onChange;

  const _Jours({required this.jours, required this.onChange});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            _Rond(
              texte: initialesJours[i],
              coche: jours & (1 << i) != 0,
              onTap: () => onChange(jours ^ (1 << i)),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final (texte, masque) in const [
            ('Tous', 0x7F),
            ('Semaine', 0x1F),
            ('Week-end', 0x60),
          ])
            Expanded(
              child: ActionChip(
                label: Text(texte, maxLines: 1, overflow: TextOverflow.fade),
                labelStyle: const TextStyle(fontSize: 12),
                labelPadding: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                onPressed: () => onChange(masque),
                side: BorderSide(
                  color: jours == masque ? AppTheme.vert : AppTheme.trait,
                ),
                backgroundColor: AppTheme.fond,
              ),
            ),
        ].expand((w) => [w, const SizedBox(width: 6)]).toList()..removeLast(),
      ),
    ],
  );
}

class _Rond extends StatelessWidget {
  final String texte;
  final bool coche;
  final VoidCallback onTap;

  const _Rond({required this.texte, required this.coche, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.vert.withValues(alpha: coche ? 0.28 : 0),
        border: Border.all(color: coche ? AppTheme.vert : AppTheme.trait),
      ),
      child: Text(
        texte,
        style: TextStyle(
          color: coche ? AppTheme.texte : AppTheme.doux,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
