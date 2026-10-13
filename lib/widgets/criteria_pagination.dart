import 'package:flutter/material.dart';

import '../controllers/criteria_page_controller.dart';
import '../theme/app_colors.dart';

class CriteriaPagination extends StatelessWidget {
  const CriteriaPagination({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final CriteriaPageController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    if (controller.page == 1 && !controller.hasNext) {
      return const SizedBox.shrink();
    }
    final active = enabled && !controller.loading;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Página anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: active && controller.page > 1
                ? () => controller.load(targetPage: controller.page - 1)
                : null,
          ),
          Flexible(
            child: Text(
              'Página ${controller.page}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          IconButton(
            tooltip: 'Próxima página',
            icon: const Icon(Icons.chevron_right),
            onPressed: active && controller.hasNext
                ? () => controller.load(targetPage: controller.page + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
