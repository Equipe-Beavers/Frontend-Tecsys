import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/recomendacao_resultado.dart';
import '../../theme/app_colors.dart';

class RecommendationMapViewport {
  const RecommendationMapViewport({
    required this.coverageBounds,
    required this.displayBounds,
  });

  static const displayRadiusFactor = 1.2;

  final LatLngBounds coverageBounds;
  final LatLngBounds displayBounds;

  static RecommendationMapViewport? fromGateways(
    List<GatewayProposto> gateways,
  ) {
    if (gateways.isEmpty) return null;
    return RecommendationMapViewport(
      coverageBounds: _boundsFor(gateways, radiusFactor: 1),
      displayBounds: _boundsFor(gateways, radiusFactor: displayRadiusFactor),
    );
  }

  static LatLngBounds _boundsFor(
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
    return LatLngBounds.fromPoints(points);
  }
}

MapOptions buildRecommendationMapOptions({
  required Size size,
  required RecommendationMapViewport? viewport,
  required GatewayProposto? centerGateway,
  required bool showBaseMap,
  required int interactionFlags,
}) {
  final fallbackCenter = centerGateway == null
      ? const LatLng(-23.2, -45.88)
      : LatLng(centerGateway.latitude, centerGateway.longitude);
  final fit = viewport == null
      ? null
      : CameraFit.bounds(bounds: viewport.displayBounds, maxZoom: 13.4);
  final baseOptions = MapOptions(
    initialCenter: fallbackCenter,
    initialZoom: 12.5,
    minZoom: 2,
    maxZoom: 18,
  );
  final fittedCamera = fit?.fit(
    MapCamera.initialCamera(baseOptions).withNonRotatedSize(size),
  );

  return MapOptions(
    initialCenter: fittedCamera?.center ?? fallbackCenter,
    initialZoom: fittedCamera?.zoom ?? 12.5,
    initialCameraFit: fit,
    minZoom: fittedCamera?.zoom ?? 2,
    maxZoom: 18,
    cameraConstraint: viewport == null
        ? const CameraConstraint.unconstrained()
        : CameraConstraint.containCenter(bounds: viewport.coverageBounds),
    backgroundColor: showBaseMap
        ? const Color(0xFFE6E6E6)
        : AppColors.surfaceBackground,
    interactionOptions: InteractionOptions(flags: interactionFlags),
  );
}
