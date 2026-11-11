import 'dart:convert';

import '../config/api_config.dart';

import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';

abstract interface class RecommendationRepository {
  Future<RecommendationScenarios> loadScenarios({
    required int studyId,
    required int profileId,
    int? criterionId,
  });

  Future<void> selectScenario({required int studyId, required int scenarioId});

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
      _baseUrl = ApiConfig.resolve(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<RecommendationScenarios> loadScenarios({
    required int studyId,
    required int profileId,
    int? criterionId,
  }) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/study/$studyId/recommendations'))
        .timeout(const Duration(seconds: 30));
    final saved = _decodeResponse(response);
    if (saved['alternativas_geradas'] == true &&
        (saved['cenarios'] as List? ?? []).isNotEmpty) {
      return RecommendationScenarios.fromJson(saved);
    }
    return RecommendationScenarios.fromJson(
      await _generate(studyId, profileId, criterionId, null),
    );
  }

  @override
  Future<void> selectScenario({
    required int studyId,
    required int scenarioId,
  }) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/study/$studyId/selected-scenario'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_cenario': scenarioId}),
        )
        .timeout(const Duration(seconds: 30));
    _decodeResponse(response);
  }

  @override
  Future<ResultadoRecomendacao> gerarRecomendacao({
    required int idEstudo,
    required int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  }) async {
    return ResultadoRecomendacao.fromJson(
      await _generate(idEstudo, idPerfilRf, idCriterioInstalacao, nomeCenario),
    );
  }

  Future<Map<String, dynamic>> _generate(
    int idEstudo,
    int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  ) async {
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
        .timeout(const Duration(minutes: 5));

    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError(
        'A API de recomendação respondeu com HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Resposta de recomendação inválida.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  void dispose() => _client.close();
}
