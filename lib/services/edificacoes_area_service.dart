import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/edificacao.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/utils/geojson_utils.dart';

class LimitesArea {
  const LimitesArea({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  factory LimitesArea.dosPontos(List<LatLng> pontos) => LimitesArea(
    minLatitude: pontos.map((p) => p.latitude).reduce(math.min),
    maxLatitude: pontos.map((p) => p.latitude).reduce(math.max),
    minLongitude: pontos.map((p) => p.longitude).reduce(math.min),
    maxLongitude: pontos.map((p) => p.longitude).reduce(math.max),
  );

  Map<String, double> toJson() => {
    'minLatitude': minLatitude,
    'maxLatitude': maxLatitude,
    'minLongitude': minLongitude,
    'maxLongitude': maxLongitude,
  };
}

class EdificacoesAreaService {
  EdificacoesAreaService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _clientProprio = client == null,
      _baseUrl = _resolverBaseUrl(baseUrl) {
    _estudos = EstudosService(client: _client, baseUrl: _baseUrl);
  }

  static const double ladoFatiaGraus = 0.01;
  static const int maxFatias = 36;
  static const int limitePorFatia = 5000;
  static const Duration tempoMaximo = Duration(seconds: 90);

  final http.Client _client;
  final bool _clientProprio;
  final String _baseUrl;
  late final EstudosService _estudos;

  static String _resolverBaseUrl(String? baseUrl) {
    const configurada = String.fromEnvironment('API_BASE_URL');
    final url = baseUrl ??
        (configurada.isNotEmpty
            ? configurada
            : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                ? 'http://10.0.2.2:3000'
                : 'http://localhost:3000');
    return url.replaceFirst(RegExp(r'/+$'), '');
  }

  Future<({List<Edificacao> itens, int total})> _buscarFatia(
    LimitesArea fatia,
  ) async {
    final uri = Uri.parse('$_baseUrl/list-buildings').replace(
      queryParameters: {
        'minLatitude': '${fatia.minLatitude}',
        'maxLatitude': '${fatia.maxLatitude}',
        'minLongitude': '${fatia.minLongitude}',
        'maxLongitude': '${fatia.maxLongitude}',
        'limit': '$limitePorFatia',
      },
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError(
        'A API de edificações respondeu com HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Resposta da API de edificações inválida.');
    }
    final itens = (decoded['data'] as List)
        .map((item) => Edificacao.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return (
      itens: itens,
      total: (decoded['total'] as num?)?.toInt() ?? itens.length,
    );
  }

  void dispose() {
    if (_clientProprio) _client.close();
  }

  static List<LimitesArea> fatiar(LimitesArea area) {
    final colunas = math.max(
      1,
      ((area.maxLongitude - area.minLongitude) / ladoFatiaGraus - 1e-9).ceil(),
    );
    final linhas = math.max(
      1,
      ((area.maxLatitude - area.minLatitude) / ladoFatiaGraus - 1e-9).ceil(),
    );
    final larguraFatia = (area.maxLongitude - area.minLongitude) / colunas;
    final alturaFatia = (area.maxLatitude - area.minLatitude) / linhas;

    return [
      for (var linha = 0; linha < linhas; linha++)
        for (var coluna = 0; coluna < colunas; coluna++)
          LimitesArea(
            minLatitude: area.minLatitude + linha * alturaFatia,
            maxLatitude: area.minLatitude + (linha + 1) * alturaFatia,
            minLongitude: area.minLongitude + coluna * larguraFatia,
            maxLongitude: area.minLongitude + (coluna + 1) * larguraFatia,
          ),
    ];
  }

  Future<Map<String, dynamic>?> paraEstudo(int idEstudo) async {
    try {
      return await _paraEstudo(idEstudo).timeout(tempoMaximo);
    } catch (erro) {
      debugPrint('Edificações do estudo $idEstudo não enviadas ao back: $erro');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _paraEstudo(int idEstudo) async {
    final estudo = await _estudos.get(idEstudo);
    final area = _pontosDoPoligono(estudo['geom']);
    if (area == null) return null;
    return montarPayload(area);
  }

  Future<Map<String, dynamic>?> montarPayload(List<LatLng> area) async {
    if (area.length < 3) return null;

    final limites = LimitesArea.dosPontos(area);
    final fatias = fatiar(limites);
    if (fatias.length > maxFatias) {
      debugPrint(
        'Área do estudo grande demais para enviar as edificações '
        '(${fatias.length} fatias, máximo $maxFatias).',
      );
      return null;
    }

    final porId = <String, Edificacao>{};
    for (final fatia in fatias) {
      final resultado = await _buscarFatia(fatia);
      if (resultado.total > resultado.itens.length) {
        debugPrint(
          'Fatia com ${resultado.total} edificações, acima do limite de '
          '$limitePorFatia: o back usará a própria fonte.',
        );
        return null;
      }
      for (final edificacao in resultado.itens) {
        porId[edificacao.id] = edificacao;
      }
    }

    final dentro = porId.values.where((e) => _dentroDaArea(e, area));

    return {
      'area': limites.toJson(),
      'poligono': [
        for (final p in area) [p.longitude, p.latitude],
      ],
      'itens': [for (final e in dentro) e.toPayloadJson()],
    };
  }

  static bool _dentroDaArea(Edificacao edificacao, List<LatLng> area) {
    if (pontoDentroDoPoligono(
      LatLng(edificacao.latitude, edificacao.longitude),
      area,
    )) {
      return true;
    }
    return edificacao.poligonos.any(
      (poligono) =>
          poligono.isNotEmpty &&
          poligono.first.any((vertice) => pontoDentroDoPoligono(vertice, area)),
    );
  }

  static List<LatLng>? _pontosDoPoligono(dynamic geom) {
    if (geom is! Map || geom['type'] != 'Polygon') return null;
    final aneis = geom['coordinates'];
    if (aneis is! List || aneis.isEmpty || aneis.first is! List) return null;

    final pontos = <LatLng>[];
    for (final ponto in aneis.first as List) {
      if (ponto is! List || ponto.length < 2) return null;
      pontos.add(LatLng((ponto[1] as num).toDouble(), (ponto[0] as num).toDouble()));
    }
    return pontos.length >= 3 ? pontos : null;
  }
}
