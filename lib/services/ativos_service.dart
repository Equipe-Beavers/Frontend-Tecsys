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
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      totalAtivos: (json['totalAtivos'] as num?)?.toInt() ?? 0,
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
            defaultValue: kIsWeb
                ? 'http://localhost:3000'
                : 'http://10.0.2.2:3000',
          );

  final http.Client _client;
  final String _baseUrl;

  static String _normalizarMunicipio(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty || texto == 'Não informado') return '';
    final parte = texto.split('-').first.trim();
    return parte.isEmpty ? texto : parte;
  }

  static String _normalizarEstado(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty || texto == 'Não informado') return '';
    if (texto.contains('-')) {
      return texto.split('-').last.trim();
    }
    return texto;
  }

  static List<AtivoBdgd> _aplicarFiltros(
    List<AtivoBdgd> ativos, {
    String? distribuidora,
    Set<String>? tipos,
    String? estado,
    String? municipio,
    String? busca,
  }) {
    final estadoFiltro = estado?.trim();
    final municipioFiltro = municipio?.trim();
    final buscaFiltro = busca?.trim().toLowerCase();

    return ativos.where((ativo) {
      if (distribuidora != null &&
          distribuidora.isNotEmpty &&
          ativo.distribuidora.trim() != distribuidora) {
        return false;
      }

      if (tipos != null && tipos.isNotEmpty) {
        final tipoApi = ativo.tipo.apiValue;
        if (!tipos.contains(tipoApi)) {
          return false;
        }
      }

      if (estadoFiltro != null &&
          estadoFiltro.isNotEmpty &&
          _normalizarEstado(ativo.municipio).toLowerCase() !=
              estadoFiltro.toLowerCase()) {
        return false;
      }

      if (municipioFiltro != null && municipioFiltro.isNotEmpty) {
        final nomeMunicipio = _normalizarMunicipio(ativo.municipio).toLowerCase();
        final nomeBairro = ativo.bairro.trim().toLowerCase();
        final alvo = municipioFiltro.toLowerCase();
        if (nomeMunicipio != alvo && nomeBairro != alvo &&
            !nomeMunicipio.contains(alvo) && !nomeBairro.contains(alvo)) {
          return false;
        }
      }

      if (buscaFiltro != null && buscaFiltro.isNotEmpty) {
        final textoBusca = '${ativo.municipio} ${ativo.bairro} ${ativo.distribuidora}'.toLowerCase();
        if (!textoBusca.contains(buscaFiltro)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<List<DistribuidoraResumo>> getDistribuidoras() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/distribuidoras'))
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
    String? estado,
    String? municipio,
    String? busca,
  }) async {
    final query = <String, String>{
      'minLatitude': '$minLatitude',
      'maxLatitude': '$maxLatitude',
      'minLongitude': '$minLongitude',
      'maxLongitude': '$maxLongitude',
      'limit': '$limit',
    };
    if (distribuidora != null && distribuidora.isNotEmpty) {
      query['distribuidoras'] = distribuidora;
    }
    if (tipos != null && tipos.isNotEmpty) {
      query['tipos'] = tipos.join(',');
    }
    if (estado != null && estado.isNotEmpty) {
      query['estado'] = estado;
    }
    if (municipio != null && municipio.isNotEmpty) {
      query['municipio'] = municipio;
    }
    if (busca != null && busca.isNotEmpty) {
      query['busca'] = busca;
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

    final ativos = (decoded['data'] as List)
        .map(
          (item) => AtivoBdgd.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    final filtered = _aplicarFiltros(
      ativos,
      distribuidora: distribuidora,
      tipos: tipos,
      estado: estado,
      municipio: municipio,
      busca: busca,
    );

    final rawTotal = decoded['total'];
    final total = rawTotal is num ? rawTotal.toInt() : filtered.length;
    return AtivosResult(ativos: filtered, total: total);
  }

  void dispose() => _client.close();
}
