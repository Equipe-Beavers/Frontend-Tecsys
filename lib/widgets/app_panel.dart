import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceCardLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}
