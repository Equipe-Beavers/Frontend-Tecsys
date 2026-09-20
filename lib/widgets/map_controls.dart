import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocation;
  final VoidCallback onAbrirCamadas;
  final int totalCamadasAtivas;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocation,
    required this.onAbrirCamadas,
    this.totalCamadasAtivas = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botão de Camadas com Badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildBotaoControle(
              icon: Icons.layers_outlined,
              onPressed: onAbrirCamadas,
              tooltip: 'Camadas e Filtros',
              iconColor: AppColors.primaryLime,
            ),
            if (totalCamadasAtivas > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLime,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      '$totalCamadasAtivas',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Bloco de Zoom In / Zoom Out
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildItemInterno(
                icon: Icons.add,
                onPressed: onZoomIn,
                tooltip: 'Aproximar',
              ),
              Container(
                height: 1,
                width: 32,
                color: AppColors.borderSubtle,
              ),
              _buildItemInterno(
                icon: Icons.remove,
                onPressed: onZoomOut,
                tooltip: 'Afastar',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Botão Centralizar / Minha Localização
        _buildBotaoControle(
          icon: Icons.my_location,
          onPressed: onLocation,
          tooltip: 'Centralizar na rede',
        ),
      ],
    );
  }

  Widget _buildBotaoControle({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color iconColor = AppColors.textWhite,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemInterno({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 40,
            child: Icon(icon, color: AppColors.textWhite, size: 20),
          ),
        ),
      ),
    );
  }
}

