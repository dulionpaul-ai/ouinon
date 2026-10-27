import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/suggestions.dart';
import '../models/question.dart';
import '../utils/date_fr.dart';
import '../theme/app_theme.dart';
import '../widgets/rond.dart';

/// Ajout ou modification d'une question : texte, 2 ou 3 réponses (la
/// meilleure d'abord), heure de la notification, jours.
class EditionQuestionScreen extends StatefulWidget {
  final Base base;

  /// Nulle pour une nouvelle question.
  final Question? question;

  const EditionQuestionScreen({super.key, required this.base, this.question});

  @override
  State<EditionQuestionScreen> createState() => _EditionQuestionScreenState();
}

class _EditionQuestionScreenState extends State<EditionQuestionScreen> {
  static const _parDefaut = {
    2: ['Oui', 'Non'],
    3: ['Bien', 'Moyen', 'Pas bien'],
  };

  late final TextEditingController _texte;
  late List<TextEditingController> _reponses;
  late int _heure;
  late int _jours;
  String? _erreur;
  List<List<String>> _suggestions = const [];

  /// Cadran de l'heure ouvert : « Enregistrer » est caché.
  bool _choixHeure = false;

  bool get _nouvelle => widget.question == null;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _texte = TextEditingController(text: q?.texte ?? '');
    _reponses = [
      for (final r in q?.reponses ?? _parDefaut[2]!)
        TextEditingController(text: r),
    ];
    _heure = q?.heure ?? 21 * 60;
    _jours = q?.jours ?? Question.tousLesJours;
    Suggestions.charge().then((s) {
      if (mounted) setState(() => _suggestions = s);
    });
  }

  @override
  void dispose() {
    _texte.dispose();
    for (final c in _reponses) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _actuelles => [for (final c in _reponses) c.text.trim()];

  bool _pareil(List<String> a, List<String> b) =>
      a.length == b.length && a.indexed.every((e) => b[e.$1] == e.$2);

  void _applique(List<String> m) => setState(() {
    for (final c in _reponses) {
      c.dispose();
    }
    _reponses = [for (final r in m) TextEditingController(text: r)];
  });

  Future<void> _enregistreSuggestions(List<List<String>> s) async {
    setState(() => _suggestions = s);
    await Suggestions.enregistre(s);
  }

  /// Fenêtre pour créer (`index` nul) ou modifier une suggestion.
  Future<void> _editeSuggestion({int? index}) async {
    final depart = index == null
        ? List.filled(_reponses.length, '')
        : _suggestions[index];
    final valeurs = await showDialog<List<String>>(
      context: context,
      builder: (context) => _FenetreSuggestion(
        titre: index == null ? 'Nouvelle suggestion' : 'Modifier la suggestion',
        depart: depart,
      ),
    );
    if (valeurs == null || valeurs.any((v) => v.isEmpty)) return;
    final liste = [..._suggestions];
    if (index == null) {
      liste.add(valeurs);
    } else {
      liste[index] = valeurs;
    }
    await _enregistreSuggestions(liste);
    _applique(valeurs);
  }

  Future<void> _optionsSuggestion(int index) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(context, 'modifier'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Supprimer'),
              onTap: () => Navigator.pop(context, 'supprimer'),
            ),
          ],
        ),
      ),
    );
    if (choix == 'modifier') {
      await _editeSuggestion(index: index);
    } else if (choix == 'supprimer') {
      await _enregistreSuggestions([..._suggestions]..removeAt(index));
    }
  }

  void _nombre(int nb) {
    final actuelles = _actuelles;
    final connues = [..._suggestions, ..._parDefaut.values];
    final inchangees = connues.any((m) => _pareil(m, actuelles));
    if (inchangees) {
      _applique(
        _suggestions.firstWhere(
          (m) => m.length == nb,
          orElse: () => _parDefaut[nb]!,
        ),
      );
    } else if (nb > _reponses.length) {
      setState(
        () => _reponses = [
          _reponses[0],
          TextEditingController(),
          ..._reponses.skip(1),
        ],
      );
    } else {
      setState(() => _reponses.removeAt(1).dispose());
    }
  }

  /// Cadran de l'heure, sans le bouton clavier ; « Enregistrer » est caché
  /// pendant le choix (on croyait qu'il validait l'heure).
  Future<void> _choisitHeure() async {
    setState(() => _choixHeure = true);
    final choisie = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: TimeOfDay(hour: _heure ~/ 60, minute: _heure % 60),
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    if (!mounted) return;
    setState(() {
      _choixHeure = false;
      if (choisie != null) _heure = choisie.hour * 60 + choisie.minute;
    });
  }

  Future<void> _enregistre() async {
    final texte = _texte.text.trim();
    final reponses = [for (final c in _reponses) c.text.trim()];
    final erreur = texte.isEmpty
        ? 'Écris la question.'
        : reponses.any((r) => r.isEmpty)
        ? 'Donne un nom à chaque réponse.'
        : reponses.toSet().length != reponses.length
        ? 'Les réponses doivent être différentes.'
        : _jours == 0
        ? 'Choisis au moins un jour.'
        : null;
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    final ancienne = widget.question;
    final modifiee =
        (ancienne ?? Question(texte: '', reponses: reponses, heure: 0)).copie(
          texte: texte,
          reponses: reponses,
          heure: _heure,
          jours: _jours,
        );
    if (ancienne == null || ancienne.nbReponses == reponses.length) {
      await widget.base.enregistre(modifiee);
    } else {
      if (!await _confirmeNombre(ancienne, reponses)) return;
      await widget.base.enregistreAvecNombre(modifiee, ancienne.nbReponses);
    }
    if (mounted) Navigator.pop(context);
  }

  /// Changer le nombre de réponses d'une question qui a un historique :
  /// on dit ce que deviennent les réponses passées.
  Future<bool> _confirmeNombre(Question q, List<String> nouvelles) async {
    final passees = await widget.base.reponsesDe(q.id!);
    if (passees.isEmpty || !mounted) return true;
    final String message;
    if (q.nbReponses == 2) {
      message =
          'Tes ${passees.length} réponses passées sont gardées : '
          '« ${q.reponses[0]} » devient « ${nouvelles[0]} » et '
          '« ${q.reponses[1]} » devient « ${nouvelles[2]} ».';
    } else {
      final milieu = passees.values.where((c) => c == 1).length;
      final effacees = switch (milieu) {
        0 => 'Aucune réponse « ${q.reponses[1]} » à effacer.',
        1 => '1 réponse « ${q.reponses[1]} » sera effacée.',
        _ => '$milieu réponses « ${q.reponses[1]} » seront effacées.',
      };
      message =
          '$effacees Les autres sont gardées : « ${q.reponses[0]} » devient '
          '« ${nouvelles[0]} » et « ${q.reponses[2]} » devient '
          '« ${nouvelles[1]} ».';
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Passer à ${nouvelles.length} réponses ?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Changer'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _pause() async {
    final q = widget.question!;
    await widget.base.enregistre(q.copie(active: !q.active));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _supprime() async {
    final q = widget.question!;
    final nb = (await widget.base.reponsesDe(q.id!)).length;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la question ?'),
        content: Text(
          nb == 0
              ? 'Elle n\'a encore aucune réponse.'
              : 'Ses $nb réponse${nb > 1 ? 's' : ''} seront effacées. '
                    'Pour les garder, mets-la plutôt en pause.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.base.supprime(q.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final theme = Theme.of(context);
    final doux = TextStyle(color: t.doux, height: 1.35);
    final nb = _reponses.length;
    final q = widget.question;
    Widget titre(String texte) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Text(texte, style: theme.textTheme.titleMedium),
    );
    return Scaffold(
      appBar: AppBar(title: Text(_nouvelle ? 'Nouvelle question' : 'Modifier')),
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
          titre('Question'),
          TextField(
            controller: _texte,
            autofocus: _nouvelle,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Ex. : Bu assez d\'eau ?',
              counterText: '',
            ),
          ),
          titre('Réponses'),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            child: Text(
              'La meilleure en haut (vert), la moins bonne en bas (rouge).',
              style: doux,
            ),
          ),
          ChoixPilules<int>(
            options: const [(2, '2 réponses'), (3, '3 réponses')],
            valeur: nb,
            onChoix: (n) {
              if (n != nb) _nombre(n);
            },
          ),
          const SizedBox(height: 10),
          _blocSuggestions(doux),
          const SizedBox(height: 12),
          for (final (i, c) in _reponses.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ValueKey('reponse$i'),
                controller: c,
                maxLength: Question.longueurMaxReponse,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: i == 0
                      ? 'Meilleure réponse'
                      : i == nb - 1
                      ? 'Moins bonne réponse'
                      : 'Entre les deux',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 18, right: 12),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.couleurReponse(context, i, nb),
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(),
                ),
              ),
            ),
          titre('Notification'),
          CarteRonde(
            onTap: _choisitHeure,
            padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Heure',
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
                        heureFr(_heure),
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
          const SizedBox(height: 10),
          CarteRonde(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, contraintes) {
                    final taille = ((contraintes.maxWidth - 6 * 4) / 7).clamp(
                      28.0,
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
                    // Largeur selon la longueur du libellé : même taille
                    // de texte pour les trois.
                    for (final (i, (masque, libelle, part)) in const [
                      (0x7F, 'Tous les jours', 14),
                      (0x1F, 'Semaine', 9),
                      (0x60, 'Week-end', 10),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        flex: part,
                        child: PiluleChoix(
                          libelle,
                          centree: true,
                          choisie: _jours == masque,
                          onTap: () => setState(() => _jours = masque),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _erreur!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (q != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _pause,
              child: Text(q.active ? 'Mettre en pause' : 'Reprendre'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _supprime,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        ],
      ),
    );
  }

  /// Les suggestions du nombre de réponses choisi : toucher pour remplir,
  /// appui long pour modifier ou supprimer, « + » pour en créer une.
  Widget _blocSuggestions(TextStyle doux) {
    final nb = _reponses.length;
    final actuelles = _actuelles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, m) in _suggestions.indexed)
              if (m.length == nb)
                PiluleChoix(
                  m.join(' / '),
                  choisie: _pareil(m, actuelles),
                  onTap: () => _applique(m),
                  onLongPress: () => _optionsSuggestion(i),
                ),
            PiluleChoix('+ Autre', onTap: () => _editeSuggestion()),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(
            'Touche une suggestion pour remplir ; appui long pour la '
            'modifier ou la supprimer.',
            style: doux.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Fenêtre de saisie d'une suggestion ; rend les réponses saisies (nulle si
/// annulée). Garde ses propres champs jusqu'à sa fermeture complète.
class _FenetreSuggestion extends StatefulWidget {
  final String titre;
  final List<String> depart;

  const _FenetreSuggestion({required this.titre, required this.depart});

  @override
  State<_FenetreSuggestion> createState() => _FenetreSuggestionState();
}

class _FenetreSuggestionState extends State<_FenetreSuggestion> {
  late final _champs = [
    for (final r in widget.depart) TextEditingController(text: r),
  ];

  @override
  void dispose() {
    for (final c in _champs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, c) in _champs.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: c,
                autofocus: i == 0,
                maxLength: Question.longueurMaxReponse,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: i == 0
                      ? 'Meilleure réponse'
                      : i == _champs.length - 1
                      ? 'Moins bonne réponse'
                      : 'Entre les deux',
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, [for (final c in _champs) c.text.trim()]),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
