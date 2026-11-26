import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/apparence_distante.dart';
import '../data/base.dart';
import '../data/notifications.dart';
import '../models/apparence.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../utils/frequence.dart';
import '../utils/jour.dart';
import 'questions_screen.dart';

/// Créer ou modifier une habitude, l'écran clé de l'appli (thème HUD,
/// 26/11/2026). En haut, l'aperçu en direct de sa notification ; puis,
/// numérotés : la question, son « pourquoi », 2 ou 3 réponses (la moins
/// bonne à gauche), l'heure, les jours, et « Répéter » (chaque jour coché
/// ou tous les N jours, pour une tâche). Aucun jour : en pause.
class QuestionScreen extends StatefulWidget {
  final Base base;

  /// Nulle : nouvelle question.
  final Question? question;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const QuestionScreen({
    super.key,
    required this.base,
    this.question,
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
  late int _jours = widget.question?.jours ?? 0;
  late int _intervalle = widget.question?.intervalle ?? 0;

  /// La série en cours, pour l'aperçu de la notification.
  int _serie = 0;

  /// Les intervalles proposés (0 : chaque jour coché).
  static const _intervalles = [0, 2, 3, 4, 5, 7, 10, 14, 21, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    ApparenceDistante.courante.addListener(_redessine);
    _litSerie();
  }

  void _redessine() {
    if (mounted) setState(() {});
  }

  Future<void> _litSerie() async {
    final q = widget.question;
    if (q == null) return;
    final r = (await widget.base.toutesLesReponses())[q.id] ?? const {};
    if (mounted) setState(() => _serie = serie(q, widget.maintenant(), r));
  }

  @override
  void dispose() {
    ApparenceDistante.courante.removeListener(_redessine);
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

  Question get _brouillon => Question(
    id: widget.question?.id,
    texte: _texte.text.trim(),
    pourquoi: _pourquoi.text.trim(),
    reponses: [for (final c in _reponses) c.text.trim()],
    heure: _heure,
    jours: _jours,
    intervalle: _intervalle,
  );

  Future<void> _choisitHeure() async {
    HapticFeedback.selectionClick();
    final choisie = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _heure ~/ 60, minute: _heure % 60),
      initialEntryMode: TimePickerEntryMode.dialOnly,
      builder: (context, enfant) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    if (choisie != null) {
      setState(() => _heure = choisie.hour * 60 + choisie.minute);
    }
  }

  Future<void> _enregistre() async {
    final ancienne = widget.question;
    final q = _brouillon;
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
          'sonne, décoche tous ses jours.',
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
              child: Text(action, style: TextStyle(color: AppTheme.moinsBonne)),
            ),
          ],
        ),
      ) ??
      false;

  /// Intervalle précédent ([sens] = −1) ou suivant (+1). Choisir un
  /// intervalle sans aucun jour coché coche tous les jours.
  void _changeIntervalle(int sens) {
    final i = _intervalles.indexOf(_intervalle);
    final j = ((i < 0 ? 0 : i) + sens).clamp(0, _intervalles.length - 1);
    HapticFeedback.selectionClick();
    setState(() {
      _intervalle = _intervalles[j];
      if (_intervalle > 0 && _jours == 0) _jours = Question.tousLesJours;
    });
  }

  void _ajouteReponse() {
    HapticFeedback.selectionClick();
    setState(() => _reponses.insert(1, TextEditingController(text: 'Moyen')));
  }

  void _retireMilieu() {
    HapticFeedback.selectionClick();
    setState(() => _reponses.removeAt(1).dispose());
  }

  @override
  Widget build(BuildContext context) {
    final a = Apparence.actuelle;
    final nouvelle = widget.question == null;
    final n = _reponses.length;
    return Scaffold(
      backgroundColor: a.fond,
      body: CustomPaint(
        painter: a.grille ? Quadrillage(a.trait) : null,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(
                        a.t('retour'),
                        style: AppTheme.etiquette(couleur: a.meilleure),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        nouvelle ? 'NOUVELLE' : 'HABITUDE',
                        textAlign: TextAlign.center,
                        style: AppTheme.etiquette(),
                      ),
                    ),
                    if (nouvelle)
                      const SizedBox(width: 64)
                    else
                      TextButton(
                        onPressed: _supprime,
                        child: Text(
                          a.t('supprimer'),
                          style: AppTheme.etiquette(couleur: a.moinsBonne),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    if (a.voirApercu) ...[
                      _Apercu(question: _brouillon, serie: _serie),
                      const SizedBox(height: 12),
                    ],
                    _Etiquette('01 · ${a.t('question')}'),
                    TextField(
                      controller: _texte,
                      autofocus: nouvelle,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: a.tailleQuestion,
                        fontWeight: FontWeight.w600,
                        color: a.texte,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Sport ?',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: a.meilleure),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _Etiquette('02 · ${a.t('pourquoi')}'),
                    TextField(
                      key: const ValueKey('pourquoi'),
                      controller: _pourquoi,
                      maxLength: Question.longueurMaxPourquoi,
                      minLines: 1,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(fontSize: 16, color: a.texte),
                      decoration: const InputDecoration(
                        hintText: 'Pour… (dans la notification)',
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    _Etiquette('03 · ${a.t('reponses')}'),
                    Row(
                      children: [
                        // La moins bonne à gauche, la meilleure à droite.
                        for (var i = n - 1; i >= 0; i--) ...[
                          Expanded(
                            child: _ChampReponse(
                              controleur: _reponses[i],
                              couleur: AppTheme.couleurReponse(i, n),
                              onChanged: () => setState(() {}),
                            ),
                          ),
                          if (i > 0) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: n == 2 ? _ajouteReponse : _retireMilieu,
                        child: Text(
                          n == 2
                              ? '+ RÉPONSE DU MILIEU'
                              : '× RÉPONSE DU MILIEU',
                          style: AppTheme.etiquette(couleur: a.doux),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _Etiquette('04 · ${a.t('heure')}')),
                        Semantics(
                          button: true,
                          label: 'Heure',
                          child: GestureDetector(
                            onTap: _choisitHeure,
                            child: Text(
                              heureMono(_heure),
                              style: TextStyle(
                                fontFamily: AppTheme.mono,
                                fontSize: 34,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 2,
                                height: 1,
                                color: a.meilleure,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Etiquette('05 · ${a.t('jours')} · ${joursFr(_jours)}'),
                    _Jours(
                      jours: _jours,
                      onChange: (j) => setState(() => _jours = j),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: a.trait),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Etiquette('06 · ${a.t('repeter')}', bas: 0),
                          ),
                          IconButton(
                            tooltip: 'Plus souvent',
                            color: a.texte,
                            onPressed: _intervalle == 0
                                ? null
                                : () => _changeIntervalle(-1),
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          SizedBox(
                            width: 140,
                            child: Text(
                              _intervalle == 0
                                  ? 'JOURS COCHÉS'
                                  : 'TOUS LES $_intervalle J',
                              key: const ValueKey('intervalle'),
                              textAlign: TextAlign.center,
                              style: AppTheme.etiquette(
                                couleur: _intervalle == 0
                                    ? a.texte
                                    : a.meilleure,
                                taille: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Moins souvent',
                            color: a.texte,
                            onPressed: _intervalle == _intervalles.last
                                ? null
                                : () => _changeIntervalle(1),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: BoutonHud(
                  texte: a.t('enregistrer'),
                  plein: true,
                  onTap: _valide ? _enregistre : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'aperçu de la notification, en direct : comme sur le téléphone, avec
/// la série à droite et les boutons dessous.
class _Apercu extends StatelessWidget {
  final Question question;
  final int serie;

  const _Apercu({required this.question, required this.serie});

  @override
  Widget build(BuildContext context) {
    final a = Apparence.actuelle;
    final q = question;
    final corps = q.pourquoi.isEmpty ? null : q.pourquoi;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: a.surface.withValues(alpha: 0.9),
        border: Border.all(color: a.trait),
      ),
      foregroundDecoration: _Equerres(a.meilleure),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.t('apercu'), style: AppTheme.etiquette(taille: 10)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.texte.isEmpty ? '…' : titreNotif(q, a),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: a.texte,
                      ),
                    ),
                    if (corps != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        corps,
                        style: TextStyle(fontSize: 13, color: a.doux),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: a.fond,
                  border: Border.all(color: a.meilleure),
                ),
                child: Text(
                  serie.toString().padLeft(2, '0'),
                  style: AppTheme.etiquette(
                    couleur: a.meilleure,
                    taille: 14,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 22,
            children: [
              for (var i = q.nbReponses - 1; i >= 0; i--)
                Text(
                  (a.majuscules ? q.reponses[i].toUpperCase() : q.reponses[i])
                      .trim(),
                  style: AppTheme.etiquette(
                    couleur: AppTheme.couleurReponse(i, q.nbReponses),
                    taille: 12,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Les équerres d'accent aux coins d'un cadre.
class _Equerres extends Decoration {
  final Color couleur;

  const _Equerres(this.couleur);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _Peintre(couleur);
}

class _Peintre extends BoxPainter {
  final Color couleur;

  _Peintre(this.couleur);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final r = offset & configuration.size!;
    final p = Paint()
      ..color = couleur
      ..strokeWidth = 2;
    const l = 10.0;
    canvas
      ..drawLine(r.topLeft, r.topLeft.translate(l, 0), p)
      ..drawLine(r.topLeft, r.topLeft.translate(0, l), p)
      ..drawLine(r.bottomRight, r.bottomRight.translate(-l, 0), p)
      ..drawLine(r.bottomRight, r.bottomRight.translate(0, -l), p);
  }
}

class _Etiquette extends StatelessWidget {
  final String texte;
  final double bas;

  const _Etiquette(this.texte, {this.bas = 4});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bas),
    child: Text(texte.toUpperCase(), style: AppTheme.etiquette(taille: 10.5)),
  );
}

/// Une réponse à écrire, dans un cadre à sa couleur.
class _ChampReponse extends StatelessWidget {
  final TextEditingController controleur;
  final Color couleur;
  final VoidCallback onChanged;

  const _ChampReponse({
    required this.controleur,
    required this.couleur,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder bord(double alpha) => OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: couleur.withValues(alpha: alpha)),
    );
    return TextField(
      controller: controleur,
      maxLength: Question.longueurMaxReponse,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => onChanged(),
      style: TextStyle(
        fontFamily: AppTheme.mono,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: couleur,
      ),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: couleur.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        border: bord(0.5),
        enabledBorder: bord(0.5),
        focusedBorder: bord(1),
      ),
    );
  }
}

/// Les 7 jours en cases carrées, et les raccourcis.
class _Jours extends StatelessWidget {
  final int jours;
  final ValueChanged<int> onChange;

  const _Jours({required this.jours, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final a = Apparence.actuelle;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              Expanded(
                child: _Case(
                  texte: initialesJours[i],
                  coche: jours & (1 << i) != 0,
                  onTap: () => onChange(jours ^ (1 << i)),
                ),
              ),
              if (i < 6) const SizedBox(width: 4),
            ],
          ],
        ),
        Row(
          children: [
            for (final (texte, masque) in const [
              ('Tous', 0x7F),
              ('Semaine', 0x1F),
              ('Week-end', 0x60),
            ])
              Expanded(
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onChange(masque);
                  },
                  child: Text(
                    texte.toUpperCase(),
                    style: AppTheme.etiquette(
                      couleur: jours == masque ? a.meilleure : a.doux,
                      taille: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Case extends StatelessWidget {
  final String texte;
  final bool coche;
  final VoidCallback onTap;

  const _Case({required this.texte, required this.coche, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = Apparence.actuelle;
    return Semantics(
      button: true,
      selected: coche,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: a.meilleure.withValues(alpha: coche ? 0.16 : 0),
            border: Border.all(color: coche ? a.meilleure : a.trait),
          ),
          child: Text(
            texte,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontWeight: FontWeight.w700,
              color: coche ? a.meilleure : a.doux,
            ),
          ),
        ),
      ),
    );
  }
}
