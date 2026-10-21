import 'package:flutter/material.dart';

import '../../models/recomendacao_resultado.dart';
import '../../theme/app_colors.dart';

class GatewayRecommendationCard extends StatelessWidget {
  const GatewayRecommendationCard({
    super.key,
    required this.gateway,
    required this.onTap,
  });

  final GatewayProposto gateway;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('gateway-card-${gateway.idEstudoPonto}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  gateway.rotulo ?? 'Gateway ${gateway.idEstudoPonto}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (gateway.idAtivoBdgd != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gateway.idAtivoBdgd!,
                      style: const TextStyle(
                        color: AppColors.secondaryTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                      size: 17,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          _AttributeLine(
            label: 'Coordenadas',
            value:
                '${gateway.latitude.toStringAsFixed(4)}, ${gateway.longitude.toStringAsFixed(4)}',
          ),
          if (gateway.descricaoAtivo != null)
            _AttributeLine(
              label: 'Ativo elétrico',
              value: gateway.descricaoAtivo!,
            ),
          if (gateway.alimentador != null)
            _AttributeLine(label: 'Alimentador', value: gateway.alimentador!),
          _AttributeLine(
            label: 'Atende',
            value: '${gateway.quantidadeAtendidos} ativo(s)',
          ),
        ],
      ),
    ),
  );
}

class _AttributeLine extends StatelessWidget {
  const _AttributeLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
