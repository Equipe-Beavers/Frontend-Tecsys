import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/edificacao.dart';

class EdificacoesService {
  EdificacoesService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: kIsWeb
                  ? 'http://localhost:3000'
                  : 'http://10.0.2.2:3000',
            );

  final http.Client _client;
  final String _baseUrl;

  static String _mensagemErro(http.Response response, String padrao) {
    try {
      final corpo = jsonDecode(response.body);
      if (corpo is Map && corpo['message'] != null) {
        return corpo['message'].toString();
      }
    } catch (_) {
      // Corpo não é JSON: usa a mensagem padrão.
    }
    return '$padrao (HTTP ${response.statusCode}).';
  }

  /// Edificações (altura, largura, profundidade e material) dentro da área visível do mapa.
  /// O backend consulta a Overture Maps sob demanda: a primeira busca de uma região pode
  /// levar alguns segundos; as seguintes vêm do cache do backend.
  Future<List<Edificacao>> getEdificacoes({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    int limit = 2000,
  }) async {
    final uri = Uri.parse('$_baseUrl/list-buildings').replace(
      queryParameters: {
        'minLatitude': '$minLatitude',
        'maxLatitude': '$maxLatitude',
        'minLongitude': '$minLongitude',
        'maxLongitude': '$maxLongitude',
        'limit': '$limit',
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 150));

    if (response.statusCode != 200) {
      throw StateError(_mensagemErro(response, 'A API de edificações falhou'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Resposta da API de edificações inválida.');
    }

    return (decoded['data'] as List)
        .map((item) => Edificacao.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Mancha de cobertura de um gateway no ponto informado, considerando as edificações.
  Future<ManchaCobertura> gerarMancha({
    required double latitude,
    required double longitude,
    required int idPerfilRf,
    double? alturaGatewayM,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/generate-coverage'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'latitude': latitude,
            'longitude': longitude,
            'id_perfil_rf': idPerfilRf,
            if (alturaGatewayM != null) 'gateway_height_m': alturaGatewayM,
          }),
        )
        .timeout(const Duration(seconds: 150));

    if (response.statusCode != 200) {
      throw StateError(_mensagemErro(response, 'Não foi possível calcular a mancha'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const FormatException('Resposta da mancha de cobertura inválida.');
    }

    return ManchaCobertura.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  /// Manchas já salvas de um cenário (uma por gateway e a consolidada).
  Future<ManchaCenario> getManchaCenario(int idCenario) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/get-scenario-coverage/$idCenario'))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError(_mensagemErro(response, 'Não foi possível carregar a mancha do cenário'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const FormatException('Resposta da mancha do cenário inválida.');
    }

    return ManchaCenario.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  void dispose() {
    _client.close();
  }
}
