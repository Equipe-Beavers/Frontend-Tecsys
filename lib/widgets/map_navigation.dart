import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class MapNavigationControls extends StatelessWidget {
  const MapNavigationControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    decoration: BoxDecoration(
      color: AppColors.backgroundColor,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Aproximar',
          onPressed: onZoomIn,
          icon: const Icon(Icons.add, color: Colors.white),
        ),
        const Divider(height: 1, color: Colors.white10),
        IconButton(
          tooltip: 'Afastar',
          onPressed: onZoomOut,
          icon: const Icon(Icons.remove, color: Colors.white),
        ),
      ],
    ),
  );
}
