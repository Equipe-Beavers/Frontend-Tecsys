import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/exportacao_service.dart';
import '../../services/file_download_service.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_scope.dart';
import 'export_destination_sheet.dart';
import 'export_feedback.dart';
import 'map_snapshot_controller.dart';

/// Botão "Baixar em PDF": pede ao backend o relatório completo do estudo e
/// entrega o arquivo ao dispositivo (download do navegador na web; no celular
/// o usuário escolhe entre a pasta Downloads e outro app, como o Drive).
class ExportResultsButton extends StatefulWidget {
  const ExportResultsButton({
    super.key,
    required this.idEstudo,
    this.idCenario,
    this.snapshotController,
    this.repository,
    this.downloader,
  });

  final int idEstudo;

  /// Cenário exibido na tela, destacado no relatório.
  final int? idCenario;
  final MapSnapshotController? snapshotController;
  final StudyExportRepository? repository;
  final FileDownloader? downloader;

  @override
  State<ExportResultsButton> createState() => _ExportResultsButtonState();
}

class _ExportResultsButtonState extends State<ExportResultsButton> {
  ExportacaoService? _ownedService;
  bool _exportando = false;

  StudyExportRepository get _repository =>
      widget.repository ??
      (_ownedService ??= ExportacaoService(
        client: AuthScope.clientOf(context),
      ));

  FileDownloader get _downloader =>
      widget.downloader ?? const FileSaverDownloader();

  @override
  void dispose() {
    _ownedService?.dispose();
    super.dispose();
  }

  Future<void> _exportar() async {
    if (_exportando) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    var destino = DestinoPdf.celular;
    if (_downloader.podeEnviarParaApps) {
      final escolhido = await mostrarEscolhaDestinoPdf(context);
      if (escolhido == null || !mounted) return;
      destino = escolhido;
    }

    setState(() => _exportando = true);
    try {
      final imagem = await widget.snapshotController?.capture();
      if (!mounted) return;

      final arquivo = await _repository.exportarPdf(
        idEstudo: widget.idEstudo,
        idCenario: widget.idCenario,
        imagemMapa: imagem,
      );
      if (!mounted) return;

      switch (destino) {
        case DestinoPdf.celular:
          await _salvar(messenger, arquivo);
        case DestinoPdf.apps:
          await _enviarParaApps(messenger, arquivo);
      }
    } on ExportacaoException catch (error) {
      if (mounted) _erro(messenger, error.message);
    } on Object catch (error) {
      debugPrint('Falha ao exportar o estudo: $error');
      if (mounted) _erro(messenger, 'Não foi possível gerar o relatório.');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _salvar(
    ScaffoldMessengerState messenger,
    ArquivoExportado arquivo,
  ) async {
    final String? salvoEm;
    try {
      salvoEm = await _downloader.salvarPdf(
        nome: arquivo.nome,
        bytes: arquivo.bytes,
      );
    } on Object catch (error) {
      debugPrint('Falha ao salvar o PDF: $error');
      if (mounted) _erro(messenger, 'Erro ao realizar o download.');
      return;
    }
    if (!mounted) return;

    if (!kIsWeb && (salvoEm == null || salvoEm.isEmpty)) {
      ExportFeedback.info(messenger, 'Download cancelado.');
      return;
    }
    ExportFeedback.sucesso(
      messenger,
      kIsWeb
          ? 'Download de ${arquivo.nome} iniciado.'
          : _downloader.podeEnviarParaApps
          ? 'Relatório salvo na pasta Downloads do celular: ${arquivo.nome}.'
          : 'Relatório salvo: ${arquivo.nome}.',
    );
  }

  Future<void> _enviarParaApps(
    ScaffoldMessengerState messenger,
    ArquivoExportado arquivo,
  ) async {
    final ResultadoCompartilhamento resultado;
    try {
      resultado = await _downloader.enviarPdfParaApps(
        nome: arquivo.nome,
        bytes: arquivo.bytes,
      );
    } on Object catch (error) {
      debugPrint('Falha ao enviar o PDF: $error');
      if (mounted) _erro(messenger, 'Erro ao enviar o relatório.');
      return;
    }
    if (!mounted) return;

    if (resultado == ResultadoCompartilhamento.cancelado) {
      ExportFeedback.info(messenger, 'Envio cancelado.');
      return;
    }
    ExportFeedback.sucesso(
      messenger,
      'Relatório ${arquivo.nome} enviado para o app escolhido.',
    );
  }

  void _erro(ScaffoldMessengerState messenger, String texto) =>
      ExportFeedback.erro(messenger, texto, onTentarNovamente: _exportar);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      key: const ValueKey('export-pdf-button'),
      onPressed: _exportando ? null : _exportar,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryLime,
        foregroundColor: AppColors.textDark,
        disabledBackgroundColor: AppColors.primaryLime.withValues(alpha: .55),
        disabledForegroundColor: AppColors.textDark,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _ConteudoBotao(exportando: _exportando),
    ),
  );
}

class _ConteudoBotao extends StatelessWidget {
  const _ConteudoBotao({required this.exportando});

  final bool exportando;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: exportando
        ? const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Gerando relatório...',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ]
        : const [
            Icon(Icons.download_rounded, size: 18),
            SizedBox(width: 8),
            Text(
              'Baixar em PDF',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
  );
}
