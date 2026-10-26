import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NameFilterField extends StatelessWidget {
  const NameFilterField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Buscar pelo nome',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.secondaryTeal,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            filled: true,
            fillColor: AppColors.surfaceBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.secondaryTeal),
            ),
          ),
        ),
      );
}
