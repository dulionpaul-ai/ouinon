import 'package:flutter/material.dart';

import '../data/base.dart';
import '../data/notifications.dart';
import '../data/preferences.dart';
import '../widgets/anneau_roles.dart';

/// « Répartir les rôles », depuis les Réglages : l'anneau des 24 heures,
/// comme dans l'intro. Chaque changement est gardé tout de suite, et les
/// notifications du matin et de fin de journée suivent.
class RolesScreen extends StatefulWidget {
  final Base base;

  const RolesScreen({super.key, required this.base});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  ({int debut, int fin})? _journee;

  @override
  void initState() {
    super.initState();
    Preferences.journee().then((j) {
      if (mounted) setState(() => _journee = j);
    });
  }

  Future<void> _change(({int debut, int fin}) j) async {
    setState(() => _journee = j);
    await Preferences.changeJournee(debut: j.debut, fin: j.fin);
    try {
      await Notifications.instance.replanifie(widget.base);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final j = _journee;
    return Scaffold(
      appBar: AppBar(title: const Text('Répartir les rôles')),
      body: j == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [RepartitionRoles(journee: j, onChange: _change)],
            ),
    );
  }
}
