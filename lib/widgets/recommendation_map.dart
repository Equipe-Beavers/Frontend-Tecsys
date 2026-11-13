import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/mancha_cenario.dart';
import '../models/recomendacao_resultado.dart';
import 'recommendation/recommendation_map_overlays.dart';
import 'recommendation/recommendation_map_viewport.dart';
import 'recommendation/responsive_recommendation_map.dart';

class RecommendationMap extends StatelessWidget {
  const RecommendationMap({
    super.key,
    required this.gateways,
    this.assets = const [],
    this.scenarioCoverage = const [],
    this.selectedGateway,
    this.onGatewayTap,
    this.lockPosition = false,
    this.showBaseMap = true,
  });

  final List<GatewayProposto> gateways;
  final List<AtivoResultadoMapa> assets;
  final List<ManchaGatewayCenario> scenarioCoverage;
  final GatewayProposto? selectedGateway;
  final ValueChanged<GatewayProposto>? onGatewayTap;
  final bool lockPosition;
  final bool showBaseMap;

  @override
  Widget build(BuildContext context) {
    final legendScale = MediaQuery.sizeOf(context).width >= 900 ? 1.44 : 1.0;
    final visibleGateways = selectedGateway == null
        ? gateways
        : <GatewayProposto>[selectedGateway!];
    final visibleAssets = _visibleAssets();
    final visibleScenarioCoverage = _visibleScenarioCoverage();
    final viewport = RecommendationMapViewport.fromContent(
      gateways: visibleGateways,
      scenarioCoverage: visibleScenarioCoverage,
      assets: visibleAssets,
    );
    final compact = MediaQuery.sizeOf(context).width < 600;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Positioned.fill(
            child: ResponsiveRecommendationMap(
              gateways: visibleGateways,
              assets: visibleAssets,
              scenarioCoverage: visibleScenarioCoverage,
              viewport: viewport,
              selectedGateway: selectedGateway,
              onGatewayTap: onGatewayTap,
              showBaseMap: showBaseMap,
              lockPosition: lockPosition,
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
          if (lockPosition && !compact)
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

  List<ManchaGatewayCenario> _visibleScenarioCoverage() {
    final visible = selectedGateway == null ? gateways : [selectedGateway!];
    return [for (final gateway in visible) ..._coverageFor(gateway)];
  }

  List<ManchaGatewayCenario> _coverageFor(GatewayProposto gateway) {
    final saved = scenarioCoverage
        .where(
          (coverage) =>
              coverage.idEstudoPonto == gateway.idEstudoPonto &&
              coverage.mancha.length >= 3,
        )
        .toList();
    if (saved.isNotEmpty) return saved;
    return [
      for (final ring in gateway.manchasCobertura)
        ManchaGatewayCenario(
          idEstudoPonto: gateway.idEstudoPonto,
          rotulo: gateway.rotulo,
          posicao: LatLng(gateway.latitude, gateway.longitude),
          alcanceMedioM: gateway.raioCoberturaM.round(),
          mancha: ring,
        ),
    ];
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
