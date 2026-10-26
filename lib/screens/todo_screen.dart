import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/a_faire.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../utils/deux_moi.dart';
import '../widgets/arrivee.dart';
import '../widgets/qui_est_la.dart';
import '../widgets/rond.dart';
import 'edition_a_faire_screen.dart';
import 'preparer_screen.dart';

/// La to-do (revue du 25/10/2026, refaite avec Paul le 26/10/2026) : en
/// haut, « Ajouter… » (« Papiers 1 h ») avec Important et Urgent ; en
/// dessous, « Ma to-do » dans les 4 cases d'Eisenhower, toujours toutes
/// visibles (chaque case défile seule si elle est pleine) ; en bas,
/// « Préparer demain ». Le soir, c'est l'écran du Décideur : à
/// l'arrivée de l'ascenseur, « Bonjour, Décideur. » d'abord, le reste
/// ensuite. Une chose n'a pas d'heure ici : elle en prend une quand on la
/// case dans une journée.
class TodoScreen extends StatefulWidget {
  final Base base;

  /// Qui est là (choisi par l'accueil).
  final Moi moi;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const TodoScreen({
    super.key,
    required this.base,
    this.moi = Moi.repos,
    this.maintenant = DateTime.now,
  });

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<AFaire> _liste = const [];
  Map<int, Tache> _casees = const {};
  int _demainCasees = 0;
  final _saisie = TextEditingController();
  final _focus = FocusNode();
  bool _important = false;
  bool _urgent = false;

  /// Arrivé par l'ascenseur chez le Décideur : « Bonjour, Décideur. »
  /// jusqu'à la première chose ajoutée.
  bool _bonjour = false;

  DateTime get _aujourdhui => jourDe(widget.maintenant());

  @override
  void initState() {
    super.initState();
    widget.base.changements.addListener(_recharge);
    arriveeAscenseur.addListener(_arrive);
    _recharge();
  }

