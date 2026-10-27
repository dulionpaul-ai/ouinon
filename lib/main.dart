import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/notifications.dart';
import 'screens/questions_screen.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Notifications.instance.prepare();
  } catch (_) {
    // Sans notifications plutôt que sans appli.
  }
  runApp(const OuinonApp());
}

/// L'appli, repartie de zéro le 27/10/2026 (`docs/cahier.md`) : pour
/// l'instant, un seul écran, « Mes questions ».
class OuinonApp extends StatelessWidget {
  final Widget? accueil;

  const OuinonApp({super.key, this.accueil});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ouinon',
    debugShowCheckedModeBanner: false,
    theme: themeOuinon(),
    locale: const Locale('fr', 'FR'),
    supportedLocales: const [Locale('fr', 'FR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, enfant) =>
        MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: enfant!),
    home: accueil ?? const QuestionsScreen(),
  );
}
