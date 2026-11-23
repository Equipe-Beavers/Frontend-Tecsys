import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Para onde o PDF exportado vai no celular.
enum DestinoPdf {
  /// Pasta Downloads do aparelho.
  celular,

  /// Menu de compartilhar do sistema (Google Drive, WhatsApp, e-mail...).
  apps,
}

/// Pergunta onde salvar o relatório. Null quando o usuário fecha a escolha.
Future<DestinoPdf?> mostrarEscolhaDestinoPdf(BuildContext context) =>
    showModalBottomSheet<DestinoPdf>(
      context: context,
      backgroundColor: AppColors.surfaceBackground,
      showDragHandle: true,
      builder: (_) => const ExportDestinationSheet(),
    );

class ExportDestinationSheet extends StatelessWidget {
  const ExportDestinationSheet({super.key});

  @override
  Widget build(BuildContext context) => const SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Onde salvar o relatório?',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _DestinoTile(
            key: ValueKey('export-destino-celular'),
            destino: DestinoPdf.celular,
            icone: Icons.phone_android,
            titulo: 'Salvar no celular',
            descricao: 'Pasta Downloads',
          ),
          _DestinoTile(
            key: ValueKey('export-destino-apps'),
            destino: DestinoPdf.apps,
            icone: Icons.share,
            titulo: 'Compartilhar',
            descricao: 'Drive, WhatsApp, e-mail e outros apps',
          ),
        ],
      ),
    ),
  );
}

class _DestinoTile extends StatelessWidget {
  const _DestinoTile({
    super.key,
    required this.destino,
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  final DestinoPdf destino;
  final IconData icone;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icone, color: AppColors.primaryLime),
    title: Text(titulo, style: const TextStyle(color: AppColors.textWhite)),
    subtitle: Text(
      descricao,
      style: const TextStyle(color: AppColors.textMuted),
    ),
    onTap: () => Navigator.pop(context, destino),
  );
}
