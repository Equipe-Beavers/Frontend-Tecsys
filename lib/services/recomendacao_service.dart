import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';

class RecomendacaoService {
  RecomendacaoService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:3000',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<ResultadoRecomendacao> gerarRecomendacao({
    required int idEstudo,
    required int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  }) async {
    final uri = Uri.parse('$_baseUrl/estudos/$idEstudo/recomendar');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_perfil_rf': idPerfilRf,
            if (idCriterioInstalacao != null)
              'id_criterio_instalacao': idCriterioInstalacao,
            if (nomeCenario != null) 'nome_cenario': nomeCenario,
          }),
        )
        .timeout(const Duration(seconds: 30));

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
