import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/config/api_config.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';

class DistribuidoraResumo {
  const DistribuidoraResumo({
    required this.id,
    required this.nome,
    required this.uf,
    required this.anoBdgd,
    this.totalAtivos = 0,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String nome;
  final String? uf;
  final int anoBdgd;
  final int totalAtivos;
  final double? latitude;
  final double? longitude;

  bool get possuiAtivosLocais => totalAtivos > 0;

  factory DistribuidoraResumo.fromJson(Map<String, dynamic> json) {
    return DistribuidoraResumo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nome: json['nome']?.toString() ?? '',
      uf: json['uf']?.toString(),
      anoBdgd: (json['anoBdgd'] as num?)?.toInt() ?? 0,
      totalAtivos: (json['totalAtivos'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class MunicipioResumo {
  const MunicipioResumo({
    required this.nome,
    required this.totalAtivos,
    this.uf,
    this.latitude,
    this.longitude,
  });

  final String nome;
  final String? uf;
  final int totalAtivos;
  final double? latitude;
  final double? longitude;

  factory MunicipioResumo.fromJson(Map<String, dynamic> json) {
    return MunicipioResumo(
      nome: json['nome']?.toString() ?? '',
      uf: json['uf']?.toString(),
      totalAtivos: (json['totalAtivos'] as num?)?.toInt() ?? 0,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class AtivosResult {
  const AtivosResult({
    required this.ativos,
    required this.total,
  });

  final List<AtivoBdgd> ativos;
  final int total;
}

class AtivosService {
  AtivosService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? ApiConfig.baseUrl)
            .replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  // O backend limita a 100 registros por página nas consultas de região.
  static const int _limitePaginaRegiao = 100;
  static const int _maxPaginasRegiao = 10;

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
        // O backend já resolve o nome do município (IBGE) e filtra;
        // aqui só garantimos a coerência com o que veio na resposta.
        final nomeMunicipio = ativo.municipio.trim().toLowerCase();
        final alvo = municipioFiltro.toLowerCase();

        if (nomeMunicipio != alvo && !nomeMunicipio.contains(alvo)) {
          return false;
        }
      }

      if (buscaFiltro != null && buscaFiltro.isNotEmpty) {
        final textoBusca =
            '${ativo.municipio} ${ativo.distribuidora}'.toLowerCase();

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

    final List<dynamic>? lista = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List)
            ? decoded['data'] as List
            : null;

    if (lista == null) {
      throw const FormatException(
        'Resposta de distribuidoras inválida.',
      );
    }

    return lista
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

    final uri = Uri.parse('$_baseUrl/api/ativos').replace(
      queryParameters: query,
    );

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
      throw const FormatException(
        'Resposta da API de ativos inválida.',
      );
    }

    final ativos = (decoded['data'] as List)
        .map(
          (item) => AtivoBdgd.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
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

    final total = rawTotal is num
        ? rawTotal.toInt()
        : filtered.length;

    return AtivosResult(
      ativos: filtered,
      total: total,
    );
  }

  Future<List<MunicipioResumo>> getMunicipios({
    required String distribuidora,
    String? busca,
  }) {
    return _buscarPaginas(
      path: '/api/municipios',
      filtros: {
        'distribuidora': distribuidora,
        if (busca != null && busca.isNotEmpty) 'busca': busca,
      },
      fromJson: MunicipioResumo.fromJson,
    );
  }

  Future<List<T>> _buscarPaginas<T>({
    required String path,
    required Map<String, String> filtros,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final itens = <T>[];

    for (var pagina = 1; pagina <= _maxPaginasRegiao; pagina++) {
      final uri = Uri.parse('$_baseUrl$path').replace(
        queryParameters: {
          ...filtros,
          'pagina': '$pagina',
          'limite': '$_limitePaginaRegiao',
        },
      );

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw StateError(
          'A API de regiões respondeu com HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['dados'] is! List) {
        throw const FormatException('Resposta da API de regiões inválida.');
      }

      itens.addAll(
        (decoded['dados'] as List).map(
          (item) => fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );

      final paginacao = decoded['paginacao'];
      final totalPaginas = paginacao is Map
          ? ((paginacao['totalPaginas'] as num?)?.toInt() ?? 1)
          : 1;

      if (pagina >= totalPaginas) break;
    }

    return itens;
  }

  void dispose() {
    _client.close();
  }
}
