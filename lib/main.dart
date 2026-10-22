import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/notifications.dart';
import 'screens/accueil_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Notifications.instance.prepare();
  } catch (_) {
    // Sans notifications plutôt que sans appli.
  }
  runApp(const OuinonApp());
}

class OuinonApp extends StatelessWidget {
  final Widget? accueil;

  const OuinonApp({super.key, this.accueil});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ouinon',
      debugShowCheckedModeBanner: false,
      // Toujours sombre (choix de Paul du 22/10/2026).
      theme: AppTheme.sombre(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Taille du texte du téléphone respectée, jusqu'à 1,3 fois : au-delà,
      // les boutons de réponse couperaient les mots.
      builder: (context, enfant) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: enfant!,
      ),
      home: accueil ?? const AccueilScreen(),
    );
  }
}
