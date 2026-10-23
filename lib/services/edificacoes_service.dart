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

  /// O back-end recusa áreas com lado maior que 0,1°.
  static const double ladoMaximoGraus = 0.1;

  final http.Client _client;
  final String _baseUrl;

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

    // A primeira consulta de uma região pode demorar (fonte externa).
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw StateError(
        'A API de edificações respondeu com HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException(
        'Resposta da API de edificações inválida.',
      );
    }

    return (decoded['data'] as List)
        .map(
          (item) => Edificacao.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
