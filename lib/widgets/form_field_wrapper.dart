import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FormFieldWrapper extends StatelessWidget {
  const FormFieldWrapper({
    super.key,
    required this.title,
    required this.child,
    this.titleColor = AppColors.textMuted,
  });
  final String title;
  final Widget child;
  final Color titleColor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.3,
          ).copyWith(color: titleColor),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
