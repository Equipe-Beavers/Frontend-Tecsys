import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

enum StudyDatabaseSource { system, importFile }

class StudyDatabaseBottomSheet extends StatefulWidget {
  const StudyDatabaseBottomSheet({
    super.key,
    required this.distributorCount,
    required this.databaseYear,
  });

  final int distributorCount;
  final int databaseYear;

  static Future<StudyDatabaseSource?> show({
    required BuildContext context,
    required int distributorCount,
    required int databaseYear,
  }) {
    return showModalBottomSheet<StudyDatabaseSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StudyDatabaseBottomSheet(
        distributorCount: distributorCount,
        databaseYear: databaseYear,
      ),
    );
  }

  @override
  State<StudyDatabaseBottomSheet> createState() =>
      _StudyDatabaseBottomSheetState();
}

class _StudyDatabaseBottomSheetState extends State<StudyDatabaseBottomSheet> {
  StudyDatabaseSource _selectedSource = StudyDatabaseSource.system;

  void _continue() => Navigator.of(context).pop(_selectedSource);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'INICIAR ESTUDO',
              style: TextStyle(
                color: AppColors.primaryLime,
                fontSize: 13,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Base de dados',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 22),
            _DatabaseOption(
              title: 'Dados BDGD ${widget.databaseYear}',
              subtitle: '${widget.distributorCount} distribuidoras disponíveis',
              selected: _selectedSource == StudyDatabaseSource.system,
              onTap: () =>
                  setState(() => _selectedSource = StudyDatabaseSource.system),
            ),
            const SizedBox(height: 12),
            _DatabaseOption(
              title: 'Importar minha própria base',
              subtitle: 'Envie um arquivo BDGD .gdb.zip',
              selected: _selectedSource == StudyDatabaseSource.importFile,
              onTap: () => setState(
                () => _selectedSource = StudyDatabaseSource.importFile,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLime,
                  foregroundColor: AppColors.textDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Prosseguir',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatabaseOption extends StatelessWidget {
  const _DatabaseOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.primaryLime.withValues(alpha: 0.6)
        : AppColors.border;

    return Material(
      color: selected
          ? AppColors.coverageArea.withValues(alpha: 0.6)
          : AppColors.surfaceBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primaryLime : AppColors.textMuted,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
