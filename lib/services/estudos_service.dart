import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/novo_estudo.dart';

class EstudosService {
  EstudosService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? _defaultUrl).replaceFirst(RegExp(r'/+$'), '');

  static String get _defaultUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  final http.Client _client;
  final String _baseUrl;

  void dispose() => _client.close();

  Future<Map<String, dynamic>> get(int id) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/estudos/$id'))
        .timeout(const Duration(seconds: 15));
    return _readStudy(response, 200);
  }

  Future<Map<String, dynamic>> update(
    int id,
    Map<String, dynamic> values,
  ) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/estudos/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(values),
        )
        .timeout(const Duration(seconds: 15));
    return _readStudy(response, 200);
  }

  Future<void> delete(int id) async {
    final response = await _client
        .delete(Uri.parse('$_baseUrl/estudos/$id'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 204) _readStudy(response, 204);
  }

  Map<String, dynamic> _readStudy(http.Response response, int expectedStatus) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode != expectedStatus) {
      throw StudyApiException(
        response.statusCode,
        body is Map
            ? (body['message'] ??
                      body['erro'] ??
                      'Não foi possível concluir a operação.')
                  .toString()
            : 'Não foi possível concluir a operação.',
      );
    }
    if (body is! Map || body['estudo'] is! Map) {
      throw const FormatException('Resposta de estudo inválida.');
    }
    return Map<String, dynamic>.from(body['estudo'] as Map);
  }

  Future<List<Map<String, dynamic>>> list({int? userId}) async {
    final uri = Uri.parse('$_baseUrl/estudos');
    final requestUri = userId == null
        ? uri
        : uri.replace(queryParameters: {'id_usuario': '$userId'});
    final response = await _client
        .get(requestUri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
        'A API de estudos respondeu com HTTP ${response.statusCode}.',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['estudos'] is! List) {
      throw const FormatException('Resposta de listagem de estudos inválida.');
    }
    return (body['estudos'] as List).map((item) {
      if (item is! Map) {
        throw const FormatException('Estudo inválido na listagem.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
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
      final mensagem =
          corpo is Map && (corpo['erro'] ?? corpo['message']) != null
          ? (corpo['erro'] ?? corpo['message']).toString()
          : 'A API de estudos respondeu com HTTP ${resposta.statusCode}.';
      throw StateError(mensagem);
    }
    if (corpo is! Map || corpo['estudo'] is! Map) {
      throw const FormatException('Resposta de criação de estudo inválida.');
    }
    return Map<String, dynamic>.from(corpo['estudo'] as Map);
  }
}

class StudyApiException implements Exception {
  const StudyApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}
