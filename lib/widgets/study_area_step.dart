import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StudyAreaStep extends StatelessWidget {
  const StudyAreaStep({
    super.key,
    required this.locationLabel,
    required this.areaDesenhada,
    required this.areaKm2,
    required this.ativosNaArea,
    required this.onCancelar,
    required this.onRefazer,
    required this.onProsseguir,
  });

  final String locationLabel;
  final bool areaDesenhada;
  final double areaKm2;
  final int ativosNaArea;
  final VoidCallback onCancelar;
  final VoidCallback onRefazer;
  final VoidCallback onProsseguir;

  String _formatArea(double area) =>
      area.toStringAsFixed(1).replaceAll('.', ',');

  String _formatCount(int count) => count.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: AppColors.navBarBackground,
            padding: EdgeInsets.fromLTRB(18, safeTop + 8, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onCancelar,
                  tooltip: 'Voltar',
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.textWhite,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'INICIAR ESTUDO',
                        style: TextStyle(
                          color: AppColors.primaryLime,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Selecionar área',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (locationLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTeal,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'PASSO 3 DE 4',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (areaDesenhada)
          Positioned(
            left: 16,
            right: 16,
            bottom: safeBottom + 112,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Área selecionada',
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onRefazer,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondaryTeal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Refazer',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _AreaMetric(
                          label: 'ÁREA',
                          value: '${_formatArea(areaKm2)} km²',
                        ),
                      ),
                      Expanded(
                        child: _AreaMetric(
                          label: 'ATIVOS NA ÁREA',
                          value: _formatCount(ativosNaArea),
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: AppColors.navBarBackground,
            padding: EdgeInsets.fromLTRB(18, 15, 18, safeBottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancelar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textWhite,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 19),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (areaDesenhada) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onProsseguir,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLime,
                        foregroundColor: AppColors.textDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 19),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Prosseguir',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AreaMetric extends StatelessWidget {
  const _AreaMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.primaryLime : AppColors.textWhite,
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
