import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class MapSearchBar extends StatelessWidget {
  const MapSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: MediaQuery.of(context).size.width * 0.75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.searchBarFieldsBackground,
      ),
      child: Center(
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            hintText: 'Buscar ativo ou município',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 16,
              fontWeight: FontWeight.w200,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.widgetColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
