import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend_tecsys/models/mancha_cenario.dart';
import 'package:http/http.dart' as http;

class ManchaCenarioService {
  ManchaCenarioService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: kIsWeb
                ? 'http://localhost:3000'
                : 'http://10.0.2.2:3000',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<ManchaCenario> getManchaCenario(int idCenario) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/get-scenario-coverage/$idCenario'))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError(
        'A API de cobertura respondeu com HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const FormatException('Resposta da mancha do cenário inválida.');
    }

    return ManchaCenario.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  void dispose() => _client.close();
}
