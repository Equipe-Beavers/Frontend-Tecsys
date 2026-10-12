import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textMuted,
      side: const BorderSide(color: AppColors.borderSubtle),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}
