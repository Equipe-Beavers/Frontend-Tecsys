import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum _TipoAviso { sucesso, info, erro }

/// Avisos (snackbars) do fluxo de exportação do relatório.
abstract final class ExportFeedback {
  static void sucesso(ScaffoldMessengerState messenger, String texto) =>
      messenger.showSnackBar(_aviso(_TipoAviso.sucesso, texto));

  static void info(ScaffoldMessengerState messenger, String texto) =>
      messenger.showSnackBar(_aviso(_TipoAviso.info, texto));

  /// Erro com ação "Tentar novamente".
  static void erro(
    ScaffoldMessengerState messenger,
    String texto, {
    required VoidCallback onTentarNovamente,
  }) => messenger.showSnackBar(
    _aviso(_TipoAviso.erro, texto, onTentarNovamente: onTentarNovamente),
  );

  static SnackBar _aviso(
    _TipoAviso tipo,
    String texto, {
    VoidCallback? onTentarNovamente,
  }) {
    final (fundo, icone, corIcone) = switch (tipo) {
      _TipoAviso.sucesso => (
        AppColors.badgeSuccessBg,
        Icons.check_circle_outline,
        AppColors.primaryLime,
      ),
      _TipoAviso.info => (
        AppColors.surfaceCardLight,
        Icons.info_outline,
        AppColors.textMuted,
      ),
      _TipoAviso.erro => (
        AppColors.errorBackground,
        Icons.error_outline,
        AppColors.errorText,
      ),
    };
    return SnackBar(
      key: const ValueKey('export-feedback'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: fundo,
      duration: tipo == _TipoAviso.erro
          ? const Duration(seconds: 6)
          : const Duration(milliseconds: 4000),
      content: Row(
        children: [
          Icon(icone, color: corIcone, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: AppColors.textWhite),
            ),
          ),
        ],
      ),
      action: onTentarNovamente == null
          ? null
          : SnackBarAction(
              label: 'Tentar novamente',
              textColor: AppColors.primaryLime,
              onPressed: onTentarNovamente,
            ),
    );
  }
}
