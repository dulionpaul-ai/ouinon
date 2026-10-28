import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/a_faire.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../widgets/vivant.dart';
import 'edition_a_faire_screen.dart';
import 'reglages_screen.dart';

/// Onglet 1, la to-do (maquette validée par Paul le 28/10/2026) : les 4
/// cases d'Eisenhower, toujours toutes visibles, chacune avec son nombre
/// de choses et leur temps total. On tire une chose vers la droite (sans
/// appui long) jusqu'au bandeau vert d'eau « Aujourd'hui » : elle part
/// dans l'onglet Aujourd'hui, à placer. Le « + » ouvre le formulaire
/// (micro, doublons signalés).
class TodoScreen extends StatefulWidget {
  final Base base;

  /// Moment présent imposé (tests).
  final DateTime Function() maintenant;

  const TodoScreen({
    super.key,
    required this.base,
    this.maintenant = DateTime.now,
  });

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<AFaire> _liste = const [];
  List<Tache> _duJour = const [];

  /// Une chose est en train d'être tirée.
  bool _glisse = false;

  /// Chaque envoi vers Aujourd'hui lance une traînée.
  int _envois = 0;

  DateTime get _aujourdhui => jourDe(widget.maintenant());

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

  Future<void> _recharge() async {
    final liste = await widget.base.liste();
    final duJour = await widget.base.tachesDu(_aujourdhui);
    if (!mounted) return;
    setState(() {
      _liste = liste;
      _duJour = duJour;
    });
  }

  /// Ce qui est déjà pour aujourd'hui (à placer, ou prévu) quitte la
  /// to-do.
  bool _pourAujourdhui(AFaire a) =>
      a.choisiePour == _aujourdhui ||
      _duJour.any((t) => t.listeId == a.id && t.etat != Tache.pasFait);

  /// Ce qui attend dans l'onglet Aujourd'hui.
  int get _attend =>
      _duJour.where((t) => t.etat == null).length +
      _liste
          .where(
            (a) =>
                a.choisiePour == _aujourdhui &&
                !_duJour.any((t) => t.listeId == a.id),
          )
          .length;

  Future<void> _versAujourdhui(AFaire a) async {
    setState(() => _envois++);
    await widget.base.choisitPour(a.id!, _aujourdhui);
    if (!mounted) return;
    annonce(
      context,
      '« ${a.texte} » → Aujourd\'hui',
      annuler: () => widget.base.choisitPour(a.id!, a.choisiePour),
    );
  }

