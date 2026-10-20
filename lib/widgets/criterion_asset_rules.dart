import 'package:flutter/material.dart';

import '../models/install_criterion.dart';
import '../models/layer_filter.dart';
import '../theme/app_colors.dart';

/// A neutral type belongs to neither persisted list.
class CriterionAssetRules extends StatelessWidget {
  const CriterionAssetRules({
    super.key,
    required this.allowed,
    required this.blocked,
    required this.onChanged,
    this.enabled = true,
    this.hasLegacyStructure = false,
  });

  final List<String> allowed;
  final List<String> blocked;
  final bool enabled;
  final bool hasLegacyStructure;
  final void Function(List<String>, List<String>) onChanged;

  @override
  Widget build(BuildContext context) {
    final obsolete = {
      ...allowed,
      ...blocked,
    }.where((type) => !criterionAssetTypes.containsKey(type)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecione o critério desejado para cada tipo de ativo. '
          'Deixe em "Neutro" caso não haja regra definida.',
          style: TextStyle(color: Color(0xFFABC2BC), fontSize: 13, height: 1.5),
        ),
        if (obsolete.isNotEmpty || hasLegacyStructure) ...[
          const SizedBox(height: 12),
          Text(
            'Este critério contém regras antigas fora do catálogo atual'
            '${obsolete.isEmpty ? '.' : ': ${obsolete.join(', ')}.'} '
            'Remova essas regras para usar a nova seleção.',
            style: const TextStyle(color: Colors.orange),
          ),
          TextButton(
            onPressed: enabled
                ? () => onChanged(
                    allowed.where(criterionAssetTypes.containsKey).toList(),
                    blocked.where(criterionAssetTypes.containsKey).toList(),
                  )
                : null,
            child: const Text('Remover regras antigas'),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 580;
            return Column(
              children: [
                if (!compact)
                  const Row(
                    children: [
                      Expanded(child: Text('Ativo')),
                      SizedBox(width: 330, child: Text('Status')),
                    ],
                  ),
                for (final group in CatalogoCamadas.obterGrupos()) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        group.titulo,
                        style: const TextStyle(
                          color: Color(0xFFABC2BC),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  for (final item in group.itens) ...[
                    Builder(
                      builder: (context) {
                        // Stable rule IDs are independent of the visual segment order.
                        final status = allowed.contains(item.tipo.criterionKey)
                            ? 0
                            : blocked.contains(item.tipo.criterionKey)
                            ? 1
                            : 2;
                        final controls = SegmentedButton<int>(
                          key: ValueKey('asset-rule-${item.tipo.criterionKey}'),
                          showSelectedIcon: true,
                          selectedIcon: Icon(
                            status == 0
                                ? Icons.check
                                : status == 1
                                ? Icons.block
                                : Icons.remove,
                            size: 14,
                          ),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.standard,
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                            minimumSize: const WidgetStatePropertyAll(
                              Size(0, 44),
                            ),
                            textStyle: const WidgetStatePropertyAll(
                              TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (!states.contains(WidgetState.selected)) {
                                return AppColors.surfaceCard;
                              }
                              return [
                                AppColors.secondaryTeal,
                                Colors.orange.withValues(alpha: .12),
                                AppColors.surfaceInput,
                              ][status];
                            }),
                            side: WidgetStateProperty.resolveWith(
                              (states) => BorderSide(
                                color: states.contains(WidgetState.selected)
                                    ? [
                                        AppColors.secondaryTeal,
                                        Colors.orange.withValues(alpha: .55),
                                        AppColors.border,
                                      ][status]
                                    : AppColors.border,
                              ),
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.disabled)
                                  ? const Color(0xFFABC2BC)
                                  : states.contains(WidgetState.selected)
                                  ? [
                                      AppColors.textDark,
                                      Colors.orange.shade300,
                                      AppColors.textWhite,
                                    ][status]
                                  : const Color(0xFFABC2BC),
                            ),
                          ),
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text(
                                'Permitido',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text(
                                'Bloqueado',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            ButtonSegment(
                              value: 2,
                              label: Text(
                                'Neutro',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ],
                          selected: {status},
                          onSelectionChanged:
                              !enabled ||
                                  obsolete.isNotEmpty ||
                                  hasLegacyStructure
                              ? null
                              : (selection) {
                                  final nextAllowed = allowed
                                      .where(
                                        (type) =>
                                            type != item.tipo.criterionKey,
                                      )
                                      .toList();
                                  final nextBlocked = blocked
                                      .where(
                                        (type) =>
                                            type != item.tipo.criterionKey,
                                      )
                                      .toList();
                                  if (selection.single == 0) {
                                    nextAllowed.add(item.tipo.criterionKey);
                                  }
                                  if (selection.single == 1) {
                                    nextBlocked.add(item.tipo.criterionKey);
                                  }
                                  onChanged(nextAllowed, nextBlocked);
                                },
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: compact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.titulo),
                                    const SizedBox(height: 8),
                                    controls,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: Text(item.titulo)),
                                    const SizedBox(width: 16),
                                    SizedBox(width: 330, child: controls),
                                  ],
                                ),
                        );
                      },
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
