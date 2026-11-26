import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/question.dart';
import '../utils/jour.dart';
import 'base.dart';

/// La copie en ligne des questions et des réponses, dans le projet
/// Supabase « Ouinon » de Paul (26/11/2026) : sauvegarde, et le coach peut
/// les lire. Le téléphone reste la référence ; la copie suit.
class Supabase implements Miroir {
  static const _adresse = 'https://mcusodanxgriodltqkhc.supabase.co/rest/v1';

  /// Clé publique du projet, donnée à la fabrication de l'APK
  /// (`tool/cle_supabase.sh`), jamais écrite dans le code. Vide : pas de
  /// copie en ligne.
  static const _cle = String.fromEnvironment('SUPABASE_CLE');

  static bool get disponible => _cle.isNotEmpty;

  static const _delai = Duration(seconds: 8);

  final http.Client _client;

  Supabase([http.Client? client]) : _client = client ?? http.Client();

  Map<String, String> _entetes([String? prefere]) => {
    'apikey': _cle,
    'Content-Type': 'application/json',
    'Prefer': ?prefere,
  };

  Uri _uri(String table, [String requete = '']) =>
      Uri.parse('$_adresse/$table$requete');

  void _verifie(http.Response r) {
    if (r.statusCode >= 300) {
      throw http.ClientException('Supabase ${r.statusCode} : ${r.body}');
    }
  }

  Future<void> _ajoute(String table, List<Map<String, Object?>> lignes) async {
    if (lignes.isEmpty) return;
    _verifie(
      await _client
          .post(
            _uri(table),
            headers: _entetes('resolution=merge-duplicates,return=minimal'),
            body: jsonEncode(lignes),
          )
          .timeout(_delai),
    );
  }

  Future<void> _efface(String table, String filtre) async => _verifie(
    await _client
        .delete(_uri(table, '?$filtre'), headers: _entetes())
        .timeout(_delai),
  );

  Future<List<dynamic>> _lis(String table) async {
    final r = await _client
        .get(_uri(table, '?select=*'), headers: _entetes())
        .timeout(_delai);
    _verifie(r);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Map<String, Object?> _ligneQuestion(Question q) => {
    ...q.versLigne(),
    'modifie_le': DateTime.now().toUtc().toIso8601String(),
  };

  static Map<String, Object?> _ligneReponse(int id, String jour, int choix) => {
    'question_id': id,
    'jour': jour,
    'choix': choix,
    'repondu_le': DateTime.now().toUtc().toIso8601String(),
  };

  @override
  Future<void> envoieQuestion(Question q) =>
      _ajoute('questions', [_ligneQuestion(q)]);

  @override
  Future<void> supprimeQuestion(int id) => _efface('questions', 'id=eq.$id');

  @override
  Future<void> envoieReponse(int questionId, DateTime jour, int choix) =>
      _ajoute('reponses', [_ligneReponse(questionId, cleJour(jour), choix)]);

  @override
  Future<void> effaceReponse(int questionId, DateTime jour) => _efface(
    'reponses',
    'question_id=eq.$questionId&jour=eq.${cleJour(jour)}',
  );

  @override
  Future<void> remplaceReponsesDe(int questionId, Reponses reponses) async {
    await _efface('reponses', 'question_id=eq.$questionId');
    await _ajoute('reponses', [
      for (final e in reponses.entries)
        _ligneReponse(questionId, e.key, e.value),
    ]);
  }

  @override
  Future<void> envoieReglage(String cle, String valeur) => _ajoute('reglages', [
    {'cle': cle, 'valeur': valeur},
  ]);

  @override
  Future<void> envoieTout(Copie copie) async {
    await _ajoute('questions', [
      for (final q in copie.questions) _ligneQuestion(q),
    ]);
    await _ajoute('reponses', [
      for (final MapEntry(key: id, value: r) in copie.reponses.entries)
        for (final e in r.entries) _ligneReponse(id, e.key, e.value),
    ]);
    await _ajoute('reglages', [
      for (final MapEntry(key: cle, value: valeur) in copie.reglages.entries)
        {'cle': cle, 'valeur': valeur},
    ]);
  }

  @override
  Future<Copie> telecharge() async {
    final questions = [
      for (final l in await _lis('questions'))
        Question.depuisLigne((l as Map<String, dynamic>).cast()),
    ];
    final reponses = <int, Reponses>{};
    for (final l in await _lis('reponses')) {
      (reponses[l['question_id'] as int] ??= {})[l['jour'] as String] =
          l['choix'] as int;
    }
    return (
      questions: questions,
      reponses: reponses,
      reglages: {
        for (final l in await _lis('reglages'))
          l['cle'] as String: l['valeur'] as String,
      },
    );
  }
}
