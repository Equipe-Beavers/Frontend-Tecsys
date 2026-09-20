import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class MapNavigationControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocationPressed;

  const MapNavigationControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          // IconButton(onPressed: onZoomIn, icon: Icon(Icons.add, color: Colors.white, size: 16.0,), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),),
          Container(
            width: 72,
            height: 40,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white10, width: 1),
              ),
            ),
            child: InkWell(
              onTap: onZoomIn,
              child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 20,),
              ),
            ),
          ),
          Container(
            width: 72,
            height: 40,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white10, width: 1),
              ),
            ),
            child: InkWell(
              onTap: onZoomOut,
              child: const Center(
                child: Icon(Icons.remove, color: Colors.white, size: 20),
              ),
            ),
          ),
          Container(
            width: 72,
            height: 40,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white10, width: 1),
              ),
            ),
            child: InkWell(
              onTap: onLocationPressed,
              child: const Center(
                child: Icon(Icons.my_location, color: AppColors.widgetColor, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
