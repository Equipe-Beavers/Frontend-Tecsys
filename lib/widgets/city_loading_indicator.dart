import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CityLoadingIndicator extends StatelessWidget {
  const CityLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 200,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryLime,
            semanticsLabel: 'Carregando cidades',
          ),
          SizedBox(height: 16),
          Text(
            'Carregando cidades...',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}
