import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/a_faire.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../data/preferences.dart';
import '../utils/deux_moi.dart';
import '../widgets/arrivee.dart';
import '../widgets/retro.dart';
import '../widgets/qui_est_la.dart';
import '../widgets/rond.dart';
import 'edition_a_faire_screen.dart';
import 'preparer_screen.dart';
import 'rapport_screen.dart';
import 'reglages_screen.dart';

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
    final duJour = await widget.base.tachesDu(_aujourdhui);
    final motSoir = await DeuxMoi.motDuJour(_aujourdhui);
    final journee = await Preferences.journee();
    if (!mounted) return;
    final now = widget.maintenant();
    setState(() {
      _liste = liste;
      _casees = casees;
      _demainCasees = demain.length;
      // Ce que l'Exécutant remonte : après sa journée, ou s'il a laissé
      // un mot.
      _remonte =
          duJour.isNotEmpty &&
              (motSoir != null || now.hour * 60 + now.minute >= journee.fin)
          ? (score: scoreJournee(duJour), mot: motSoir)
          : null;
    });
  }

  /// Le compte rendu de l'Exécutant, à lire par le Décideur (répartition
  /// du 26/10/2026) : le score du jour et son mot.
  ({String score, String? mot})? _remonte;

  void _rapport() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RapportScreen(base: widget.base, jour: _aujourdhui),
    ),
  );

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
    final bas = MediaQuery.paddingOf(context).bottom;
    final decideur = widget.moi == Moi.decideur;
    final bonjour = decideur && (_bonjour || liste.isEmpty);
    final contenu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Arrivee(
          child: QuiEstLa(
            moi: widget.moi,
            date: dateCourte(_aujourdhui),
            // Les Réglages, communs aux deux toi.
            fin: IconButton(
              tooltip: 'Réglages',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReglagesScreen(base: widget.base),
                ),
              ),
              icon: Icon(Icons.settings_outlined, color: t.doux),
            ),
          ),
        ),
        GrandTitre(bonjour ? 'Bonjour, Décideur.' : 'To-do'),
        Arrivee(
          rang: 1,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: bonjour
                ? Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Ici, tu ne fais rien : tu décides.\n',
                        ),
                        TextSpan(
                          text: 'Écris ce que tu veux, l\'exécutant le fera.',
                          style: TextStyle(color: t.doux),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  )
                : Text(
                    'Ce que l\'Exécutant devra faire, un jour ou l\'autre.',
                    style: TextStyle(color: t.doux, fontSize: 15),
                  ),
          ),
        ),
        if (_remonte case final r? when widget.moi == Moi.decideur)
          Arrivee(
            rang: 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Material(
                color: Teintes.jour.fond,
                borderRadius: BorderRadius.circular(t.rayon),
                child: InkWell(
                  key: const ValueKey('remonte'),
                  borderRadius: BorderRadius.circular(t.rayon),
                  onTap: _rapport,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                'L\'EXÉCUTANT : ${r.score.toUpperCase()} · '
                                'COMPTE RENDU ›',
                          ),
                          if (r.mot != null)
                            TextSpan(
                              text: '\n« ${r.mot} »',
                              style: styleMono(
                                13,
                                couleur: const Color(0xFFE9DCC0),
                              ),
                            ),
                        ],
                      ),
                      style: styleMono(13),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Arrivee(rang: 2, child: _barreAjout(t)),
        const SizedBox(height: 10),
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
              const SizedBox(width: 18),
              _Bascule(
                texte: 'Urgent',
                couleur: t.moinsBonne,
                actif: _urgent,
                onTap: () => setState(() => _urgent = !_urgent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
    decoration: BoxDecoration(
      color: t.carte,
      borderRadius: BorderRadius.circular(t.rayon),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.rayon - 4),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
  );
}

/// Important ou Urgent, à cocher avant d'ajouter : un rond vide ou
/// plein et le mot, sans cadre (style « tableau », 26/10/2026).
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
    final c = actif ? couleur : t.doux;
    return Semantics(
      button: true,
      toggled: actif,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: actif ? couleur : Colors.transparent,
                  border: Border.all(color: c, width: 1.6),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                texte,
                style: TextStyle(
                  color: c,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les 4 cases d'Eisenhower, dessinées comme sur le tableau blanc de
/// Paul : une croix qui coupe l'espace en quatre, sans cadres (style
/// « tableau » choisi le 26/10/2026). D'abord, À planifier, Vite fait,
/// Peut-être jamais.
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
    final t = Teintes.de(context);
    Widget kase(Case c, EdgeInsets marge) => Expanded(
      child: Padding(
        padding: marge,
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
      ),
    );
    Widget trait({required bool vertical}) => Container(
      width: vertical ? 2 : null,
      height: vertical ? null : 2,
      decoration: BoxDecoration(
        color: t.puce,
        borderRadius: BorderRadius.circular(1),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kase(Case.dabord, const EdgeInsets.fromLTRB(0, 0, 14, 12)),
              trait(vertical: true),
              kase(Case.aPlanifier, const EdgeInsets.fromLTRB(16, 0, 0, 12)),
            ],
          ),
        ),
        trait(vertical: false),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kase(Case.viteFait, const EdgeInsets.fromLTRB(0, 14, 14, 0)),
              trait(vertical: true),
              kase(
                Case.peutEtreJamais,
                const EdgeInsets.fromLTRB(16, 14, 0, 0),
              ),
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
    final titre = switch (kase) {
      Case.dabord => t.accent,
      Case.peutEtreJamais => t.doux,
      _ => t.texte,
    };
    return KeyedSubtree(
      key: ValueKey('case-${kase.name}'),
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
                    fontSize: 15,
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
                          kaseJamais: kase == Case.peutEtreJamais,
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

/// Une chose dans sa case : son nom puis sa durée, sur la même ligne (et
/// « demain 14 h » si elle est casée). Toucher l'ouvre ; appui long :
/// fait.
class _ChoseCase extends StatelessWidget {
  final AFaire aFaire;
  final DateTime aujourdhui;
  final Tache? casee;
  final VoidCallback onTap;
  final VoidCallback onFaite;

  /// Dans « Peut-être jamais » : en gris.
  final bool kaseJamais;

  const _ChoseCase({
    super.key,
    this.kaseJamais = false,
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
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: a.texte,
                style: TextStyle(
                  color: kaseJamais ? t.doux : t.texte,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // La durée ne se coupe pas (« 1 h 30 »).
              TextSpan(text: '  ${dureeFr(a.duree).replaceAll(' ', '\u00a0')}'),
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
          style: TextStyle(
            color: t.doux,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
