import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CriterionTag extends StatelessWidget {
  const CriterionTag(this.label, {super.key, this.warning = false});
  final String label;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: (warning ? Colors.orange : AppColors.secondaryTeal).withValues(
        alpha: .10,
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: warning ? Colors.orange.shade300 : AppColors.secondaryTeal,
      ),
    ),
  );
}
