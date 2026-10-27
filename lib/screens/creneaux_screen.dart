import 'package:flutter/material.dart';

import '../data/base.dart';
import '../models/creneau.dart';
import '../theme/app_theme.dart';
import '../utils/date_fr.dart';
import 'edition_creneau_screen.dart';

/// Les créneaux fixes (« Enfants 17 h – 23 h »), depuis les Réglages.
class CreneauxScreen extends StatefulWidget {
  final Base base;

  const CreneauxScreen({super.key, required this.base});

  @override
  State<CreneauxScreen> createState() => _CreneauxScreenState();
}

class _CreneauxScreenState extends State<CreneauxScreen> {
  List<Creneau> _creneaux = const [];

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
    final creneaux = await widget.base.creneaux();
    if (mounted) setState(() => _creneaux = creneaux);
  }

  void _ouvre([Creneau? c]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditionCreneauScreen(base: widget.base, creneau: c),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Créneaux fixes')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un créneau',
        backgroundColor: t.accent,
        foregroundColor: t.surAccent,
        onPressed: _ouvre,
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            'Des moments pris chaque semaine : ils apparaissent grisés dans '
            'ta journée, et rien ne s\'y case.',
            style: TextStyle(color: t.doux, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final c in _creneaux)
            InkWell(
              onTap: () => _ouvre(c),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.puce)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.texte,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            joursFr(c.jours),
                            style: TextStyle(color: t.doux, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${heureFr(c.debut)} – ${heureFr(c.fin % (24 * 60))}',
                      style: TextStyle(
                        color: t.doux,
                        fontWeight: FontWeight.w700,
                      ),
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
