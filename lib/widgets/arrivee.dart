import 'dart:async';

import 'package:flutter/material.dart';

/// Chaque arrivée par l'ascenseur : son numéro et sa direction (vers le
/// Décideur ou vers l'Exécutant).
final arriveeAscenseur = ValueNotifier<({int numero, bool versLeSoir})>((
  numero: 0,
  versLeSoir: true,
));

/// Un morceau d'écran qui, à l'arrivée de l'ascenseur, se cache portes
/// fermées puis apparaît après le « Bonjour » (idée de Paul du
/// 26/10/2026 : « la porte s'ouvre, Bonjour Décideur, et après le reste
/// s'affiche »). [rang] décale les morceaux les uns après les autres.
class Arrivee extends StatefulWidget {
  final int rang;
  final Widget child;

  const Arrivee({super.key, this.rang = 0, required this.child});

  /// Attente avant le premier morceau : le temps que les portes s'ouvrent
  /// et qu'on lise le « Bonjour ».
  static const attente = Duration(milliseconds: 1300);

  @override
  State<Arrivee> createState() => _ArriveeState();
}

class _ArriveeState extends State<Arrivee> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );
  Timer? _retard;

  @override
  void initState() {
    super.initState();
    arriveeAscenseur.addListener(_arrive);
  }

  void _arrive() {
    _retard?.cancel();
    _anim.value = 0;
    _retard = Timer(
      Arrivee.attente + Duration(milliseconds: 110 * widget.rang),
      () {
        if (mounted) _anim.forward();
      },
    );
  }

  @override
  void dispose() {
    arriveeAscenseur.removeListener(_arrive);
    _retard?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (context, enfant) {
      final v = Curves.easeOut.transform(_anim.value);
      return Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - v)),
          child: enfant,
        ),
      );
    },
    child: widget.child,
  );
}
