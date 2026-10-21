import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/recomendacao_resultado.dart';
import 'recommendation/recommendation_map_overlays.dart';
import 'recommendation/recommendation_map_viewport.dart';
import 'recommendation/responsive_recommendation_map.dart';

class RecommendationMap extends StatelessWidget {
  const RecommendationMap({
    super.key,
    required this.gateways,
    this.assets = const [],
    this.selectedGateway,
    this.onGatewayTap,
    this.lockPosition = false,
    this.showBaseMap = true,
  });

  final List<GatewayProposto> gateways;
  final List<AtivoResultadoMapa> assets;
  final GatewayProposto? selectedGateway;
  final ValueChanged<GatewayProposto>? onGatewayTap;
  final bool lockPosition;
  final bool showBaseMap;

  static const _focusedMapFlags =
      InteractiveFlag.drag |
      InteractiveFlag.pinchZoom |
      InteractiveFlag.doubleTapZoom |
      InteractiveFlag.doubleTapDragZoom |
      InteractiveFlag.scrollWheelZoom;

  @override
  Widget build(BuildContext context) {
    final legendScale = MediaQuery.sizeOf(context).width >= 900 ? 1.44 : 1.0;
    final visibleGateways = selectedGateway == null
        ? gateways
        : <GatewayProposto>[selectedGateway!];
    final visibleAssets = _visibleAssets();
    final centerGateway = selectedGateway ?? gateways.firstOrNull;
    final viewport = RecommendationMapViewport.fromGateways(visibleGateways);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Positioned.fill(
            child: ResponsiveRecommendationMap(
              showBaseMap: showBaseMap,
              optionsBuilder: (size) => buildRecommendationMapOptions(
                size: size,
                viewport: viewport,
                centerGateway: centerGateway,
                showBaseMap: showBaseMap,
                interactionFlags: lockPosition
                    ? _focusedMapFlags
                    : InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              layers: buildRecommendationMapLayers(
                gateways: visibleGateways,
                assets: visibleAssets,
                selectedGateway: selectedGateway,
                onGatewayTap: onGatewayTap,
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Transform.scale(
              scale: legendScale,
              alignment: Alignment.bottomLeft,
              child: RecommendationMapLegend(
                gatewayCount: visibleGateways.length,
              ),
            ),
          ),
          if (lockPosition)
            const Positioned(
              right: 14,
              top: 14,
              child: RecommendationZoomHint(),
            ),
        ],
      ),
    );
  }

  List<AtivoResultadoMapa> _visibleAssets() {
    final gateway = selectedGateway;
    if (gateway == null) return assets;
    return assets
        .where(
          (asset) =>
              (asset.coberto && _isInsideCoverage(asset, gateway)) ||
              (!asset.coberto &&
                  asset.idGatewayReferencia == gateway.idEstudoPonto),
        )
        .toList();
  }

  bool _isInsideCoverage(AtivoResultadoMapa asset, GatewayProposto gateway) {
    const distance = Distance();
    return distance.as(
          LengthUnit.Meter,
          LatLng(asset.latitude, asset.longitude),
          LatLng(gateway.latitude, gateway.longitude),
        ) <=
        gateway.raioCoberturaM;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