  @override
  void dispose() {
    widget.base.changements.removeListener(_recharge);
    arriveeAscenseur.removeListener(_arrive);
    _saisie.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _arrive() {
    if (arriveeAscenseur.value.versLeSoir) setState(() => _bonjour = true);
  }

  Future<void> _recharge() async {
    final liste = await widget.base.liste();
    final casees = await widget.base.placees(_aujourdhui);
    final demain = await widget.base.tachesDu(ajouteJours(_aujourdhui, 1));
    if (!mounted) return;
    setState(() {
      _liste = liste;
      _casees = casees;
      _demainCasees = demain.length;
    });
  }

  Future<void> _ajoute() async {
    final lu = lisAjout(_saisie.text);
    if (lu.texte.isEmpty) return;
    await widget.base.enregistreAFaire(
      AFaire(
        texte: lu.texte,
        duree: lu.duree ?? 30,
        important: _important,
        urgent: _urgent,
        creeLe: _aujourdhui,
      ),
    );
    _saisie.clear();
    setState(() {
      _important = false;
      _urgent = false;
      _bonjour = false;
    });
    _focus.requestFocus();
  }

  Future<void> _faite(AFaire a) async {
    await widget.base.marqueFaite(a.id!, _aujourdhui);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('« ${a.texte} » : fait.'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () => widget.base.marqueFaite(a.id!, null),
        ),
      ),
    );
  }

  void _ouvre(AFaire a) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionAFaireScreen(
        base: widget.base,
        aFaire: a,
        maintenant: widget.maintenant,
      ),
    ),
  );

  void _prepare() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Theme(
        data: AppTheme.soir(),
        child: PreparerScreen(
          base: widget.base,
          jour: ajouteJours(_aujourdhui, 1),
          maintenant: widget.maintenant,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final liste = ordreDePlacement(_liste, _aujourdhui, avecJamais: true);
    final minutes = liste.fold(0, (s, a) => s + a.duree);
    final bas = MediaQuery.paddingOf(context).bottom;
    final decideur = widget.moi == Moi.decideur;
    final bonjour = decideur && (_bonjour || liste.isEmpty);
    final contenu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Arrivee(
          child: QuiEstLa(moi: widget.moi, date: dateCourte(_aujourdhui)),
        ),
        GrandTitre(bonjour ? 'Bonjour, Décideur.' : 'To-do'),
        if (liste.isEmpty)
          Arrivee(
            rang: 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: decideur
                          ? 'Ici, tu ne fais rien : tu décides.\n'
                          : 'Note ici tout ce que tu as à faire.\n',
                    ),
                    TextSpan(
                      text: decideur
                          ? 'Écris ce que tu veux, l\'exécutant le fera.'
                          : 'Avec le temps que ça prend : « Papiers 1 h ».',
                      style: TextStyle(color: t.doux),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Arrivee(rang: 2, child: _barreAjout(t)),
        const SizedBox(height: 8),
        Arrivee(
          rang: 3,
          child: Row(
            children: [
              _Bascule(
                texte: 'Important',
                couleur: t.accent,
                actif: _important,
                onTap: () => setState(() => _important = !_important),
              ),
              const SizedBox(width: 6),
              _Bascule(
                texte: 'Urgent',
                couleur: t.moinsBonne,
                actif: _urgent,
                onTap: () => setState(() => _urgent = !_urgent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Arrivee(
          rang: 4,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Ma to-do',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                liste.isEmpty
                    ? 'vide'
                    : '${liste.length} chose${liste.length > 1 ? 's' : ''}'
                          ' · ${dureeFr(minutes)}',
                style: TextStyle(
                  color: t.doux,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Arrivee(
            rang: 5,
            child: _Matrice(
              liste: liste,
              aujourdhui: _aujourdhui,
              casees: _casees,
              onTap: _ouvre,
              onFaite: _faite,
            ),
          ),
        ),
        if (liste.isNotEmpty || _demainCasees > 0) ...[
          const SizedBox(height: 10),
          Arrivee(
            rang: 6,
            child: FilledButton(
              onPressed: _prepare,
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.surAccent,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                _demainCasees == 0
                    ? 'Préparer demain'
                    : 'Demain : $_demainCasees chose'
                          '${_demainCasees > 1 ? 's' : ''} · modifier',
              ),
            ),
          ),
        ],
      ],
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // Les 4 cases tiennent dans l'écran ; sur un trop petit écran (ou
        // clavier ouvert), la page défile plutôt que d'écraser les cases.
        child: LayoutBuilder(
          builder: (context, contraintes) {
            const minimum = 600.0;
            final assez = contraintes.maxHeight >= minimum;
            return SingleChildScrollView(
              physics: assez ? const NeverScrollableScrollPhysics() : null,
              child: SizedBox(
                height: assez ? contraintes.maxHeight : minimum,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 96 + bas),
                  child: contenu,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _barreAjout(Teintes t) => Container(
    height: 52,
    padding: const EdgeInsets.fromLTRB(18, 0, 5, 0),
    decoration: ShapeDecoration(
      color: t.carte,
      shape: StadiumBorder(
        side: BorderSide(color: t.accent.withValues(alpha: 0.55)),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('ajout'),
            controller: _saisie,
            focusNode: _focus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _ajoute(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Ajouter… (ex. Papiers 1 h)',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Ajouter',
          onPressed: _ajoute,
          style: IconButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.surAccent,
            fixedSize: const Size(42, 42),
          ),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
  );
}

/// Important ou Urgent, à cocher avant d'ajouter.
class _Bascule extends StatelessWidget {
  final String texte;
  final Color couleur;
  final bool actif;
  final VoidCallback onTap;

  const _Bascule({
    required this.texte,
    required this.couleur,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      button: true,
      toggled: actif,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: actif ? couleur.withValues(alpha: 0.14) : null,
            shape: StadiumBorder(
              side: BorderSide(color: actif ? couleur : t.puce),
            ),
          ),
          child: Text(
            texte,
            style: TextStyle(
              color: actif ? couleur : t.doux,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Les 4 cases d'Eisenhower, deux par deux : D'abord, À planifier, Vite
/// fait, Peut-être jamais. Teintes transparentes de l'accent, plus fortes
/// pour « D'abord ».
class _Matrice extends StatelessWidget {
  final List<AFaire> liste;
  final DateTime aujourdhui;
  final Map<int, Tache> casees;
  final void Function(AFaire) onTap;
  final void Function(AFaire) onFaite;

  const _Matrice({
    required this.liste,
    required this.aujourdhui,
    required this.casees,
    required this.onTap,
    required this.onFaite,
  });

  @override
  Widget build(BuildContext context) {
    Widget kase(Case c) => Expanded(
      child: _Case(
        kase: c,
        choses: [
          for (final a in liste)
            if (a.caseLe(aujourdhui) == c) a,
        ],
        aujourdhui: aujourdhui,
        casees: casees,
        onTap: onTap,
        onFaite: onFaite,
      ),
    );
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kase(Case.dabord),
              const SizedBox(width: 6),
              kase(Case.aPlanifier),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kase(Case.viteFait),
              const SizedBox(width: 6),
              kase(Case.peutEtreJamais),
            ],
          ),
        ),
      ],
    );
  }
}

class _Case extends StatelessWidget {
  final Case kase;
  final List<AFaire> choses;
  final DateTime aujourdhui;
  final Map<int, Tache> casees;
  final void Function(AFaire) onTap;
  final void Function(AFaire) onFaite;

  const _Case({
    required this.kase,
    required this.choses,
    required this.aujourdhui,
    required this.casees,
    required this.onTap,
    required this.onFaite,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final (fond, bord, titre) = switch (kase) {
      Case.dabord => (
        t.accent.withValues(alpha: 0.16),
        t.accent.withValues(alpha: 0.35),
        t.accent,
      ),
      Case.aPlanifier => (
        t.accent.withValues(alpha: 0.07),
        Colors.transparent,
        t.texte,
      ),
      Case.viteFait => (
        t.texte.withValues(alpha: 0.05),
        Colors.transparent,
        t.texte,
      ),
      Case.peutEtreJamais => (
        t.texte.withValues(alpha: 0.025),
        Colors.transparent,
        t.doux,
      ),
    };
    return Container(
      key: ValueKey('case-${kase.name}'),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bord),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kase.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titre,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (choses.isNotEmpty)
                Text(
                  '${choses.length}',
                  style: TextStyle(
                    color: t.doux,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: choses.isEmpty
                ? Text(
                    kase.detail,
                    style: TextStyle(color: t.doux, fontSize: 12),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final a in choses)
                        _ChoseCase(
                          key: ValueKey('todo-${a.id}'),
                          aFaire: a,
                          aujourdhui: aujourdhui,
                          casee: casees[a.id],
                          onTap: () => onTap(a),
                          onFaite: () => onFaite(a),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Une chose dans sa case : son nom, sa durée (et « demain 14 h » si elle
/// est casée). Toucher l'ouvre ; appui long : fait.
class _ChoseCase extends StatelessWidget {
  final AFaire aFaire;
  final DateTime aujourdhui;
  final Tache? casee;
  final VoidCallback onTap;
  final VoidCallback onFaite;

  const _ChoseCase({
    super.key,
    required this.aFaire,
    required this.aujourdhui,
    required this.casee,
    required this.onTap,
    required this.onFaite,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = aFaire;
    final c = casee;
    final enRetard = a.echeance != null && a.echeance!.isBefore(aujourdhui);
    return InkWell(
      onTap: onTap,
      onLongPress: onFaite,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: t.texte.withValues(alpha: 0.06)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.texte,
              style: const TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: dureeFr(a.duree)),
                  if (enRetard)
                    TextSpan(
                      text: ' · en retard',
                      style: TextStyle(color: t.moinsBonne),
                    ),
                  if (c != null)
                    TextSpan(
                      text:
                          ' · ${c.jour == aujourdhui ? 'aujourd\'hui' : 'demain'}'
                          ' ${heureFr(c.debut)}',
                      style: TextStyle(color: t.accent),
                    ),
                ],
              ),
              style: TextStyle(color: t.doux, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
