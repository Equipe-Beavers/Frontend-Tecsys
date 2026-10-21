import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/ativo_bdgd.dart';
import '../../models/recomendacao_resultado.dart';
import '../../theme/app_colors.dart';

List<Widget> buildRecommendationMapLayers({
  required List<GatewayProposto> gateways,
  required List<AtivoResultadoMapa> assets,
  required GatewayProposto? selectedGateway,
  required ValueChanged<GatewayProposto>? onGatewayTap,
}) => [
  CircleLayer(
    circles: [
      for (final gateway in gateways)
        CircleMarker(
          key: ValueKey('coverage-${gateway.idEstudoPonto}'),
          point: LatLng(gateway.latitude, gateway.longitude),
          radius: gateway.raioCoberturaM,
          useRadiusInMeter: true,
          color: AppColors.coverageArea.withValues(alpha: .24),
          borderColor: AppColors.coverageBorder.withValues(alpha: .9),
          borderStrokeWidth: 1.8,
        ),
    ],
  ),
  MarkerLayer(
    markers: [
      for (final asset in assets)
        Marker(
          key: ValueKey(
            '${asset.coberto ? 'covered' : 'uncovered'}-asset-${asset.idEstudoPonto}',
          ),
          point: LatLng(asset.latitude, asset.longitude),
          width: 22,
          height: 22,
          child: Semantics(
            label:
                '${asset.tipoAtivo.label}: ${asset.coberto ? 'ativo coberto' : 'sem cobertura'}',
            child: _AssetMarker(covered: asset.coberto),
          ),
        ),
    ],
  ),
  MarkerLayer(
    markers: [
      for (final gateway in gateways)
        Marker(
          key: ValueKey('gateway-${gateway.idEstudoPonto}'),
          point: LatLng(gateway.latitude, gateway.longitude),
          width: 42,
          height: 42,
          child: Semantics(
            button: onGatewayTap != null,
            label: 'Abrir detalhes de ${gateway.rotulo ?? 'gateway'}',
            child: GestureDetector(
              onTap: onGatewayTap == null ? null : () => onGatewayTap(gateway),
              child: _GatewayMarker(
                selected:
                    selectedGateway?.idEstudoPonto == gateway.idEstudoPonto,
              ),
            ),
          ),
        ),
    ],
  ),
];

class RecommendationMapLegend extends StatelessWidget {
  const RecommendationMapLegend({super.key, required this.gatewayCount});

  final int gatewayCount;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('gateway-map-legend'),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$gatewayCount ${gatewayCount == 1 ? 'GATEWAY' : 'GATEWAYS'}',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        const _LegendLine(
          color: AppColors.primaryLime,
          label: 'Gateway proposto',
          square: true,
        ),
        const SizedBox(height: 5),
        const _LegendLine(
          color: AppColors.secondaryTeal,
          label: 'Ativo coberto',
        ),
        const SizedBox(height: 5),
        const _LegendLine(
          color: AppColors.layerChaveFusivel,
          label: 'Sem cobertura',
        ),
      ],
    ),
  );
}

class RecommendationZoomHint extends StatelessWidget {
  const RecommendationZoomHint({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pan_tool_alt_outlined, size: 15, color: AppColors.textMuted),
        SizedBox(width: 5),
        Text(
          'Arraste ou use o zoom para inspecionar o raio',
          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _GatewayMarker extends StatelessWidget {
  const _GatewayMarker({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 23 : 19,
      height: selected ? 23 : 19,
      decoration: BoxDecoration(
        color: AppColors.primaryLime,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.textWhite, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLime.withValues(alpha: .75),
            blurRadius: 15,
            spreadRadius: 4,
          ),
        ],
      ),
    ),
  );
}

class _AssetMarker extends StatelessWidget {
  const _AssetMarker({required this.covered});

  final bool covered;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: covered ? AppColors.secondaryTeal : AppColors.layerChaveFusivel,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.surfaceBackground.withValues(alpha: .7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (covered
                        ? AppColors.secondaryTeal
                        : AppColors.layerChaveFusivel)
                    .withValues(alpha: .35),
            blurRadius: 5,
          ),
        ],
      ),
    ),
  );
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({
    required this.color,
    required this.label,
    this.square = false,
  });

  final Color color;
  final String label;
  final bool square;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(2) : null,
        ),
      ),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(color: AppColors.textWhite, fontSize: 10),
      ),
    ],
  );
}
