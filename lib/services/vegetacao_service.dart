import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend_tecsys/models/vegetacao_config.dart';
import 'package:http/http.dart' as http;

class VegetacaoService {
  VegetacaoService({http.Client? client, String? baseUrl})
      : _ownsClient = client == null,
        _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: kIsWeb
                  ? 'http://localhost:3000'
                  : 'http://10.0.2.2:3000',
            );

  final bool _ownsClient;
  final http.Client _client;
  final String _baseUrl;

  Future<VegetacaoConfig> obterConfiguracao() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/vegetacao/config'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError('A API de vegetação respondeu com HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Resposta de configuração da vegetação inválida.');
    }

    return VegetacaoConfig.fromJson(Map<String, dynamic>.from(decoded));
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
