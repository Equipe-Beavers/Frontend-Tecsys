import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class LayerFilterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final int activeLayersCount;

  const LayerFilterButton({
    super.key,
    required this.onPressed,
    this.activeLayersCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: activeLayersCount > 0,
      label: Text(
        '$activeLayersCount',
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppColors.primaryLime,
      offset: const Offset(-2, 2),
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Camadas e Filtros',
        icon: Icon(
          Icons.layers_outlined,
          color: AppColors.textPrimaryColor,
        ),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.searchBarFieldsBackground,
          fixedSize: const Size(50, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}