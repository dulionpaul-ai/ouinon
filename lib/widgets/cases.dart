import 'package:flutter/material.dart';

import '../models/a_faire.dart';
import '../theme/app_theme.dart';

/// Couleur d'une case d'Eisenhower : corail pour « D'abord », citron pour
/// « À planifier » (la case qui compte), abricot pour « Vite fait »,
/// neutre pour « Peut-être jamais ».
Color couleurCase(BuildContext context, Case c) {
  final t = Teintes.de(context);
  return switch (c) {
    Case.dabord => t.moinsBonne,
    Case.aPlanifier => t.meilleure,
    Case.viteFait => t.moyenne,
    Case.peutEtreJamais => t.puce,
  };
}

/// Texte sur la couleur d'une case.
Color texteSurCase(BuildContext context, Case c) =>
    c == Case.peutEtreJamais ? Teintes.de(context).texte : Teintes.orbite.fond;
