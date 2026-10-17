import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'criterion_components.dart';

class LibraryRecordParameter {
  const LibraryRecordParameter(this.label, {this.warning = false});

  final String label;
  final bool warning;
}

class LibraryRecordAction {
  const LibraryRecordAction({required this.value, required this.label});

  final String value;
  final String label;
}

class LibraryRecordCard extends StatelessWidget {
  const LibraryRecordCard({
    super.key,
    required this.title,
    required this.parameters,
    this.onTap,
    this.enabled = true,
    this.actions = const [],
    this.onAction,
    this.emptyMessage = 'Nenhuma informação adicional definida',
  });

  final String title;
  final List<LibraryRecordParameter> parameters;
  final VoidCallback? onTap;
  final bool enabled;
  final List<LibraryRecordAction> actions;
  final ValueChanged<String>? onAction;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceCardLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actions.isNotEmpty)
                  PopupMenuButton<String>(
                    enabled: enabled,
                    tooltip: 'Ações de $title',
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      for (final action in actions)
                        PopupMenuItem(
                          value: action.value,
                          child: Text(action.label),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (parameters.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 7,
                children: [
                  for (final parameter in parameters)
                    CriterionTag(parameter.label, warning: parameter.warning),
                ],
              )
            else
              Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
