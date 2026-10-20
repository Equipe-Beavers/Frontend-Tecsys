import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend_tecsys/models/emissao_rf.dart';
import 'package:http/http.dart' as http;

class EmissoesRfResult {
  const EmissoesRfResult({required this.emissoes, required this.total, required this.limit});

  final List<EmissaoRf> emissoes;
  final int total;
  final int limit;

  bool get truncado => emissoes.length < total;
}

class EmissoesRfService {
  EmissoesRfService({http.Client? client, String? baseUrl})
      : _ownsClient = client == null,
        _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000',
            );

  final bool _ownsClient;
  final http.Client _client;
  final String _baseUrl;

  Future<EmissoesRfResult> listar({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    int limit = 5000,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/emissoes-rf').replace(
      queryParameters: {
        'minLatitude': '$minLatitude',
        'maxLatitude': '$maxLatitude',
        'minLongitude': '$minLongitude',
        'maxLongitude': '$maxLongitude',
        'limit': '$limit',
      },
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('A API de emissões RF respondeu com HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Resposta da API de emissões RF inválida.');
    }
    final emissoes = (decoded['data'] as List)
        .whereType<Map>()
        .map((item) => EmissaoRf.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final totalRaw = decoded['total'];
    final limitRaw = decoded['limit'];
    return EmissoesRfResult(
      emissoes: emissoes,
      total: totalRaw is num ? totalRaw.toInt() : emissoes.length,
      limit: limitRaw is num ? limitRaw.toInt() : limit,
    );
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
