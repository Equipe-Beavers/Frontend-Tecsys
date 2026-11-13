import 'package:flutter/material.dart';

import '../../models/recomendacao_resultado.dart';
import '../../theme/app_colors.dart';

class RecommendationKpis extends StatelessWidget {
  const RecommendationKpis({super.key, required this.result});

  final ResultadoRecomendacao result;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _KpiCard(
          label: 'Cobertura',
          value: '${result.percentualCobertura}%',
          valueColor: AppColors.primaryLime,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _KpiCard(
          label: 'Gateways',
          value: '${result.quantidadeGateways}',
          valueColor: AppColors.secondaryTeal,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _KpiCard(
          label: 'Custo Total',
          value: 'R\$ ${_formatValue(result.custoTotalEstimado)}',
          valueColor: AppColors.layerChaveFusivel,
        ),
      ),
    ],
  );

  static String _formatValue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
