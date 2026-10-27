import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/preferences.dart';
import '../models/a_faire.dart';
import '../models/creneau.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../widgets/etape.dart';
import 'edition_a_faire_screen.dart';
import 'placer_screen.dart';

/// Le soir, étape 1 sur 2 : « Qu'est-ce qui traîne ? » (maquette validée
/// par Paul le 26/10/2026). Le tableau de Paul : on écrit en vrac, chaque
/// chose devient un aimant rangé dans sa case d'Eisenhower. Un toucher
/// choisit l'aimant pour demain et ouvre ses réglages en bas (durée,
/// Important, Urgent, heure) ; un second toucher le retire. Pas d'appui
/// long, pas de défilement : une case trop pleine se replie en
/// « + 3 autres ».
class ChoisirScreen extends StatefulWidget {
  final Base base;

  /// Le jour préparé (demain).
  final DateTime jour;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const ChoisirScreen({
    super.key,
    required this.base,
    required this.jour,
    this.maintenant = DateTime.now,
  });

  @override
  State<ChoisirScreen> createState() => _ChoisirScreenState();
}

class _ChoisirScreenState extends State<ChoisirScreen> {
  List<AFaire> _liste = const [];
  List<Tache> _taches = const [];
  List<Creneau> _creneaux = const [];
  ({int debut, int fin}) _journee = (
    debut: Preferences.debutJourneeParDefaut,
    fin: Preferences.finJourneeParDefaut,
  );
  bool _charge = false;

  /// La chose dont les réglages sont ouverts en bas.
  int? _fiche;

  /// Une case dépliée sur toute la matrice (« + 3 autres »).
  Case? _depliee;

  final _saisie = TextEditingController();

  DateTime get _jour => jourDe(widget.jour);

  @override
  void initState() {
    super.initState();
    widget.base.changements.addListener(_recharge);
    _recharge();
  }

  @override
  void dispose() {
    widget.base.changements.removeListener(_recharge);
    _saisie.dispose();
    super.dispose();
  }

  Future<void> _recharge() async {
    final liste = await widget.base.liste();
    final taches = await widget.base.tachesDu(_jour);
    final creneaux = await widget.base.creneauxDu(_jour);
    final journee = await Preferences.journee();
    if (!mounted) return;
    setState(() {
      _liste = liste;
      _taches = taches;
      _creneaux = creneaux;
      _journee = journee;
      _charge = true;
      if (_fiche != null && !liste.any((a) => a.id == _fiche)) _fiche = null;
    });
  }

  /// Passages de ce jour tirés de la liste : id de la chose → passage.
  Map<int, Tache> get _casees => {
    for (final t in _taches)
      if (t.listeId != null && t.etat != Tache.pasFait) t.listeId!: t,
  };

  bool _choisie(AFaire a) =>
      a.choisiePour == _jour || _casees.containsKey(a.id);

  int get _choisi => _liste
      .where((a) => !a.faite && _choisie(a))
      .fold(0, (s, a) => s + a.duree);

  int get _libre => tempsLibre(
    jour: _jour,
    prevues: [
      for (final t in _taches)
        if (t.imperatif) t,
    ],
    debutJournee: _journee.debut,
    finJournee: _journee.fin,
    maintenant: widget.maintenant(),
    creneaux: _creneaux,
  );

  Future<void> _bascule(AFaire a) async {
    if (_choisie(a)) {
      setState(() => _fiche = null);
      final casee = _casees[a.id];
      if (casee != null) await widget.base.supprimeTache(casee.id!);
      await widget.base.choisitPour(a.id!, null);
    } else {
      setState(() => _fiche = a.id);
      await widget.base.choisitPour(a.id!, _jour);
    }
  }

  /// « Banque 45 min » : une nouvelle chose, choisie pour demain, ses
  /// réglages ouverts.
  Future<void> _ajoute() async {
    final lu = lisAjout(_saisie.text);
    if (lu.texte.isEmpty) return;
    _saisie.clear();
    final a = await widget.base.enregistreAFaire(
      AFaire(
        texte: lu.texte,
        duree: lu.duree ?? 30,
        creeLe: jourDe(widget.maintenant()),
        choisiePour: _jour,
      ),
    );
    if (mounted) setState(() => _fiche = a.id);
  }

