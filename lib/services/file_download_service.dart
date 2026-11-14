import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Resultado de enviar o PDF para outro app (Drive, WhatsApp, e-mail...).
enum ResultadoCompartilhamento { enviado, cancelado }

abstract interface class FileDownloader {
  /// Se o dispositivo deixa escolher entre salvar no aparelho e enviar o PDF
  /// para outro app (Google Drive etc.). Só no celular.
  bool get podeEnviarParaApps;

  Future<String?> salvarPdf({required String nome, required Uint8List bytes});

  Future<ResultadoCompartilhamento> enviarPdfParaApps({
    required String nome,
    required Uint8List bytes,
  });
}

class FileSaverDownloader implements FileDownloader {
  const FileSaverDownloader();

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get podeEnviarParaApps => _android || _ios;

  @override
  Future<String?> salvarPdf({
    required String nome,
    required Uint8List bytes,
  }) async {
    final semExtensao = _semExtensao(nome);

    // Android: grava direto na pasta pública Download/ (MediaStore), sem
    // seletor. Com o seletor "Salvar em…" o app vai para segundo plano e, em
    // aparelhos com pouca memória, o Android encerra o processo junto com os
    // bytes do PDF: o destino escolhido (ex.: Google Drive) ficava com 0 bytes.
    if (_android) {
      return FileSaver.instance.saveToDownloads(
        name: semExtensao,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    }
    // iOS não tem pasta Downloads compartilhada; mantém o seletor.
    if (_ios) {
      return FileSaver.instance.saveAs(
        name: semExtensao,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    }
    return FileSaver.instance.saveFile(
      name: semExtensao,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  /// Abre o menu de compartilhamento do sistema ("Salvar no Drive" etc.).
  /// O share_plus grava o PDF num arquivo temporário antes de abrir o menu,
  /// então o app de destino recebe o arquivo completo mesmo que o Android
  /// encerre este app em segundo plano.
  @override
  Future<ResultadoCompartilhamento> enviarPdfParaApps({
    required String nome,
    required Uint8List bytes,
  }) async {
    final arquivo = '${_semExtensao(nome)}.pdf';
    final resultado = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, name: arquivo, mimeType: 'application/pdf'),
        ],
        fileNameOverrides: [arquivo],
        subject: arquivo,
      ),
    );
    return resultado.status == ShareResultStatus.dismissed
        ? ResultadoCompartilhamento.cancelado
        : ResultadoCompartilhamento.enviado;
  }

  static String _semExtensao(String nome) => nome.toLowerCase().endsWith('.pdf')
      ? nome.substring(0, nome.length - 4)
      : nome;
}
