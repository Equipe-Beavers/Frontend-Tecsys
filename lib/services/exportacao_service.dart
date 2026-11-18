import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ArquivoExportado {
  const ArquivoExportado({required this.nome, required this.bytes});

  final String nome;
  final Uint8List bytes;
}

class ExportacaoException implements Exception {
  const ExportacaoException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

abstract interface class StudyExportRepository {
  /// Solicita o relatório completo do estudo (todos os cenários e o
  /// comparativo, montados pelo backend). [idCenario] só indica o cenário em
  /// destaque, e [imagemMapa] é o mapa desse cenário como aparece na tela.
  Future<ArquivoExportado> exportarPdf({
    required int idEstudo,
    int? idCenario,
    Uint8List? imagemMapa,
  });
}

/// Integração com `POST /estudos/:id/exportar-pdf`
/// (contrato em Backend-Tecsys/docs/exportacao-pdf-contrato.md).
class ExportacaoService implements StudyExportRepository {
  ExportacaoService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = ApiConfig.resolve(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<ArquivoExportado> exportarPdf({
    required int idEstudo,
    int? idCenario,
    Uint8List? imagemMapa,
  }) async {
    if (idEstudo < 1) {
      throw const ExportacaoException('Estudo não encontrado.');
    }

    // `incluir_alternativas` não é enviado: o padrão do backend já traz todos
    // os cenários do estudo e o comparativo.
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/estudos/$idEstudo/exportar-pdf'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/pdf',
            },
            body: jsonEncode({
              'id_cenario': ?idCenario,
              if (imagemMapa != null && imagemMapa.isNotEmpty)
                'imagem_mapa': base64Encode(imagemMapa),
            }),
          )
          .timeout(const Duration(seconds: 120));
    } on Exception {
      throw const ExportacaoException('Falha na comunicação com o servidor.');
    }

    if (response.statusCode != 200) {
      throw ExportacaoException(
        mensagemDeErro(response.statusCode, response.body),
        status: response.statusCode,
      );
    }
    if (!_ehPdf(response.bodyBytes)) {
      throw const ExportacaoException(
        'O servidor devolveu um arquivo inválido. Tente novamente.',
      );
    }

    return ArquivoExportado(
      nome:
          nomeDoArquivo(response.headers['content-disposition']) ??
          'relatorio-estudo-$idEstudo.pdf',
      bytes: response.bodyBytes,
    );
  }

  static bool _ehPdf(Uint8List bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F

  static String? nomeDoArquivo(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final match = RegExp(
      r'''filename\*?=(?:UTF-8'')?"?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    final nome = match?.group(1)?.trim();
    if (nome == null || nome.isEmpty) return null;
    // Evita caminhos vindos do servidor; só o nome do arquivo é usado.
    final semCaminho = Uri.decodeComponent(nome).split(RegExp(r'[\\/]')).last;
    return semCaminho.isEmpty ? null : semCaminho;
  }

  static String mensagemDeErro(int status, String body) {
    switch (status) {
      case 401:
        return 'Sua sessão expirou. Entre novamente para exportar.';
      case 403:
        return 'Você não possui permissão para exportar este estudo.';
      case 413:
        return 'O mapa ficou grande demais para o envio. Tente novamente.';
      case >= 500:
        return 'Não foi possível gerar o relatório. Tente novamente.';
    }
    // 400, 404 e 409 trazem mensagens próprias para o usuário.
    final doBackend = _mensagemDoBackend(body);
    if (doBackend != null) return doBackend;
    return switch (status) {
      404 => 'Estudo não encontrado.',
      409 => 'O estudo ainda não possui resultados processados para exportar.',
      _ => 'Não foi possível gerar o relatório.',
    };
  }

  static String? _mensagemDoBackend(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  void dispose() => _client.close();
}
