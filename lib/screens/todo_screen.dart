import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/a_faire.dart';
import '../models/tache.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import '../utils/jour.dart';
import '../utils/planning.dart';
import '../utils/remplissage.dart';
import '../widgets/rond.dart';
import 'edition_a_faire_screen.dart';
import 'preparer_screen.dart';

/// La to-do (revue du 25/10/2026) : une seule liste, triée toute seule
/// (urgent et important d'abord), une barre « Ajouter… » toujours là
/// (« Papiers 1 h »), et « Préparer demain ». Une chose n'a pas d'heure
/// ici : elle en prend une quand on la case dans une journée.
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
  Map<int, Tache> _casees = const {};
  int _demainCasees = 0;
  final _saisie = TextEditingController();
  final _focus = FocusNode();

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
    _saisie.dispose();
    _focus.dispose();
    super.dispose();
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
      AFaire(texte: lu.texte, duree: lu.duree ?? 30, creeLe: _aujourdhui),
    );
    _saisie.clear();
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
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 180 + bas),
              children: [
                SizedBox(
                  height: 40,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      liste.isEmpty
                          ? 'Rien pour l\'instant'
                          : '${liste.length} chose${liste.length > 1 ? 's' : ''}'
                                ' · ${dureeFr(minutes)}',
                      style: TextStyle(
                        color: t.doux,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const GrandTitre('To-do'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _prepare,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.surAccent,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.nightlight_round),
                  label: Text(
                    _demainCasees == 0
                        ? 'Préparer demain'
                        : 'Demain : $_demainCasees chose'
                              '${_demainCasees > 1 ? 's' : ''} · modifier',
                  ),
                ),
                const SizedBox(height: 8),
                if (liste.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Note ici tout ce que tu as à faire, avec le temps que '
                      'ça prend : « Papiers 1 h », « Banque 30 min ».',
                      style: TextStyle(color: t.doux, height: 1.35),
                    ),
                  ),
                for (final a in liste)
                  _LigneTodo(
                    key: ValueKey('todo-${a.id}'),
                    aFaire: a,
                    aujourdhui: _aujourdhui,
                    casee: _casees[a.id],
                    onFaite: () => _faite(a),
                    onTap: () => _ouvre(a),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 92 + bas,
            child: Container(
              height: 54,
              padding: const EdgeInsets.fromLTRB(20, 0, 6, 0),
              decoration: ShapeDecoration(
                color: t.carte,
                shape: StadiumBorder(side: BorderSide(color: t.barre)),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Une chose de la to-do : rond à cocher (fait), texte, durée et
/// étiquettes ; « demain 14 h » si elle est déjà casée.
class _LigneTodo extends StatelessWidget {
  final AFaire aFaire;
  final DateTime aujourdhui;
  final Tache? casee;
  final VoidCallback onFaite;
  final VoidCallback onTap;

  const _LigneTodo({
    super.key,
    required this.aFaire,
    required this.aujourdhui,
    required this.casee,
    required this.onFaite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    final a = aFaire;
    final e = etiquettes(a, aujourdhui);
    final c = casee;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.puce)),
        ),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Fait',
              child: InkResponse(
                onTap: onFaite,
                radius: 22,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: t.doux, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.texte,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: dureeFr(a.duree)),
                          // « Urgent » et « en retard » en corail, le reste
                          // discret.
                          for (final m in (e ?? '').split(' · '))
                            if (m.isNotEmpty)
                              TextSpan(
                                text: ' · $m',
                                style: m == 'Urgent' || m == 'en retard'
                                    ? TextStyle(color: t.moinsBonne)
                                    : null,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
