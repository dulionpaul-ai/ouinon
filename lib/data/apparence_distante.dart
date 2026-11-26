import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/apparence.dart';
import 'base.dart';

/// Le fichier public de réglages (couleurs, textes, tailles…), modifié par
/// Claude à la demande de Paul : l'appli change sans nouvel APK (accord de
/// Paul du 26/11/2026). L'appli ne fait que le télécharger : rien de Paul
/// n'est envoyé. La dernière version lue est gardée dans la base, pour
/// démarrer sans réseau et pour le moteur des notifications.
abstract final class ApparenceDistante {
  /// Lu par l'API de GitHub (mise à jour en une minute au plus ; l'adresse
  /// « raw » garde une copie 5 minutes).
  static const adresse =
      'https://api.github.com/repos/dulionpaul-ai/ouinon-reglages/'
      'contents/reglages.json';

  /// L'apparence en cours ; l'appli se redessine quand elle change.
  static final courante = ValueNotifier<Apparence>(Apparence.defaut);

  static void _applique(Apparence a) {
    Apparence.actuelle = a;
    courante.value = a;
  }

  /// La dernière version gardée dans la base.
  static Future<void> charge(Base base) async {
    final texte = await base.reglage('apparence');
    if (texte == null) return;
    final a = Apparence.depuisJson(texte);
    if (a != null) _applique(a);
  }

  /// Télécharge le fichier (6 s au plus) ; s'il est lisible et nouveau, le
  /// garde et l'applique. Sans réseau : rien ne change.
  static Future<void> telecharge(
    Base base, {
    Future<String?> Function(Uri adresse)? lecteur,
  }) async {
    final String? texte;
    try {
      texte = await (lecteur ?? _lis)(Uri.parse(adresse));
    } catch (_) {
      return;
    }
    if (texte == null) return;
    final a = Apparence.depuisJson(texte);
    if (a == null) return;
    if (await base.reglage('apparence') != texte) {
      await base.changeReglage('apparence', texte);
    }
    _applique(a);
  }

  static Future<String?> _lis(Uri adresse) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final requete = await client.getUrl(adresse);
      // Pas de cache : une modification se voit à la prochaine ouverture.
      requete.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github.raw')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache');
      final reponse = await requete.close().timeout(const Duration(seconds: 6));
      if (reponse.statusCode != 200) return null;
      return await reponse
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 6));
    } finally {
      client.close(force: true);
    }
  }
}
