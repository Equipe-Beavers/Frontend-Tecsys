import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';

abstract interface class RecommendationRepository {
  Future<ResultadoRecomendacao> gerarRecomendacao({
    required int idEstudo,
    required int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  });
}

class RecomendacaoService implements RecommendationRepository {
  RecomendacaoService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? _defaultUrl).replaceFirst(RegExp(r'/+$'), '');

  static String get _defaultUrl {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return defined;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<ResultadoRecomendacao> gerarRecomendacao({
    required int idEstudo,
    required int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  }) async {
    final uri = Uri.parse('$_baseUrl/study/$idEstudo/recommendation');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_perfil_rf': idPerfilRf,
            'id_criterio_instalacao': ?idCriterioInstalacao,
            'nome_cenario': ?nomeCenario,
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError(
        'A API de recomendação respondeu com HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Resposta de recomendação inválida.');
    }

    return ResultadoRecomendacao.fromJson(Map<String, dynamic>.from(decoded));
  }

  void dispose() => _client.close();
}
