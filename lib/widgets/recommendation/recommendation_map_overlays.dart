import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

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
          'Arraste ou use o zoom para inspecionar a cobertura',
          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
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
