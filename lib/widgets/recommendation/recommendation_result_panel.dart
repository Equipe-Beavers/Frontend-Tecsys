import 'package:flutter/material.dart';

import '../../models/recomendacao_resultado.dart';
import '../../theme/app_colors.dart';
import 'coverage_summary.dart';
import 'gateway_recommendation_card.dart';
import 'recommendation_kpis.dart';

class RecommendationResultPanel extends StatelessWidget {
  const RecommendationResultPanel({
    super.key,
    required this.result,
    required this.onGatewayTap,
    this.subtitle,
    this.scrollable = true,
  });

  final ResultadoRecomendacao result;
  final ValueChanged<GatewayProposto> onGatewayTap;
  final String? subtitle;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: !scrollable,
    primary: scrollable ? null : false,
    physics: scrollable ? null : const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      if (subtitle != null) ...[
        Text(
          subtitle!.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 12),
      ],
      RecommendationKpis(result: result),
      const SizedBox(height: 20),
      CoverageSummaryCard(result: result),
      if (result.porCategoria.isNotEmpty) ...[
        const SizedBox(height: 20),
        CoverageByCategoryCard(categories: result.porCategoria),
      ],
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Gateways propostos',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${result.gateways.length} de ${result.quantidadeGateways}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 10),
      for (final gateway in result.gateways)
        GatewayRecommendationCard(
          gateway: gateway,
          onTap: () => onGatewayTap(gateway),
        ),
    ],
  );
}
