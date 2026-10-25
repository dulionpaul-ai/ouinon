import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../models/creneau.dart';
import '../models/question.dart';
import '../models/tache.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/stats.dart';
import '../theme/app_theme.dart';
import '../widgets/boutons_reponse.dart';
import '../widgets/rond.dart';
import 'edition_tache_screen.dart';
import 'preparer_screen.dart';
import 'reglages_screen.dart';

/// Aujourd'hui (revue du 25/10/2026) : les questions du jour en lignes
/// compactes, puis « Ma journée » (heure, rond à cocher, texte), avec les
/// créneaux fixes en gris. On glisse le doigt vers la droite pour la
/// veille, jamais après aujourd'hui ; la roue dentée mène aux Réglages.
class AujourdhuiScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const AujourdhuiScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<AujourdhuiScreen> createState() => _AujourdhuiScreenState();
}

class _AujourdhuiScreenState extends State<AujourdhuiScreen> {
  /// Page 0 = aujourd'hui, page 1 = hier… (dix ans en arrière au plus).
  static const _joursMax = 3650;

  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pages,
      // Inversé : glisser vers la droite montre la veille, et on ne peut
      // pas aller après aujourd'hui (page 0).
      reverse: true,
      itemCount: _joursMax,
      itemBuilder: (context, page) => _PageJour(
        key: ValueKey(page),
        base: widget.base,
        maintenant: widget.maintenant,
        decalage: -page,
      ),
    );
  }
}

class _PageJour extends StatefulWidget {
  final Base base;
  final DateTime Function() maintenant;

  /// Décalage par rapport à aujourd'hui (0 = aujourd'hui, −1 = hier…).
  final int decalage;

  const _PageJour({
    super.key,
    required this.base,
    required this.maintenant,
    required this.decalage,
  });

  @override
  State<_PageJour> createState() => _PageJourState();
}

class _PageJourState extends State<_PageJour> {
  int get _decalage => widget.decalage;
  List<Question> _questions = const [];
  Map<int, int> _reponses = const {};
  List<Tache> _taches = const [];
  List<Creneau> _creneaux = const [];
  bool _charge = false;

  DateTime get _jour => ajouteJours(jourDe(widget.maintenant()), _decalage);

  @override
  void initState() {
    super.initState();
    widget.base.changements.addListener(_recharge);
    _recharge();
  }

  @override
  void dispose() {
    widget.base.changements.removeListener(_recharge);
    super.dispose();
  }

  /// Séries en cours au jour affiché : id de la question → jours.
  Map<int, int> _series = const {};

  Future<void> _recharge() async {
    final jour = _jour;
    final questions = await widget.base.questions();
    final reponses = await widget.base.reponsesDuJour(jour);
    final toutes = await widget.base.toutesLesReponses();
    final taches = await widget.base.tachesDu(jour);
    final creneaux = await widget.base.creneauxDu(jour);
    if (!mounted || jour != _jour) return;
    setState(() {
      _questions = [
        for (final q in questions)
          if (q.active && q.revientLe(jour.weekday)) q,
      ];
      _reponses = reponses;
      _taches = taches;
      _creneaux = creneaux;
      _series = {
        for (final q in _questions)
          q.id!: serie(q, toutes[q.id] ?? const {}, jour).actuelle,
      };
      _charge = true;
    });
  }

  Future<void> _choisit(Question q, int? choix) async {
    final jour = _jour;
    if (choix == null) {
      await widget.base.efface(q.id!, jour);
    } else {
      await widget.base.repond(q.id!, jour, choix);
      try {
        await Notifications.instance.retire(q.id!, jour);
      } catch (_) {}
    }
  }

  Future<void> _repondTache(Tache tache, int? etat) async {
    await widget.base.repondTache(tache.id!, etat);
    if (etat != null) {
      try {
        await Notifications.instance.retireTache(tache.id!);
      } catch (_) {}
    }
  }