  /// Un réglage changé ; le passage déjà casé suit (durée, heure).
  Future<void> _change(AFaire a) async {
    await widget.base.enregistreAFaire(a);
    final casee = _casees[a.id];
    if (casee != null && a.heure != null && casee.debut != a.heure) {
      await widget.base.enregistreTache(casee.copie(debut: a.heure));
    }
  }

  Future<void> _heure(AFaire a) async {
    if (a.heure != null) {
      await _change(a.copie(heure: () => null));
      return;
    }
    final choix = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
      helpText: 'À quelle heure ?',
    );
    if (choix == null) return;
    await _change(a.copie(heure: () => choix.hour * 60 + choix.minute));
  }

  void _modifie(AFaire a) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionAFaireScreen(
        base: widget.base,
        aFaire: a,
        maintenant: widget.maintenant,
      ),
    ),
  );

  void _placer() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PlacerScreen(
        base: widget.base,
        jour: _jour,
        maintenant: widget.maintenant,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final fiche = _liste.where((a) => a.id == _fiche).firstOrNull;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BarreEtape('Étape 1 sur 2'),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TitreEcran('Qu\'est-ce qui traîne ?', taille: 26),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: const ValueKey('vrac'),
                controller: _saisie,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _ajoute(),
                decoration: InputDecoration(
                  hintText: 'Écris en vrac… « Banque 45 min »',
                  isDense: true,
                  filled: true,
                  fillColor: t.carte,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.barre),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.barre),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Ajouter',
                    onPressed: _ajoute,
                    icon: Icon(Icons.add_rounded, color: t.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: !_charge ? const SizedBox() : _matrice(context),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: fiche == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: _Fiche(
                        key: ValueKey('fiche-${fiche.id}'),
                        aFaire: fiche,
                        onDuree: (d) => _change(fiche.copie(duree: d)),
                        onImportant: () =>
                            _change(fiche.copie(important: !fiche.important)),
                        onUrgent: () =>
                            _change(fiche.copie(urgent: !fiche.urgent)),
                        onHeure: () => _heure(fiche),
                        onModifier: () => _modifie(fiche),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _Jauge(choisi: _choisi, libre: _libre),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: BoutonSuite(
                key: const ValueKey('placer-demain'),
                texte: 'Placer sur demain',
                onPressed: _placer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matrice(BuildContext context) {
    final t = Teintes.de(context);
    final parCase = {for (final c in Case.values) c: <AFaire>[]};
    for (final a in _liste) {
      if (!a.faite) parCase[a.caseLe(_jour)]!.add(a);
    }
    // Les choisies d'abord dans chaque case.
    for (final l in parCase.values) {
      l.sort((x, y) {
        final c = (_choisie(x) ? 0 : 1).compareTo(_choisie(y) ? 0 : 1);
        return c != 0 ? c : (x.id ?? 0).compareTo(y.id ?? 0);
      });
    }
    Widget kase(Case c, {required bool pleine}) => _CaseAimants(
      key: ValueKey('case-${c.name}'),
      kase: c,
      choses: parCase[c]!,
      choisie: _choisie,
      depliee: pleine,
      onAimant: _bascule,
      onDeplie: () => setState(() => _depliee = pleine ? null : c),
    );
    if (_depliee case final c?) {
      return kase(c, pleine: true);
    }
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _Croix(t.barre))),
        Column(
          children: [
            for (final rang in [0, 1])
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final col in [0, 1])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            col == 0 ? 0 : 12,
                            rang == 0 ? 0 : 12,
                            col == 0 ? 12 : 0,
                            rang == 0 ? 10 : 0,
                          ),
                          child: kase(
                            Case.values[rang * 2 + col],
                            pleine: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// La croix qui partage la matrice, comme sur un tableau.
class _Croix extends CustomPainter {
  final Color couleur;

  const _Croix(this.couleur);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = couleur
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      p,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      p,
    );
  }

  @override
  bool shouldRepaint(_Croix ancien) => ancien.couleur != couleur;
}

/// Une case : son titre souligné (majuscules espacées, le nombre au
/// bout), puis ses aimants, un par ligne. Trop pleine : les derniers se
/// replient en « + 3 autres », qui déplie la case sur toute la matrice.
class _CaseAimants extends StatelessWidget {
  final Case kase;
  final List<AFaire> choses;
  final bool Function(AFaire) choisie;
  final bool depliee;
  final void Function(AFaire) onAimant;
  final VoidCallback onDeplie;

  const _CaseAimants({
    super.key,
    required this.kase,
    required this.choses,
    required this.choisie,
    required this.depliee,
    required this.onAimant,
    required this.onDeplie,
  });

  static const _hauteurAimant = 40.0;

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final couleur = switch (kase) {
      Case.dabord => t.accent,
      Case.peutEtreJamais => t.doux,
      _ => t.texte,
    };
    final titre = GestureDetector(
      onTap: depliee ? onDeplie : null,
      child: Container(
        padding: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: kase == Case.dabord ? t.accent : t.barre,
              width: 1.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                kase.nom.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: couleur,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ),
            Text(
              depliee ? 'Replier' : '${choses.length}',
              style: TextStyle(
                color: couleur,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
    Widget aimant(AFaire a) => _Aimant(
      // Une nouvelle clé quand la chose change de case : elle s'y colle
      // avec son animation d'arrivée.
      key: ValueKey('aimant-${a.id}-${kase.name}'),
      aFaire: a,
      choisie: choisie(a),
      gris: kase == Case.peutEtreJamais,
      onTap: () => onAimant(a),
    );
    if (depliee) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titre,
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final a in choses) aimant(a)],
              ),
            ),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, contraintes) {
        final place = math.max(
          0,
          ((contraintes.maxHeight - 30) / _hauteurAimant).floor(),
        );
        final trop = choses.length > place;
        final montrees = trop ? math.max(0, place - 1) : choses.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titre,
            const SizedBox(height: 7),
            if (choses.isEmpty)
              Text(kase.detail, style: TextStyle(color: t.doux, fontSize: 12)),
            for (final a in choses.take(montrees))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: aimant(a),
              ),
            if (trop)
              GestureDetector(
                key: ValueKey('autres-${kase.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: onDeplie,
                child: SizedBox(
                  height: 34,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+ ${choses.length - montrees} autre'
                      '${choses.length - montrees > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: t.doux,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Un aimant du tableau : son nom et sa durée. Posé de travers tant qu'il
/// n'est pas choisi ; choisi, il se redresse, se soulève et s'allume.
/// Arrivé dans une case, il s'y colle (petite chute).
class _Aimant extends StatelessWidget {
  final AFaire aFaire;
  final bool choisie;
  final bool gris;
  final VoidCallback onTap;

  const _Aimant({
    super.key,
    required this.aFaire,
    required this.choisie,
    required this.gris,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = aFaire;
    // Un léger biais propre à chaque aimant (entre -1,5° et 1,5°).
    final biais = (((a.id ?? 0) * 37) % 7 - 3) * 0.009;
    final texte = choisie ? t.surAccent : (gris ? t.doux : t.texte);
    final detail = [
      if (a.heure != null) 'à ${heureFr(a.heure!)}',
      dureeFr(a.duree),
    ].join(' · ').replaceAll(' ', ' ');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, v, enfant) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * -14),
          child: enfant,
        ),
      ),
      child: AnimatedRotation(
        turns: choisie ? 0 : biais / (2 * math.pi),
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          key: ValueKey('aimant-${a.id}'),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            transform: Matrix4.translationValues(0, choisie ? -1.5 : 0, 0),
            decoration: BoxDecoration(
              color: choisie ? t.accent : t.carte,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: choisie ? t.accent : t.barre),
              boxShadow: [
                choisie
                    ? BoxShadow(
                        color: t.accent.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      )
                    : const BoxShadow(
                        color: Color(0xFF060608),
                        offset: Offset(0, 2),
                      ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    a.texte,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: texte,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  detail,
                  maxLines: 1,
                  style: TextStyle(
                    color: choisie
                        ? t.surAccent.withValues(alpha: 0.7)
                        : t.doux,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Les réglages de la chose touchée, en bas : sa durée, Important,
/// Urgent, son heure (libre, ou imposée).
class _Fiche extends StatelessWidget {
  final AFaire aFaire;
  final ValueChanged<int> onDuree;
  final VoidCallback onImportant;
  final VoidCallback onUrgent;
  final VoidCallback onHeure;
  final VoidCallback onModifier;

  const _Fiche({
    super.key,
    required this.aFaire,
    required this.onDuree,
    required this.onImportant,
    required this.onUrgent,
    required this.onHeure,
    required this.onModifier,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = aFaire;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 12),
      decoration: BoxDecoration(
        color: t.carte,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.barre),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.texte,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('modifier-chose'),
                tooltip: 'Renommer ou supprimer',
                onPressed: onModifier,
                icon: Icon(Icons.edit_outlined, size: 20, color: t.doux),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                for (final (i, d) in const [15, 30, 60, 120].indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _Pilule(
                      key: ValueKey('duree-$d'),
                      texte: dureeFr(d),
                      choisie: a.duree == d,
                      couleur: t.accent,
                      onTap: () => onDuree(d),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Expanded(
                  child: _Pilule(
                    key: const ValueKey('important'),
                    texte: 'Important',
                    choisie: a.important,
                    couleur: t.accent,
                    onTap: onImportant,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Pilule(
                    key: const ValueKey('urgent'),
                    texte: 'Urgent',
                    choisie: a.urgent,
                    couleur: t.moinsBonne,
                    onTap: onUrgent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Pilule(
                    key: const ValueKey('heure'),
                    texte: a.heure == null
                        ? 'Heure libre'
                        : 'À ${heureFr(a.heure!)}',
                    choisie: a.heure != null,
                    couleur: AppTheme.bleuVert,
                    onTap: onHeure,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pilule extends StatelessWidget {
  final String texte;
  final bool choisie;
  final Color couleur;
  final VoidCallback onTap;

  const _Pilule({
    super.key,
    required this.texte,
    required this.choisie,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Semantics(
      button: true,
      selected: choisie,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: choisie ? couleur : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: choisie ? couleur : t.barre),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                texte,
                maxLines: 1,
                style: TextStyle(
                  color: choisie ? t.surAccent : t.texte,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Demain : 2 h 30 » et ce qui reste de libre ; la barre passe au rouge
/// quand ça ne rentre plus.
class _Jauge extends StatelessWidget {
  final int choisi;
  final int libre;

  const _Jauge({required this.choisi, required this.libre});

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final etat = remplissage(choisi, libre);
    final couleur = switch (etat) {
      Remplissage.rentre => t.accent,
      Remplissage.juste => t.moyenne,
      Remplissage.tropPlein => t.moinsBonne,
    };
    final message = switch (etat) {
      Remplissage.rentre => '${dureeFr(libre - choisi)} encore libres',
      Remplissage.juste => 'c\'est juste',
      Remplissage.tropPlein => 'ça ne rentre pas',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('Demain : ', style: TextStyle(fontSize: 15)),
            Text(
              dureeFr(choisi),
              key: const ValueKey('total-demain'),
              style: const TextStyle(
                fontFamily: AppTheme.policeTitre,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: etat == Remplissage.tropPlein ? t.moinsBonne : t.doux,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              end: libre == 0
                  ? (choisi > 0 ? 1 : 0)
                  : (choisi / libre).clamp(0, 1),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: couleur,
              backgroundColor: t.puce,
            ),
          ),
        ),
      ],
    );
  }
}
