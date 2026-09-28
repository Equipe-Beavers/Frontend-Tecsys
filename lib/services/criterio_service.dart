import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/config/api_config.dart';
import 'package:frontend_tecsys/models/criterio_instalacao.dart';

class CriterioService {
  CriterioService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<List<CriterioInstalacao>> getCriterios() async {
    final resposta = await _client
        .get(Uri.parse('$_baseUrl/criterios-instalacao'))
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 200) {
      throw StateError(
        'A API de critérios respondeu com HTTP ${resposta.statusCode}.',
      );
    }

    final corpo = jsonDecode(resposta.body);

    if (corpo is! Map || corpo['criterios'] is! List) {
      throw const FormatException(
        'Resposta da listagem de critérios inválida.',
      );
    }

    return (corpo['criterios'] as List)
        .map(
          (item) =>
              CriterioInstalacao.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  void dispose() => _client.close();
}