  void _nouvelle() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          EditionAFaireScreen(base: widget.base, maintenant: widget.maintenant),
    ),
  );

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

  @override
  Widget build(BuildContext context) {
    final liste = [
      for (final a in ordreDePlacement(_liste, _aujourdhui, avecJamais: true))
        if (!_pourAujourdhui(a)) a,
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EnTete(
                    date:
                        '${dateCourte(_aujourdhui)} · ${liste.length} '
                        'chose${liste.length > 1 ? 's' : ''}',
                    titre: 'To-do',
                    actions: [
                      BoutonRond(
                        key: const ValueKey('reglages'),
                        icone: Icons.tune_rounded,
                        aide: 'Réglages et stats',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReglagesScreen(base: widget.base),
                          ),
                        ),
                      ),
                      BoutonRond(
                        key: const ValueKey('ajouter'),
                        icone: Icons.add_rounded,
                        aide: 'Ajouter une chose',
                        fort: true,
                        onTap: _nouvelle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      // La place du bandeau « Aujourd'hui ».
                      padding: const EdgeInsets.only(right: 22),
                      child: _Matrice(
                        liste: liste,
                        aujourdhui: _aujourdhui,
                        onTap: _ouvre,
                        onGlisse: (g) => setState(() => _glisse = g),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _BandeAujourdhui(
                  actif: _glisse,
                  attend: _attend,
                  envois: _envois,
                  onRecoit: _versAujourdhui,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les 4 cases, en deux rangées de deux.
class _Matrice extends StatelessWidget {
  final List<AFaire> liste;
  final DateTime aujourdhui;
  final void Function(AFaire) onTap;
  final ValueChanged<bool> onGlisse;

  const _Matrice({
    required this.liste,
    required this.aujourdhui,
    required this.onTap,
    required this.onGlisse,
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
        onTap: onTap,
        onGlisse: onGlisse,
      ),
    );
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kase(Case.dabord),
              const SizedBox(width: 8),
              kase(Case.aPlanifier),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kase(Case.viteFait),
              const SizedBox(width: 8),
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
  final void Function(AFaire) onTap;
  final ValueChanged<bool> onGlisse;

  const _Case({
    required this.kase,
    required this.choses,
    required this.onTap,
    required this.onGlisse,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final dabord = kase == Case.dabord;
    final total = choses.fold(0, (s, a) => s + a.duree);
    return Container(
      key: ValueKey('case-${kase.name}'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      decoration: BoxDecoration(
        color: dabord ? t.accent.withValues(alpha: 0.06) : null,
        border: Border.all(
          color: dabord ? t.accent.withValues(alpha: 0.45) : t.trait,
        ),
        borderRadius: BorderRadius.circular(t.rayon),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Etiquette(
            kase.nom,
            couleur: dabord
                ? t.accent
                : kase == Case.peutEtreJamais
                ? t.doux
                : null,
            // Combien de choses, et le temps qu'elles prennent.
            detail: choses.isEmpty
                ? null
                : '${choses.length} · ${dureeFr(total)}',
          ),
          Expanded(
            child: choses.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      kase.detail,
                      style: TextStyle(color: t.doux, fontSize: 13),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final a in choses)
                        Apparition(
                          key: ValueKey('todo-${a.id}'),
                          child: _Chose(
                            aFaire: a,
                            jamais: kase == Case.peutEtreJamais,
                            onTap: () => onTap(a),
                            onGlisse: onGlisse,
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

/// Une chose : son nom, sa durée. Tirée vers la droite, elle part vers
/// le bandeau « Aujourd'hui » ; touchée, elle s'ouvre.
class _Chose extends StatelessWidget {
  final AFaire aFaire;
  final bool jamais;
  final VoidCallback onTap;
  final ValueChanged<bool> onGlisse;

  const _Chose({
    required this.aFaire,
    required this.jamais,
    required this.onTap,
    required this.onGlisse,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = aFaire;
    final ligne = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.puce)),
        ),
        // La durée sous le nom : les mots ne sont jamais coupés, même
        // sur un petit téléphone.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.texte,
              style: TextStyle(
                color: jamais ? t.doux : t.texte,
                fontSize: 13.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              dureeFr(a.duree),
              style: TextStyle(
                fontFamily: AppTheme.policeMono,
                fontSize: 10.5,
                color: t.doux,
              ),
            ),
          ],
        ),
      ),
    );
    // Sans appui long (Paul, 26/10/2026) : la chose suit le doigt dès
    // qu'il glisse de côté.
    return Draggable<AFaire>(
      data: a,
      affinity: Axis.horizontal,
      onDragStarted: () => onGlisse(true),
      onDragEnd: (_) => onGlisse(false),
      onDraggableCanceled: (_, _) => onGlisse(false),
      feedback: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.vertDeau.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(t.rayon),
            border: Border.all(color: AppTheme.vertDeau),
          ),
          child: Text(
            a.texte,
            style: TextStyle(
              color: t.texte,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: ligne),
      child: ligne,
    );
  }
}

/// Le bandeau « Aujourd'hui », au bord droit, vert d'eau comme l'onglet
/// où vont les choses : il s'élargit quand on tire une chose, s'allume
/// quand elle passe dessus ; une traînée part à chaque envoi.
class _BandeAujourdhui extends StatelessWidget {
  final bool actif;
  final int attend;
  final int envois;
  final void Function(AFaire) onRecoit;

  const _BandeAujourdhui({
    required this.actif,
    required this.attend,
    required this.envois,
    required this.onRecoit,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    const c = AppTheme.vertDeau;
    return DragTarget<AFaire>(
      onAcceptWithDetails: (d) => onRecoit(d.data),
      builder: (context, candidats, _) {
        final dessus = candidats.isNotEmpty;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: [
            AnimatedContainer(
              key: const ValueKey('cible-aujourdhui'),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: dessus ? 64 : (actif ? 52 : 28),
              height: 220,
              decoration: BoxDecoration(
                color: c.withValues(alpha: dessus ? 0.28 : 0.08),
                border: Border(
                  left: BorderSide(
                    color: c.withValues(alpha: actif ? 1 : 0.45),
                  ),
                  top: BorderSide(color: c.withValues(alpha: actif ? 1 : 0.45)),
                  bottom: BorderSide(
                    color: c.withValues(alpha: actif ? 1 : 0.45),
                  ),
                ),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Chevron(actif: actif),
                    const SizedBox(height: 10),
                    RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        'AUJOURD\'HUI',
                        style: TextStyle(
                          fontFamily: AppTheme.policeTitre,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          letterSpacing: 3,
                          color: t.texte,
                        ),
                      ),
                    ),
                    if (attend > 0) ...[
                      const SizedBox(height: 10),
                      TweenAnimationBuilder<double>(
                        key: ValueKey('attend-$attend'),
                        tween: Tween(begin: 1.8, end: 1),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.elasticOut,
                        builder: (context, v, enfant) =>
                            Transform.scale(scale: v, child: enfant),
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.withValues(alpha: 0.22),
                            border: Border.all(color: c),
                          ),
                          child: Text(
                            '$attend',
                            style: const TextStyle(
                              fontFamily: AppTheme.policeMono,
                              fontSize: 11,
                              color: c,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _Chevron(actif: actif),
                  ],
                ),
              ),
            ),
            // La traînée d'un envoi.
            if (envois > 0)
              Positioned(
                right: 6,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('envoi-$envois'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeIn,
                  builder: (context, v, _) => v >= 1
                      ? const SizedBox.shrink()
                      : IgnorePointer(
                          child: Transform.translate(
                            offset: Offset(-180 * (1 - v), 0),
                            child: Container(
                              width: 30 + 60 * v,
                              height: 2,
                              color: c.withValues(alpha: 1 - v),
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

/// Une flèche qui bat vers la droite pendant qu'on tire une chose.
class _Chevron extends StatelessWidget {
  final bool actif;

  const _Chevron({required this.actif});

  @override
  Widget build(BuildContext context) {
    const c = AppTheme.vertDeau;
    final icone = const Icon(Icons.chevron_right_rounded, size: 18, color: c);
    if (!actif) return icone;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -4, end: 4),
      duration: const Duration(milliseconds: 500),
      builder: (context, v, enfant) =>
          Transform.translate(offset: Offset(v, 0), child: enfant),
      child: icone,
    );
  }
}
