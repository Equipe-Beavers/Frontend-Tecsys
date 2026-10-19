import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend_tecsys/models/antena_anatel.dart';
import 'package:http/http.dart' as http;

class AntenasResult {
  const AntenasResult({required this.antenas, required this.total});

  final List<AntenaAnatel> antenas;
  final int total;
}

class AntenasService {
  AntenasService({http.Client? client, String? baseUrl})
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

  Future<AntenasResult> listar({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    int limit = 1000,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/antenas').replace(
      queryParameters: {
        'minLatitude': '$minLatitude',
        'maxLatitude': '$maxLatitude',
        'minLongitude': '$minLongitude',
        'maxLongitude': '$maxLongitude',
        'limit': '$limit',
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError('A API de antenas respondeu com HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Resposta da API de antenas inválida.');
    }

    final antenas = (decoded['data'] as List)
        .whereType<Map>()
        .map((item) => AntenaAnatel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final totalRaw = decoded['total'];

    return AntenasResult(
      antenas: antenas,
      total: totalRaw is num ? totalRaw.toInt() : antenas.length,
    );
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
