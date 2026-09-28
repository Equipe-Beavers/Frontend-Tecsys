import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/estudo.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';

class EstudosService {
  EstudosService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          (const String.fromEnvironment('API_BASE_URL').isNotEmpty
              ? const String.fromEnvironment('API_BASE_URL')
              : kIsWeb
              ? 'http://localhost:3000'
              : defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:3000'
              : 'http://localhost:3000');

  final http.Client _client;
  final String _baseUrl;

  Future<List<EstudoResumo>> listarEstudos() async {
    final resposta = await _client
        .get(Uri.parse('$_baseUrl/estudos'))
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 200) {
      throw StateError(
        'A API de estudos respondeu com HTTP ${resposta.statusCode}.',
      );
    }

    final corpo = jsonDecode(resposta.body);
    if (corpo is! Map || corpo['estudos'] is! List) {
      throw const FormatException('Resposta de listagem de estudos inválida.');
    }

    return (corpo['estudos'] as List)
        .map(
          (item) =>
              EstudoResumo.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<Map<String, dynamic>> criarEstudo(NovoEstudo estudo) async {
    final resposta = await _client
        .post(
          Uri.parse('$_baseUrl/estudos'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(estudo.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    final corpo = resposta.body.isEmpty ? null : jsonDecode(resposta.body);

    if (resposta.statusCode != 201) {
      final mensagem = corpo is Map && corpo['erro'] != null
          ? corpo['erro'].toString()
          : 'A API de estudos respondeu com HTTP ${resposta.statusCode}.';
      throw StateError(mensagem);
    }
    if (corpo is! Map || corpo['estudo'] is! Map) {
      throw const FormatException('Resposta de criação de estudo inválida.');
    }
    return Map<String, dynamic>.from(corpo['estudo'] as Map);
  }

  Future<void> atualizarEstudo(int idEstudo, Map<String, dynamic> dados) async {
    final resposta = await _client
        .patch(
          Uri.parse('$_baseUrl/estudos/$idEstudo'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(dados),
        )
        .timeout(const Duration(seconds: 15));

    final corpo = resposta.body.isEmpty ? null : jsonDecode(resposta.body);
    if (resposta.statusCode != 200) {
      final mensagem = corpo is Map && corpo['erro'] != null
          ? corpo['erro'].toString()
          : 'A API de estudos respondeu com HTTP ${resposta.statusCode}.';
      throw StateError(mensagem);
    }
  }

  Future<void> excluirEstudo(int idEstudo) async {
    final resposta = await _client
        .delete(Uri.parse('$_baseUrl/estudos/$idEstudo'))
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 200) {
      final corpo = resposta.body.isEmpty ? null : jsonDecode(resposta.body);
      final mensagem = corpo is Map && corpo['erro'] != null
          ? corpo['erro'].toString()
          : 'A API de estudos respondeu com HTTP ${resposta.statusCode}.';
      throw StateError(mensagem);
    }
  }

  void dispose() {
    _client.close();
  }
}
