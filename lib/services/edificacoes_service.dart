import 'dart:convert';

import '../config/api_config.dart';

import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/edificacao.dart';

class EdificacoesService {
  EdificacoesService({
    http.Client? client,
    String? baseUrl,
    this.cacheTtl = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _baseUrl = ApiConfig.resolve(baseUrl),
       _now = now ?? DateTime.now;

  static const double ladoMaximoGraus = 0.1;
  static const int _cacheCapacity = 8;
  final http.Client _client;
  final String _baseUrl;
  final Duration cacheTtl;
  final DateTime Function() _now;
  final Map<String, _CachedBuildings> _cache = {};
  final Map<String, Future<List<Edificacao>>> _inFlight = {};
  bool _disposed = false;

  Future<List<Edificacao>> getEdificacoes({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    int limit = 2000,
  }) {
    if (_disposed) throw StateError('Serviço de edificações encerrado.');
    final bounds = [minLatitude, maxLatitude, minLongitude, maxLongitude];
    final key = jsonEncode([...bounds, limit]);
    final now = _now();
    _cache.removeWhere(
      (_, entry) => now.difference(entry.loadedAt) >= cacheTtl,
    );
    final exact = _cache.remove(key);
    if (exact != null) {
      _cache[key] = exact;
      return Future.value(exact.buildings);
    }
    // Só recorta consultas completas: uma resposta truncada pode esconder prédios.
    for (final cachedKey in _cache.keys.toList().reversed) {
      final entry = _cache[cachedKey]!;
      if (entry.complete && entry.covers(bounds)) {
        _cache.remove(cachedKey);
        _cache[cachedKey] = entry;
        return Future.value(
          List.unmodifiable(
            entry.buildings
                .where((building) => _intersects(building, bounds))
                .take(limit),
          ),
        );
      }
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final request = _fetch(bounds, limit, key).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = request;
    return request;
  }

  Future<List<Edificacao>> _fetch(
    List<double> bounds,
    int limit,
    String key,
  ) async {
    final uri = Uri.parse('$_baseUrl/list-buildings').replace(
      queryParameters: {
        'minLatitude': '${bounds[0]}',
        'maxLatitude': '${bounds[1]}',
        'minLongitude': '${bounds[2]}',
        'maxLongitude': '${bounds[3]}',
        'limit': '$limit',
      },
    );
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
      throw const FormatException('Resposta da API de edificações inválida.');
    }
    final buildings = List<Edificacao>.unmodifiable(
      (decoded['data'] as List).map(
        (item) => Edificacao.fromJson(Map<String, dynamic>.from(item as Map)),
      ),
    );
    final total = decoded['total'];
    if (!_disposed) {
      _cache[key] = _CachedBuildings(
        bounds,
        buildings,
        _now(),
        total is num && total <= buildings.length,
      );
      while (_cache.length > _cacheCapacity) {
        _cache.remove(_cache.keys.first);
      }
    }
    return buildings;
  }

  static bool _intersects(Edificacao building, List<double> bounds) {
    final points = building.poligonos
        .where((polygon) => polygon.isNotEmpty)
        .expand((polygon) => polygon.first)
        .toList();
    if (points.isEmpty) {
      return building.latitude >= bounds[0] &&
          building.latitude <= bounds[1] &&
          building.longitude >= bounds[2] &&
          building.longitude <= bounds[3];
    }
    var south = double.infinity, north = double.negativeInfinity;
    var west = double.infinity, east = double.negativeInfinity;
    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    return south <= bounds[1] &&
        north >= bounds[0] &&
        west <= bounds[3] &&
        east >= bounds[2];
  }

  void dispose() {
    _disposed = true;
    _cache.clear();
    _inFlight.clear();
    _client.close();
  }
}

class _CachedBuildings {
  const _CachedBuildings(
    this.bounds,
    this.buildings,
    this.loadedAt,
    this.complete,
  );
  final List<double> bounds;
  final List<Edificacao> buildings;
  final DateTime loadedAt;
  final bool complete;
  bool covers(List<double> other) =>
      bounds[0] <= other[0] &&
      bounds[1] >= other[1] &&
      bounds[2] <= other[2] &&
      bounds[3] >= other[3];
}
