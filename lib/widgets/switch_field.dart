import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SwitchField extends StatelessWidget {
  const SwitchField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceCardLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 12),
        SizedBox(
          height: 32,
          child: Switch(
            value: value,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            thumbColor: const WidgetStatePropertyAll(
              AppColors.surfaceBackground,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.primaryLime
                  : const Color(0xFF34534C),
            ),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}
