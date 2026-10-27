import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/question.dart';
import '../theme/theme.dart';
import '../utils/date_fr.dart';

/// Créer ou modifier une question (cahier, écran 1, 27/10/2026) : le
/// texte, les 2 ou 3 réponses écrites à la main (pas de modèles), l'heure
/// et les jours. Aucun jour coché par défaut ; raccourcis « Tous les
/// jours », « En semaine », « Le week-end ». Sans aucun jour, la question
/// ne sonne jamais (en pause).
///
/// Les réponses vont de la meilleure à la moins bonne (indice 0 =
/// meilleure) ; une troisième se glisse entre les deux. Passer de 3 à 2
/// efface les réponses du milieu déjà données, après confirmation.
class QuestionScreen extends StatefulWidget {
  final Base base;

  /// Nulle pour une nouvelle question.
  final Question? question;

  const QuestionScreen({super.key, required this.base, this.question});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  late final _texte = TextEditingController(text: widget.question?.texte);
  late final TextEditingController _meilleure;
  late final TextEditingController _milieu;
  late final TextEditingController _moinsBonne;
  late bool _trois;
  late int _heure = widget.question?.heure ?? 21 * 60;
  late int _jours = widget.question?.jours ?? 0;

  bool get _nouvelle => widget.question == null;

  @override
  void initState() {
    super.initState();
    final r = widget.question?.reponses ?? const [];
    _trois = r.length == 3;
    _meilleure = TextEditingController(text: r.isNotEmpty ? r.first : '');
    _milieu = TextEditingController(text: _trois ? r[1] : '');
    _moinsBonne = TextEditingController(text: r.length > 1 ? r.last : '');
    for (final c in [_texte, _meilleure, _milieu, _moinsBonne]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_texte, _meilleure, _milieu, _moinsBonne]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _reponses => [
    _meilleure.text.trim(),
    if (_trois) _milieu.text.trim(),
    _moinsBonne.text.trim(),
  ];

  bool get _complete =>
      _texte.text.trim().isNotEmpty && _reponses.every((r) => r.isNotEmpty);

  Future<void> _choisitHeure() async {
    final choix = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _heure ~/ 60, minute: _heure % 60),
      helpText: 'Heure de la notification',
    );
    if (choix != null) setState(() => _heure = choix.hour * 60 + choix.minute);
  }

  Future<void> _enregistre() async {
    if (!_complete) return;
    final avant = widget.question;
    final q = Question(
      id: avant?.id,
      texte: _texte.text.trim(),
      reponses: _reponses,
      heure: _heure,
      jours: _jours,
      ordre: avant?.ordre ?? 0,
    );
    if (avant == null) {
      await widget.base.enregistre(q);
    } else if (avant.nbReponses != q.nbReponses) {
      if (avant.nbReponses == 3 && !await _confirmeMoinsDeReponses()) return;
      await widget.base.enregistreAvecNombre(q, avant.nbReponses);
    } else {
      await widget.base.enregistre(q);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmeMoinsDeReponses() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Passer à 2 réponses ?'),
          content: Text(
            'Les jours où tu as répondu « ${widget.question!.reponses[1]} » '
            'seront effacés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Effacer'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _supprime() async {
    final q = widget.question!;
    final oui = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${q.texte} » ?'),
        content: const Text('Ses réponses passées seront effacées aussi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Couleurs.rouge),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (oui != true) return;
    await widget.base.supprime(q.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nouvelle ? 'Nouvelle question' : 'Modifier'),
        actions: [
          if (!_nouvelle)
            IconButton(
              key: const ValueKey('supprimer'),
              tooltip: 'Supprimer',
              onPressed: _supprime,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            key: const ValueKey('texte'),
            controller: _texte,
            autofocus: _nouvelle,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
              labelText: 'Question',
              hintText: 'Ex. : Sport ?',
            ),
          ),
          const _Titre('Réponses'),
          _Champ(
            cle: 'meilleure',
            controleur: _meilleure,
            libelle: 'Meilleure réponse',
            exemple: 'Ex. : Oui',
          ),
          if (_trois)
            _Champ(
              cle: 'milieu',
              controleur: _milieu,
              libelle: 'Entre les deux',
              exemple: 'Ex. : Un peu',
              onRetire: () => setState(() {
                _trois = false;
                _milieu.clear();
              }),
            ),
          _Champ(
            cle: 'moins-bonne',
            controleur: _moinsBonne,
            libelle: 'Moins bonne réponse',
            exemple: 'Ex. : Non',
          ),
          if (!_trois)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('troisieme'),
                onPressed: () => setState(() => _trois = true),
                icon: const Icon(Icons.add),
                label: const Text('Une réponse entre les deux'),
              ),
            ),
          const _Titre('Heure'),
          InkWell(
            key: const ValueKey('heure'),
            onTap: _choisitHeure,
            child: Container(
              height: 52,
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Couleurs.trait)),
              ),
              child: Text(
                heureFr(_heure),
                style: const TextStyle(fontSize: 20, color: Couleurs.bleu),
              ),
            ),
          ),
          const _Titre('Jours'),
          _Jours(jours: _jours, onChange: (j) => setState(() => _jours = j)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            children: [
              for (final (cle, libelle, masque) in const [
                ('tous', 'Tous les jours', 0x7F),
                ('semaine', 'En semaine', 0x1F),
                ('week-end', 'Le week-end', 0x60),
              ])
                TextButton(
                  key: ValueKey('raccourci-$cle'),
                  onPressed: () => setState(() => _jours = masque),
                  child: Text(libelle),
                ),
            ],
          ),
          if (_jours == 0)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Aucun jour : la question ne sonnera pas.',
                style: TextStyle(color: Couleurs.gris, fontSize: 14),
              ),
            ),
          const SizedBox(height: 28),
          FilledButton(
            key: const ValueKey('enregistrer'),
            onPressed: _complete ? _enregistre : null,
            child: const Text('Enregistrer', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  final String texte;

  const _Titre(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 4),
    child: Text(
      texte,
      style: const TextStyle(
        color: Couleurs.gris,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Champ extends StatelessWidget {
  final String cle;
  final TextEditingController controleur;
  final String libelle;
  final String exemple;
  final VoidCallback? onRetire;

  const _Champ({
    required this.cle,
    required this.controleur,
    required this.libelle,
    required this.exemple,
    this.onRetire,
  });

  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey('reponse-$cle'),
    controller: controleur,
    maxLength: Question.longueurMaxReponse,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: libelle,
      hintText: exemple,
      counterText: '',
      suffixIcon: onRetire == null
          ? null
          : IconButton(
              tooltip: 'Retirer cette réponse',
              onPressed: onRetire,
              icon: const Icon(Icons.close),
            ),
    ),
  );
}

/// Les 7 jours, de lundi à dimanche : une case par jour, à cocher.
class _Jours extends StatelessWidget {
  final int jours;
  final ValueChanged<int> onChange;

  const _Jours({required this.jours, required this.onChange});

  @override
  Widget build(BuildContext context) {
    const lettres = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: jours & (1 << i) != 0,
              label: joursCourts[i],
              child: GestureDetector(
                key: ValueKey('jour-$i'),
                onTap: () => onChange(jours ^ (1 << i)),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: jours & (1 << i) != 0
                        ? Couleurs.bleu
                        : Colors.transparent,
                    border: Border.all(
                      color: jours & (1 << i) != 0
                          ? Couleurs.bleu
                          : Couleurs.trait,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lettres[i],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: jours & (1 << i) != 0
                          ? Colors.white
                          : Couleurs.encre,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
