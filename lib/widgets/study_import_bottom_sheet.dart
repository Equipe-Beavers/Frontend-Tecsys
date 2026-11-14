import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class StudyImportBottomSheet extends StatefulWidget {
  const StudyImportBottomSheet({super.key, required this.onImport});

  final Future<DistribuidoraResumo> Function(
    String versaoBdgd,
    String nomeArquivo,
    Uint8List arquivo,
  )
  onImport;

  static Future<DistribuidoraResumo?> show({
    required BuildContext context,
    required Future<DistribuidoraResumo> Function(
      String versaoBdgd,
      String nomeArquivo,
      Uint8List arquivo,
    )
    onImport,
  }) {
    return showModalBottomSheet<DistribuidoraResumo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StudyImportBottomSheet(onImport: onImport),
    );
  }

  @override
  State<StudyImportBottomSheet> createState() => _StudyImportBottomSheetState();
}

class _StudyImportBottomSheetState extends State<StudyImportBottomSheet> {
  final TextEditingController _versionController = TextEditingController();
  PlatformFile? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _errorMessage;
  bool _isImporting = false;

  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    setState(() => _errorMessage = null);
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (!mounted || file == null) return;
    if (!file.name.toLowerCase().endsWith('.gdb.zip')) {
      setState(() {
        _errorMessage = 'O arquivo deve estar no formato .gdb.zip.';
        _selectedFile = null;
        _selectedFileBytes = null;
      });
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedFile = file;
        _selectedFileBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível ler o arquivo selecionado: $error';
        _selectedFile = null;
        _selectedFileBytes = null;
      });
    }
  }

  Future<void> _import() async {
    final file = _selectedFile;
    final fileBytes = _selectedFileBytes;
    final version = _versionController.text.trim();
    if (version.isEmpty) {
      setState(() => _errorMessage = 'Informe a versão da BDGD.');
      return;
    }
    if (file == null || fileBytes == null) {
      setState(() => _errorMessage = 'Selecione um arquivo .gdb.zip.');
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });
    try {
      final distributor = await widget.onImport(version, file.name, fileBytes);
      if (mounted) Navigator.of(context).pop(distributor);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _errorMessage = 'Não foi possível importar o arquivo: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
        child: SingleChildScrollView(
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
              const SizedBox(height: 24),
              const Text(
                'Importar base BDGD',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _versionController,
                enabled: !_isImporting,
                style: const TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(
                  labelText: 'Versão da BDGD',
                  hintText: 'Ex.: 2026',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedFile == null)
                Material(
                  color: AppColors.surfaceBackground,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _isImporting ? null : _selectFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.textMuted,
                          width: 1.2,
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: AppColors.textWhite,
                            size: 34,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Toque para selecionar o arquivo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Apenas um arquivo .gdb.zip',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.archive_outlined,
                        color: AppColors.secondaryTeal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedFile!.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textWhite),
                        ),
                      ),
                      IconButton(
                        onPressed: _isImporting
                            ? null
                            : () => setState(() {
                                _selectedFile = null;
                                _selectedFileBytes = null;
                              }),
                        tooltip: 'Remover arquivo',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isImporting ? null : _import,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLime,
                    foregroundColor: AppColors.textDark,
                    disabledBackgroundColor: AppColors.primaryLime.withValues(
                      alpha: 0.55,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isImporting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textDark,
                            ),
                          ),
                        )
                      : const Text(
                          'Importar arquivo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
