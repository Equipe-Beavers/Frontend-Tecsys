import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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

  static const displayRadiusFactor = 1.1;

  final RecommendationGeoBounds coverageBounds;
  final RecommendationGeoBounds displayBounds;

  static RecommendationMapViewport? fromGateways(
    List<GatewayProposto> gateways,
  ) {
    if (gateways.isEmpty) return null;
    return RecommendationMapViewport(
      coverageBounds: _boundsFor(gateways, radiusFactor: 1),
      displayBounds: _boundsFor(gateways, radiusFactor: displayRadiusFactor),
    );
  }

  static RecommendationGeoBounds _boundsFor(
    List<GatewayProposto> gateways, {
    required double radiusFactor,
  }) {
    const distance = Distance();
    final points = <LatLng>[];
    for (final gateway in gateways) {
      final center = LatLng(gateway.latitude, gateway.longitude);
      final radius = gateway.raioCoberturaM * radiusFactor;
      points.addAll([
        distance.offset(center, radius, 0),
        distance.offset(center, radius, 90),
        distance.offset(center, radius, 180),
        distance.offset(center, radius, 270),
      ]);
    }

    return RecommendationGeoBounds(
      north: points.map((point) => point.latitude).reduce(_max),
      south: points.map((point) => point.latitude).reduce(_min),
      east: points.map((point) => point.longitude).reduce(_max),
      west: points.map((point) => point.longitude).reduce(_min),
    );
  }
}

double _max(double a, double b) => a > b ? a : b;
double _min(double a, double b) => a < b ? a : b;

const recommendationMinimumAllowedZoom = 8.5;
const recommendationMaximumZoom = 17.0;

double recommendationMinimumZoom(double fittedZoom) =>
    (fittedZoom - 3).clamp(
      recommendationMinimumAllowedZoom,
      recommendationMaximumZoom,
    );
