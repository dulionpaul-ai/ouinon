import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Choix de l'heure d'une notification : deux roulettes (heures, minutes
/// de 5 en 5) dans un panneau qui monte du bas et cache le reste de
/// l'écran, avec son propre bouton « Valider ». Rend les minutes depuis
/// minuit, ou nul si on ferme sans valider.
Future<int?> choisirHeure(BuildContext context, int depart) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _PanneauHeure(depart: depart),
  );
}

class _PanneauHeure extends StatefulWidget {
  final int depart;

  const _PanneauHeure({required this.depart});

  @override
  State<_PanneauHeure> createState() => _PanneauHeureState();
}

class _PanneauHeureState extends State<_PanneauHeure> {
  late int _heure = widget.depart ~/ 60;
  late int _minute = (widget.depart % 60) ~/ 5 * 5;

  @override
  Widget build(BuildContext context) {
    final t = Teintes.de(context);
    Widget roulette({
      required Key cle,
      required int nombre,
      required int depart,
      required String Function(int) libelle,
      required ValueChanged<int> onChange,
    }) => SizedBox(
      width: 96,
      height: 200,
      child: CupertinoPicker(
        key: cle,
        scrollController: FixedExtentScrollController(initialItem: depart),
        itemExtent: 48,
        looping: true,
        // Contour seul : un fond par-dessus grisait le chiffre choisi.
        selectionOverlay: Container(
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: t.accent, width: 2)),
          ),
        ),
        onSelectedItemChanged: onChange,
        children: [
          for (var i = 0; i < nombre; i++)
            Center(
              child: Text(
                libelle(i),
                style: TextStyle(
                  fontFamily: AppTheme.policeTitre,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: t.texte,
                ),
              ),
            ),
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Heure de la notification',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                roulette(
                  cle: const ValueKey('roulette-heures'),
                  nombre: 24,
                  depart: _heure,
                  libelle: (i) => '$i',
                  onChange: (i) => _heure = i,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'h',
                    style: TextStyle(
                      fontFamily: AppTheme.policeTitre,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: t.doux,
                    ),
                  ),
                ),
                roulette(
                  cle: const ValueKey('roulette-minutes'),
                  nombre: 12,
                  depart: _minute ~/ 5,
                  libelle: (i) => (i * 5).toString().padLeft(2, '0'),
                  onChange: (i) => _minute = i * 5,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.surAccent,
              ),
              onPressed: () => Navigator.pop(context, _heure * 60 + _minute),
              child: const Text('Valider l\'heure'),
            ),
          ],
        ),
      ),
    );
  }
}
