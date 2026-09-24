import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/ativo_bdgd.dart';

class DistribuidoraResumo {
  const DistribuidoraResumo({
    required this.nome,
    required this.latitude,
    required this.longitude,
    required this.totalAtivos,
  });

  final String nome;
  final double latitude;
  final double longitude;
  final int totalAtivos;

  factory DistribuidoraResumo.fromJson(Map<String, dynamic> json) {
    return DistribuidoraResumo(
      nome: json['nome']?.toString() ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      totalAtivos: (json['totalAtivos'] as num).toInt(),
    );
  }
}

class AtivosResult {
  const AtivosResult({required this.ativos, required this.total});

  final List<AtivoBdgd> ativos;
  final int total;
}

class AtivosService {
  AtivosService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:3000',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<List<DistribuidoraResumo>> getDistribuidoras() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/ativos/distribuidoras'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
        'A API de distribuidoras respondeu com HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Resposta de distribuidoras inválida.');
    }
    return (decoded['data'] as List)
        .map(
          (item) => DistribuidoraResumo.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<AtivosResult> getAtivos({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    int limit = 3000,
    String? distribuidora,
    Set<String>? tipos,
  }) async {
    final query = <String, String>{
      'minLatitude': '$minLatitude',
      'maxLatitude': '$maxLatitude',
      'minLongitude': '$minLongitude',
      'maxLongitude': '$maxLongitude',
      'limit': '$limit',
    };
    if (distribuidora != null) {
      query['distribuidoras'] = distribuidora;
    }
    if (tipos != null && tipos.isNotEmpty) {
      query['tipos'] = tipos.join(',');
    }

    final uri = Uri.parse('$_baseUrl/api/ativos')
        .replace(queryParameters: query);

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError(
        'A API de ativos respondeu com HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Resposta da API de ativos inválida.');
    }

    try {
      final ativos = (decoded['data'] as List)
          .map(
            (item) =>
                AtivoBdgd.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      final rawTotal = decoded['total'];
      final total = rawTotal is num ? rawTotal.toInt() : ativos.length;
      return AtivosResult(ativos: ativos, total: total);
    } on FormatException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Falha ao converter ativos da API: $error\n$stackTrace');
      throw const FormatException('Dados de ativos inválidos.');
    }
  }

  void dispose() => _client.close();
}
