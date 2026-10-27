import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/ativo_bdgd.dart';

class DistribuidoraResumo {
  const DistribuidoraResumo({
    required this.id,
    required this.nome,
    required this.uf,
    required this.anoBdgd,
  });

  final int id;
  final String nome;
  final String? uf;
  final int anoBdgd;

  factory DistribuidoraResumo.fromJson(Map<String, dynamic> json) {
    return DistribuidoraResumo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nome: json['nome']?.toString() ?? '',
      uf: json['uf']?.toString(),
      anoBdgd: (json['anoBdgd'] as num?)?.toInt() ?? 0,
    );
  }
}

class TipoDispositivoResumo {
  const TipoDispositivoResumo({
    required this.id,
    required this.nome,
    this.categoria,
  });

  final int id;
  final String nome;
  final String? categoria;

  factory TipoDispositivoResumo.fromJson(Map<String, dynamic> json) {
    return TipoDispositivoResumo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nome: json['nome']?.toString() ?? '',
      categoria: json['categoria']?.toString(),
    );
  }
}

class MunicipioResumo {
  const MunicipioResumo({
    required this.nome,
    required this.uf,
    this.latitude,
    this.longitude,
  });

  final String nome;
  final String uf;
  final double? latitude;
  final double? longitude;

  factory MunicipioResumo.fromJson(Map<String, dynamic> json) {
    return MunicipioResumo(
      nome: json['nome']?.toString() ?? '',
      uf: json['uf']?.toString() ?? '',
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble(),
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
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: kIsWeb
                        ? 'http://localhost:3000'
                        : 'http://10.0.2.2:3000',
                  ))
              .replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  static String _normalizarMunicipio(String? valor) {
    final texto = (valor ?? '').trim();

    if (texto.isEmpty || texto == 'Não informado') {
      return '';
    }

    final parte = texto.split('-').first.trim();

    return parte.isEmpty ? texto : parte;
  }

  static String _normalizarEstado(String? valor) {
    final texto = (valor ?? '').trim();

    if (texto.isEmpty || texto == 'Não informado') {
      return '';
    }

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

      if (estadoFiltro != null && estadoFiltro.isNotEmpty) {
        if (_normalizarEstado(ativo.municipio).toLowerCase() !=
            estadoFiltro.toLowerCase()) {
          return false;
        }
      }

      if (municipioFiltro != null && municipioFiltro.isNotEmpty) {
        final nomeMunicipio = _normalizarMunicipio(ativo.municipio)
            .toLowerCase();
        final nomeBairro = ativo.bairro.trim().toLowerCase();
        final alvo = municipioFiltro.toLowerCase();

        if (nomeMunicipio != alvo &&
            nomeBairro != alvo &&
            !nomeMunicipio.contains(alvo) &&
            !nomeBairro.contains(alvo)) {
          return false;
        }
      }

      if (buscaFiltro != null && buscaFiltro.isNotEmpty) {
        final textoBusca =
            '${ativo.municipio} ${ativo.bairro} ${ativo.distribuidora}'
                .toLowerCase();

        if (!textoBusca.contains(buscaFiltro)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<List<DistribuidoraResumo>> getDistribuidoras() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/distribuidoras'))
        // A primeira chamada agrega 7M de posições no banco remoto; as
        // seguintes são atendidas pelo cache do backend em milissegundos.
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw StateError(
        'A API de distribuidoras respondeu com HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw const FormatException('Resposta de distribuidoras inválida.');
    }

    return decoded
        .map(
          (item) => DistribuidoraResumo.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<TipoDispositivoResumo>> getTiposDispositivos() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/ativos/tipos-dispositivos'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError(
        'A API de tipos de dispositivos respondeu com HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException(
        'Resposta de tipos de dispositivos inválida.',
      );
    }

    return (decoded['data'] as List)
        .map(
          (item) => TipoDispositivoResumo.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<MunicipioResumo>> getMunicipios({
    required String distribuidora,
    required String uf,
  }) async {
    final municipios = <MunicipioResumo>[];
    var pagina = 1;
    var totalPaginas = 1;

    do {
      final uri = Uri.parse('$_baseUrl/municipios').replace(
        queryParameters: {
          'distribuidora': distribuidora,
          'uf': uf,
          'limite': '100',
          'pagina': '$pagina',
        },
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        throw StateError(
          'A API de municípios respondeu com HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['dados'] is! List ||
          decoded['paginacao'] is! Map) {
        throw const FormatException('Resposta de municípios inválida.');
      }

      municipios.addAll(
        (decoded['dados'] as List).map(
          (item) =>
              MunicipioResumo.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );

      final pagination = Map<String, dynamic>.from(decoded['paginacao'] as Map);
      final paginas = pagination['totalPaginas'];
      if (paginas is! num || paginas < 0) {
        throw const FormatException(
          'Paginação da resposta de municípios inválida.',
        );
      }
      totalPaginas = paginas.toInt();
      pagina++;
    } while (pagina <= totalPaginas);

    return municipios;
  }

  Future<AtivoBdgd> getAtivoPorId(String id) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/ativos/${Uri.encodeComponent(id)}'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError(
        'A API do ativo respondeu com HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException('Resposta do ativo inválida.');
    }
    final ativo = decoded['active'] is Map ? decoded['active'] as Map : decoded;
    return AtivoBdgd.fromJson(Map<String, dynamic>.from(ativo));
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

    final uri = Uri.parse('$_baseUrl/ativos').replace(queryParameters: query);

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      var detalhe = response.body.trim();
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody['message'] != null) {
          detalhe = errorBody['message'].toString();
        }
      } on FormatException {
        // Keep the raw response body when the API does not return JSON.
      }

      throw StateError(
        'A API de ativos respondeu com HTTP ${response.statusCode}'
        '${detalhe.isEmpty ? '.' : ': $detalhe'}',
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

  void dispose() {
    _client.close();
  }
}
