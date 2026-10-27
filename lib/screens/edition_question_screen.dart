import 'package:flutter/material.dart';

import '../data/base.dart';
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
  late final TextEditingController _texte;

  /// Famille facultative (« Sport »), et celles qui existent déjà.
  late final TextEditingController _famille;
  List<String> _familles = const [];
  late List<TextEditingController> _reponses;
  late int _heure;
  late int _jours;
  String? _erreur;

  /// Cadran de l'heure ouvert : « Enregistrer » est caché.
  bool _choixHeure = false;

  bool get _nouvelle => widget.question == null;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _texte = TextEditingController(text: q?.texte ?? '');
    _famille = TextEditingController(text: q?.famille ?? '');
    _famille.addListener(() => setState(() {}));
    widget.base.questions().then((qs) {
      final noms = {
        for (final x in qs)
          if (x.famille?.trim() case final f? when f.isNotEmpty) f,
      }.toList()..sort();
      if (mounted) setState(() => _familles = noms);
    });
    _reponses = [
      for (final r in q?.reponses ?? const ['', ''])
        TextEditingController(text: r),
    ];
    _heure = q?.heure ?? 21 * 60;
    // Aucun jour par défaut ; sans jour, la question est en pause
    // (cahier, écran 1, validé par Paul le 27/10/2026).
    _jours = q?.jours ?? 0;
  }

  @override
  void dispose() {
    _texte.dispose();
    _famille.dispose();
    for (final c in _reponses) {
      c.dispose();
    }
    super.dispose();
  }

  /// 2 ou 3 réponses : celle du milieu s'ajoute ou s'enlève.
  void _nombre(int nb) {
    if (nb > _reponses.length) {
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
          famille: () =>
              _famille.text.trim().isEmpty ? null : _famille.text.trim(),
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
          titre('Famille'),
          TextField(
            key: const ValueKey('famille'),
            controller: _famille,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 24,
            decoration: const InputDecoration(
              hintText: 'Facultatif. Ex. : Sport',
              counterText: '',
            ),
          ),
          if (_familles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in _familles)
                  PiluleChoix(
                    f,
                    key: ValueKey('famille-$f'),
                    choisie: _famille.text.trim() == f,
                    onTap: () => setState(
                      () => _famille.text = _famille.text.trim() == f ? '' : f,
                    ),
                  ),
              ],
            ),
          ],
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
}
