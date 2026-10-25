import 'package:flutter/material.dart';

import '../../models/ativo_bdgd.dart';
import '../../models/recomendacao_resultado.dart';
import '../../theme/app_colors.dart';

class CoverageSummaryCard extends StatelessWidget {
  const CoverageSummaryCard({super.key, required this.result});

  final ResultadoRecomendacao result;

  @override
  Widget build(BuildContext context) {
    final progress = result.pontosInteresse > 0
        ? result.pontosCobertos / result.pontosInteresse
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Ativos elétricos cobertos',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${result.pontosCobertos} de ${result.pontosInteresse}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryLime),
            ),
          ),
        ],
      ),
    );
  }
}

class CoverageByCategoryCard extends StatelessWidget {
  const CoverageByCategoryCard({super.key, required this.categories});

  final List<CategoriaCobertura> categories;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    decoration: _cardDecoration,
    child: Column(
      children: [
        for (int index = 0; index < categories.length; index++)
          _CategoryLine(
            category: categories[index],
            showDivider: index != categories.length - 1,
          ),
      ],
    ),
  );
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({required this.category, required this.showDivider});

  final CategoriaCobertura category;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(category.tipo.icone, color: category.tipo.cor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.tipo.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${category.cobertos}',
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (category.naoCobertos > 0)
                      TextSpan(
                        text: ' / ${category.naoCobertos} sem cobertura',
                        style: const TextStyle(
                          color: AppColors.layerChaveFusivel,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      if (showDivider) const Divider(color: AppColors.borderSubtle, height: 1),
    ],
  );
}

final _cardDecoration = BoxDecoration(
  color: AppColors.surfaceCard,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: AppColors.border),
);
