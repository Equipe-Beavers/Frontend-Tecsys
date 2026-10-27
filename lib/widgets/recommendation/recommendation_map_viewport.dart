import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../models/mancha_cenario.dart';
import '../../models/recomendacao_resultado.dart';

class RecommendationGeoBounds {
  const RecommendationGeoBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  CoordinateBounds toMapboxBounds() => CoordinateBounds(
    southwest: Point(coordinates: Position(west, south)),
    northeast: Point(coordinates: Position(east, north)),
    infiniteBounds: false,
  );
}

class RecommendationMapViewport {
  const RecommendationMapViewport({
    required this.coverageBounds,
    required this.displayBounds,
  });

  static const displayRadiusFactor = 1.2;

  final RecommendationGeoBounds coverageBounds;
  final RecommendationGeoBounds displayBounds;

  static RecommendationMapViewport? fromGateways(
    List<GatewayProposto> gateways,
  ) => fromContent(gateways: gateways);

  static RecommendationMapViewport? fromContent({
    required List<GatewayProposto> gateways,
    List<ManchaGatewayCenario> scenarioCoverage = const [],
    List<AtivoResultadoMapa> assets = const [],
  }) {
    if (gateways.isEmpty) return null;
    final coveragePoints = _gatewayCoveragePoints(gateways);
    for (final coverage in scenarioCoverage) {
      coveragePoints.addAll(coverage.mancha);
    }
    final displayPoints = <LatLng>[
      ...coveragePoints,
      for (final asset in assets) LatLng(asset.latitude, asset.longitude),
    ];

    return RecommendationMapViewport(
      coverageBounds: _boundsForPoints(coveragePoints),
      displayBounds: _expandBounds(
        _boundsForPoints(displayPoints),
        displayRadiusFactor,
      ),
    );
  }

  static List<LatLng> _gatewayCoveragePoints(List<GatewayProposto> gateways) {
    const distance = Distance();
    final points = <LatLng>[];
    for (final gateway in gateways) {
      final center = LatLng(gateway.latitude, gateway.longitude);
      final radius = gateway.raioCoberturaM;
      points.addAll([
        distance.offset(center, radius, 0),
        distance.offset(center, radius, 90),
        distance.offset(center, radius, 180),
        distance.offset(center, radius, 270),
      ]);
    }
    return points;
  }

  static RecommendationGeoBounds _boundsForPoints(List<LatLng> points) {
    return RecommendationGeoBounds(
      north: points.map((point) => point.latitude).reduce(_max),
      south: points.map((point) => point.latitude).reduce(_min),
      east: points.map((point) => point.longitude).reduce(_max),
      west: points.map((point) => point.longitude).reduce(_min),
    );
  }

  static RecommendationGeoBounds _expandBounds(
    RecommendationGeoBounds bounds,
    double factor,
  ) {
    final centerLatitude = (bounds.north + bounds.south) / 2;
    final centerLongitude = (bounds.east + bounds.west) / 2;
    final halfLatitude = (bounds.north - bounds.south) * factor / 2;
    final halfLongitude = (bounds.east - bounds.west) * factor / 2;
    return RecommendationGeoBounds(
      north: centerLatitude + halfLatitude,
      south: centerLatitude - halfLatitude,
      east: centerLongitude + halfLongitude,
      west: centerLongitude - halfLongitude,
    );
  }
}

double _max(double a, double b) => a > b ? a : b;
double _min(double a, double b) => a < b ? a : b;

const recommendationMinimumAllowedZoom = 8.5;
const recommendationMaximumZoom = 17.0;
const recommendationMobileBreakpoint = 600.0;

double recommendationCameraSafetyZoomOut(
  double mapWidth, {
  bool focused = false,
}) {
  if (mapWidth >= recommendationMobileBreakpoint) return .15;
  // The overview emphasizes the gateway cluster; details retain their own fit.
  return focused ? .665477217 : -.35;
}

double recommendationMinimumZoom(double fittedZoom) => (fittedZoom - 3).clamp(
  recommendationMinimumAllowedZoom,
  recommendationMaximumZoom,
);