  void _ouvreTache(Tache tache) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionTacheScreen(
        base: widget.base,
        tache: tache,
        jour: tache.jour,
        maintenant: widget.maintenant,
      ),
    ),
  );

  String get _titre => switch (_decalage) {
    0 => 'Aujourd\'hui',
    -1 => 'Hier',
    _ => majuscule(jourEtDate(_jour).split(' ').first),
  };

  /// Questions dont on a rouvert les boutons après avoir répondu.
  final _rouvertes = <int>{};

  void _prepare() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PreparerScreen(
        base: widget.base,
        jour: _jour,
        maintenant: widget.maintenant,
      ),
    ),
  );

  /// Toucher une chose de la journée : répondre, modifier, remettre.
  Future<void> _actions(Tache tache) async {
    final t = Teintes.de(context);
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tache.texte, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(plageFr(tache), style: TextStyle(color: t.doux)),
              const SizedBox(height: 14),
              BoutonsReponse(
                question: reponsesTache,
                choix: tache.etat,
                onChoix: (c) => Navigator.pop(
                  context,
                  c == null ? 'efface' : (c == Tache.fait ? 'fait' : 'pas'),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Modifier'),
                onTap: () => Navigator.pop(context, 'modifier'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.undo_rounded),
                title: Text(
                  tache.imperatif
                      ? 'Supprimer le rendez-vous'
                      : 'Remettre dans la to-do',
                ),
                onTap: () => Navigator.pop(context, 'retirer'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (choix) {
      case 'fait':
        await _repondTache(tache, Tache.fait);
      case 'pas':
        await _repondTache(tache, Tache.pasFait);
      case 'efface':
        await _repondTache(tache, null);
      case 'modifier':
        _ouvreTache(tache);
      case 'retirer':
        await widget.base.supprimeTache(tache.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final faites = _questions.where((q) => _reponses.containsKey(q.id)).length;
    final aVenir = _decalage >= 0;
    final section = TextStyle(
      color: t.doux,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );
    // La journée : choses casées et créneaux fixes, dans l'ordre.
    final lignes = <(int, Widget)>[
      for (final tache in _taches)
        (
          tache.debut,
          _LigneJournee(
            key: ValueKey('journee-${tache.id}'),
            tache: tache,
            onCoche: () => _repondTache(
              tache,
              tache.etat == Tache.fait ? null : Tache.fait,
            ),
            onTap: () => _actions(tache),
          ),
        ),
      for (final c in _creneaux) (c.debut, _LigneCreneau(creneau: c)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateCourte(_jour),
                    style: TextStyle(
                      color: t.doux,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Réglages',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReglagesScreen(base: widget.base),
                    ),
                  ),
                  icon: Icon(Icons.settings_outlined, color: t.doux),
                ),
              ],
            ),
            GrandTitre(_titre),
            const SizedBox(height: 18),
            if (_questions.isNotEmpty) ...[
              Semantics(
                container: true,
                label:
                    '$faites sur ${_questions.length} répondue'
                    '${faites > 1 ? 's' : ''}',
                excludeSemantics: true,
                child: Text(
                  'Questions · $faites sur ${_questions.length}',
                  style: section,
                ),
              ),
              const SizedBox(height: 4),
              for (final q in _questions)
                _LigneQuestion(
                  key: ValueKey('question-${q.id}'),
                  question: q,
                  choix: _reponses[q.id],
                  serie: _series[q.id] ?? 0,
                  ouverte:
                      !_reponses.containsKey(q.id) || _rouvertes.contains(q.id),
                  onRouvre: () => setState(() => _rouvertes.add(q.id!)),
                  onChoix: (c) {
                    setState(() => _rouvertes.remove(q.id));
                    _choisit(q, c);
                  },
                ),
              const SizedBox(height: 22),
            ],
            Row(
              children: [
                Expanded(child: Text('Ma journée', style: section)),
                if (aVenir)
                  TextButton(
                    onPressed: _prepare,
                    child: Text(lignes.isEmpty ? 'Préparer' : 'Modifier'),
                  ),
              ],
            ),
            if (_charge && lignes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  aVenir
                      ? 'Rien de prévu. Prépare ta journée avec ta to-do.'
                      : 'Rien de prévu ce jour-là.',
                  style: TextStyle(color: t.doux),
                ),
              ),
            for (final (_, w) in lignes) w,
          ],
        ),
      ),
    );
  }
}

/// Une question en ligne : répondue, la réponse en pastille (la toucher
/// rouvre les boutons) ; sinon, ses boutons dessous.
class _LigneQuestion extends StatelessWidget {
  final Question question;
  final int? choix;
  final int serie;
  final bool ouverte;
  final VoidCallback onRouvre;
  final ValueChanged<int?> onChoix;

  const _LigneQuestion({
    super.key,
    required this.question,
    required this.choix,
    required this.serie,
    required this.ouverte,
    required this.onRouvre,
    required this.onChoix,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final q = question;
    final c = choix;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.puce)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  q.texte,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (serie >= 2) ...[
                PastilleSerie(serie),
                const SizedBox(width: 6),
              ],
              if (c != null && !ouverte)
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: onRouvre,
                    child: Pastille(
                      q.reponses[c],
                      fond: AppTheme.couleurReponse(context, c, q.nbReponses),
                      hauteur: 32,
                      taille: 14,
                    ),
                  ),
                )
              else
                Text(
                  heureFr(q.heure),
                  style: TextStyle(color: t.doux, fontSize: 13),
                ),
            ],
          ),
          if (ouverte) ...[
            const SizedBox(height: 8),
            BoutonsReponse(question: q, choix: c, onChoix: onChoix),
          ],
        ],
      ),
    );
  }
}

/// Une chose de la journée : heure, rond à cocher, texte, durée.
class _LigneJournee extends StatelessWidget {
  final Tache tache;
  final VoidCallback onCoche;
  final VoidCallback onTap;

  const _LigneJournee({
    super.key,
    required this.tache,
    required this.onCoche,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final fait = tache.etat == Tache.fait;
    final pasFait = tache.etat == Tache.pasFait;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.puce)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                heureFr(tache.debut),
                style: TextStyle(
                  color: t.doux,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Semantics(
              button: true,
              checked: fait,
              label: 'Fait',
              child: InkResponse(
                onTap: onCoche,
                radius: 22,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fait ? t.accent : Colors.transparent,
                      border: fait
                          ? null
                          : Border.all(
                              color: pasFait ? t.moinsBonne : t.doux,
                              width: 2,
                            ),
                    ),
                    child: fait
                        ? Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: t.surAccent,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                tache.texte,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: fait || pasFait ? t.doux : t.texte,
                  decoration: fait || pasFait
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: t.doux,
                ),
              ),
            ),
            Text(
              dureeFr(tache.duree),
              style: TextStyle(color: t.doux, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un créneau fixe dans la journée, en gris.
class _LigneCreneau extends StatelessWidget {
  final Creneau creneau;

  const _LigneCreneau({required this.creneau});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.puce)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              heureFr(creneau.debut),
              style: TextStyle(
                color: t.doux,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 34),
          Expanded(
            child: Text(
              creneau.texte,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.doux,
              ),
            ),
          ),
          Text(
            'jusqu\'à ${heureFr(creneau.fin % (24 * 60))}',
            style: TextStyle(color: t.doux, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
