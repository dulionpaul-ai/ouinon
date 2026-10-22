import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';

/// Réglages : autorisation des notifications, essai d'une notification,
/// et ce que l'appli fait (ou pas) de tes réponses.
class ReglagesScreen extends StatefulWidget {
  final Base base;

  const ReglagesScreen({super.key, required this.base});

  @override
  State<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends State<ReglagesScreen> {
  bool? _autorisees;

  @override
  void initState() {
    super.initState();
    _verifie();
  }

  Future<void> _verifie() async {
    bool? ok;
    try {
      ok = await Notifications.instance.autorisees();
    } catch (_) {}
    if (mounted) setState(() => _autorisees = ok);
  }

  Future<void> _autorise() async {
    try {
      await Notifications.instance.demandeAutorisation();
      await Notifications.instance.replanifie(widget.base);
    } catch (_) {}
    await _verifie();
  }

  Future<void> _essaie() async {
    final questions = [
      for (final q in await widget.base.questions())
        if (q.active) q,
    ];
    if (!mounted) return;
    final messager = ScaffoldMessenger.of(context);
    if (questions.isEmpty) {
      messager.showSnackBar(
        const SnackBar(content: Text('Aucune question active.')),
      );
      return;
    }
    try {
      await Notifications.instance.essaie(questions.first);
      messager.showSnackBar(
        const SnackBar(
          content: Text(
            'Notification envoyée : réponds avec ses boutons, la réponse '
            'compte pour aujourd\'hui.',
          ),
        ),
      );
    } catch (_) {
      messager.showSnackBar(
        const SnackBar(content: Text('Notification impossible.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doux = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text('Notifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(switch (_autorisees) {
            true => 'Autorisées.',
            false => 'Bloquées : sans elles, tu ne reçois pas tes questions.',
            null =>
              'Chaque question arrive à son heure, à quelques minutes '
                  'près.',
          }, style: doux),
          const SizedBox(height: 12),
          if (_autorisees != true)
            FilledButton(
              onPressed: _autorise,
              child: const Text('Autoriser les notifications'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _essaie,
            child: const Text('Essayer une notification maintenant'),
          ),
          const SizedBox(height: 28),
          Text('Tes réponses', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tout reste sur ce téléphone : pas de compte, pas de serveur, '
            'aucun envoi. Si tu désinstalles l\'appli, tes réponses sont '
            'effacées.',
            style: doux,
          ),
          const SizedBox(height: 28),
          Text('À savoir', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Oui-Non montre ce qui va souvent ensemble dans tes réponses. '
            'Ce ne sont pas des causes, et l\'appli ne donne aucun conseil '
            'de santé.',
            style: doux,
          ),
          const SizedBox(height: 28),
          Text('Version 1.0.0', style: doux),
        ],
      ),
    );
  }
}
