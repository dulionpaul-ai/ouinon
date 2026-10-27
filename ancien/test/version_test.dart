import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ouinon/utils/version.dart';

void main() {
  test('la version affichée suit pubspec.yaml', () {
    final ligne = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(ligne.substring('version:'.length).trim(), versionAppli);
    expect(versionLisible(), startsWith('Ouinon 1.0.0 · APK n° '));
  });
}
