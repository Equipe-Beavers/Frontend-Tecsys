import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/pages/recomendacao_resultado_page.dart';
import 'package:frontend_tecsys/services/exportacao_service.dart';
import 'package:frontend_tecsys/services/file_download_service.dart';
import 'package:frontend_tecsys/widgets/recommendation/map_snapshot_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.3 teste'));

ExportacaoService _service(MockClientHandler handler) =>
    ExportacaoService(baseUrl: 'http://api.test/', client: MockClient(handler));

Matcher _falha({int? status, required String mensagem}) => throwsA(
  isA<ExportacaoException>()
      .having((e) => e.status, 'status', status)
      .having((e) => e.message, 'message', mensagem),
);

void main() {
  group('ExportacaoService', () {
    test(
      'pede o relatório completo do estudo com o cenário e o mapa exibidos',
      () async {
        late http.Request enviado;
        final service = _service((request) async {
          enviado = request;
          return http.Response.bytes(
            _pdf,
            200,
            headers: {
              'content-type': 'application/pdf',
              'content-disposition':
                  'attachment; filename="relatorio-estudo-27-centro.pdf"',
            },
          );
        });

        final arquivo = await service.exportarPdf(
          idEstudo: 27,
          idCenario: 104,
          imagemMapa: Uint8List.fromList([1, 2, 3]),
        );

        expect(enviado.method, 'POST');
        expect(
          enviado.url.toString(),
          'http://api.test/estudos/27/exportar-pdf',
        );
        expect(enviado.headers['Content-Type'], contains('application/json'));
        // Sem `incluir_alternativas`: o backend inclui todos os cenários.
        expect(jsonDecode(enviado.body), {
          'id_cenario': 104,
          'imagem_mapa': base64Encode([1, 2, 3]),
        });
        expect(arquivo.nome, 'relatorio-estudo-27-centro.pdf');
        expect(arquivo.bytes, _pdf);
      },
    );

    test('sem mapa capturado envia só o cenário e usa o nome padrão', () async {
      late http.Request enviado;
      final service = _service((request) async {
        enviado = request;
        return http.Response.bytes(_pdf, 200);
      });

      final arquivo = await service.exportarPdf(idEstudo: 3, idCenario: 9);

      expect(jsonDecode(enviado.body), {'id_cenario': 9});
      expect(arquivo.nome, 'relatorio-estudo-3.pdf');
    });

    test('estudo sem resultados (409) mostra a mensagem do backend', () {
      final service = _service(
        (_) async => http.Response(
          jsonEncode({
            'message': 'O estudo ainda não possui resultados processados para exportar.',
          }),
          409,
        ),
      );

      expect(
        service.exportarPdf(idEstudo: 3),
        _falha(
          status: 409,
          mensagem:
              'O estudo ainda não possui resultados processados para exportar.',
        ),
      );
    });

    test('estudo inexistente (404) informa que não foi encontrado', () {
      final service = _service((_) async => http.Response('', 404));

      expect(
        service.exportarPdf(idEstudo: 999),
        _falha(status: 404, mensagem: 'Estudo não encontrado.'),
      );
    });

    test('identificador inválido não chega ao servidor', () {
      var chamadas = 0;
      final service = _service((_) async {
        chamadas++;
        return http.Response.bytes(_pdf, 200);
      });

      expect(
        service.exportarPdf(idEstudo: 0),
        _falha(mensagem: 'Estudo não encontrado.'),
      );
      expect(chamadas, 0);
    });

    test('sessão expirada (401) pede novo login', () {
      final service = _service((_) async => http.Response('', 401));

      expect(
        service.exportarPdf(idEstudo: 3),
        _falha(
          status: 401,
          mensagem: 'Sua sessão expirou. Entre novamente para exportar.',
        ),
      );
    });

    test('sem permissão (403) informa o usuário', () {
      final service = _service((_) async => http.Response('', 403));

      expect(
        service.exportarPdf(idEstudo: 3),
        _falha(
          status: 403,
          mensagem: 'Você não possui permissão para exportar este estudo.',
        ),
      );
    });

    test('erro do servidor (500) não expõe detalhes técnicos', () {
      final service = _service(
        (_) async => http.Response(
          jsonEncode({'message': 'TypeError: cannot read x of undefined'}),
          500,
        ),
      );

      expect(
        service.exportarPdf(idEstudo: 3),
        _falha(
          status: 500,
          mensagem: 'Não foi possível gerar o relatório. Tente novamente.',
        ),
      );
    });

    test('falha de conexão vira mensagem de comunicação', () {
      final service = _service(
        (_) async => throw http.ClientException('Connection refused'),
      );

      expect(
        service.exportarPdf(idEstudo: 3),
        _falha(mensagem: 'Falha na comunicação com o servidor.'),
      );
    });

    test('recusa arquivo vazio ou que não é PDF', () async {
      for (final corpo in [<int>[], utf8.encode('<html>erro</html>')]) {
        final service = _service((_) async => http.Response.bytes(corpo, 200));
        await expectLater(
          service.exportarPdf(idEstudo: 3),
          _falha(
            mensagem:
                'O servidor devolveu um arquivo inválido. Tente novamente.',
          ),
        );
      }
    });

    test('lê o nome do arquivo do Content-Disposition', () {
      expect(
        ExportacaoService.nomeDoArquivo('attachment; filename="a b.pdf"'),
        'a b.pdf',
      );
      expect(
        ExportacaoService.nomeDoArquivo(
          "attachment; filename*=UTF-8''estudo%20s%C3%A3o.pdf",
        ),
        'estudo são.pdf',
      );
      expect(
        ExportacaoService.nomeDoArquivo('attachment; filename="../x/r.pdf"'),
        'r.pdf',
      );
      expect(ExportacaoService.nomeDoArquivo(null), isNull);
    });
  });

  group('MapSnapshotController', () {
    test('devolve null quando o mapa ainda não está pronto', () async {
      expect(await MapSnapshotController().capture(), isNull);
    });

    test('devolve a imagem do mapa e ignora falhas na captura', () async {
      final controller = MapSnapshotController();
      Future<Uint8List> ok() async => Uint8List.fromList([9]);
      Future<Uint8List> falha() async => throw StateError('sem mapa');

      controller.attach(ok);
      expect(await controller.capture(), [9]);

      controller.attach(falha);
      expect(await controller.capture(), isNull);

      controller.detach(falha);
      expect(controller.isAttached, isFalse);
    });

    test('desconecta pelo tear-off do método, como o mapa faz', () {
      final controller = MapSnapshotController();
      final mapa = _MapaFalso();

      controller.attach(mapa.snapshot);
      controller.detach(mapa.snapshot);
      expect(controller.isAttached, isFalse);

      // Outro mapa não desconecta o que está ativo.
      controller.attach(mapa.snapshot);
      controller.detach(_MapaFalso().snapshot);
      expect(controller.isAttached, isTrue);
    });
  });

  group('Botão Baixar em PDF', () {
    Future<void> abrirTela(
      WidgetTester tester, {
      required _FakeExportRepository repository,
      required _FakeDownloader downloader,
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: RecomendacaoResultadoPage(
            idEstudo: 27,
            idPerfilRf: 8,
            resultadoInicial: buildRecommendationMock(),
            showBaseMap: false,
            exportRepository: repository,
            fileDownloader: downloader,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final botao = find.byKey(const ValueKey('export-pdf-button'));

    testWidgets(
      'um clique pede o relatório, mostra carregamento e baixa o arquivo',
      (tester) async {
        final repository = _FakeExportRepository();
        final downloader = _FakeDownloader();
        await abrirTela(tester, repository: repository, downloader: downloader);

        expect(find.text('Baixar em PDF'), findsOneWidget);
        await tester.tap(botao);
        await tester.pump();

        // Sem popup: a exportação começa direto.
        expect(find.text('Gerando relatório...'), findsOneWidget);
        expect(tester.widget<FilledButton>(botao).onPressed, isNull);

        // Cliques repetidos durante a geração não disparam novos pedidos.
        await tester.tap(botao, warnIfMissed: false);
        await tester.pump();
        expect(repository.chamadas, 1);

        repository.concluir();
        await tester.pumpAndSettle();

        expect(repository.idEstudo, 27);
        expect(repository.idCenario, buildRecommendationMock().idCenario);
        expect(downloader.nome, 'relatorio-estudo-27.pdf');
        expect(downloader.bytes, _pdf);
        expect(
          find.text('Relatório salvo: relatorio-estudo-27.pdf.'),
          findsOneWidget,
        );
        expect(find.text('Baixar em PDF'), findsOneWidget);
        expect(tester.widget<FilledButton>(botao).onPressed, isNotNull);
      },
    );

    testWidgets('mostra o erro e permite tentar novamente', (tester) async {
      final repository = _FakeExportRepository(
        erro: const ExportacaoException('Estudo não encontrado.', status: 404),
      );
      final downloader = _FakeDownloader();
      await abrirTela(
        tester,
        repository: repository,
        downloader: downloader,
        size: const Size(1440, 900),
      );

      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(find.text('Estudo não encontrado.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(downloader.nome, isNull);
      expect(repository.chamadas, 1);
      expect(find.text('Baixar em PDF'), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(repository.chamadas, 2);
    });

    testWidgets('falha ao salvar não mostra sucesso', (tester) async {
      final repository = _FakeExportRepository()..concluir();
      await abrirTela(
        tester,
        repository: repository,
        downloader: _FakeDownloader(falhar: true),
      );

      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(find.text('Erro ao realizar o download.'), findsOneWidget);
      expect(find.textContaining('Relatório salvo'), findsNothing);
      expect(find.text('Baixar em PDF'), findsOneWidget);
    });

    testWidgets('download cancelado pelo usuário não mostra sucesso', (
      tester,
    ) async {
      final repository = _FakeExportRepository()..concluir();
      await abrirTela(
        tester,
        repository: repository,
        downloader: _FakeDownloader(cancelar: true),
      );

      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(find.text('Download cancelado.'), findsOneWidget);
      expect(find.textContaining('Relatório salvo'), findsNothing);
    });

    group('no celular', () {
      final celular = find.byKey(const ValueKey('export-destino-celular'));
      final apps = find.byKey(const ValueKey('export-destino-apps'));

      testWidgets('pergunta o destino e salva na pasta Downloads', (
        tester,
      ) async {
        final repository = _FakeExportRepository()..concluir();
        final downloader = _FakeDownloader(celular: true);
        await abrirTela(tester, repository: repository, downloader: downloader);

        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(find.text('Onde salvar o relatório?'), findsOneWidget);
        expect(repository.chamadas, 0);

        await tester.tap(celular);
        await tester.pumpAndSettle();

        expect(repository.chamadas, 1);
        expect(downloader.nome, 'relatorio-estudo-27.pdf');
        expect(downloader.enviadoParaApps, isNull);
        expect(
          find.text(
            'Relatório salvo na pasta Downloads do celular: '
            'relatorio-estudo-27.pdf.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('compartilha o PDF com o app escolhido', (
        tester,
      ) async {
        final repository = _FakeExportRepository()..concluir();
        final downloader = _FakeDownloader(celular: true);
        await abrirTela(tester, repository: repository, downloader: downloader);

        await tester.tap(botao);
        await tester.pumpAndSettle();
        await tester.tap(apps);
        await tester.pumpAndSettle();

        expect(downloader.enviadoParaApps, 'relatorio-estudo-27.pdf');
        expect(downloader.nome, isNull);
        expect(
          find.text(
            'Relatório relatorio-estudo-27.pdf enviado para o app escolhido.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('fechar a escolha não gera o relatório', (tester) async {
        final repository = _FakeExportRepository()..concluir();
        final downloader = _FakeDownloader(celular: true);
        await abrirTela(tester, repository: repository, downloader: downloader);

        await tester.tap(botao);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Onde salvar o relatório?'), findsNothing);
        expect(repository.chamadas, 0);
        expect(find.text('Baixar em PDF'), findsOneWidget);
      });

      testWidgets('envio cancelado não mostra sucesso', (tester) async {
        final repository = _FakeExportRepository()..concluir();
        await abrirTela(
          tester,
          repository: repository,
          downloader: _FakeDownloader(celular: true, cancelar: true),
        );

        await tester.tap(botao);
        await tester.pumpAndSettle();
        await tester.tap(apps);
        await tester.pumpAndSettle();

        expect(find.text('Envio cancelado.'), findsOneWidget);
        expect(find.textContaining('enviado'), findsNothing);
      });
    });
  });
}

class _FakeExportRepository implements StudyExportRepository {
  _FakeExportRepository({this.erro});

  final ExportacaoException? erro;
  int chamadas = 0;
  int? idEstudo;
  int? idCenario;

  final _resposta = Completer<void>();
  void concluir() => _resposta.complete();

  @override
  Future<ArquivoExportado> exportarPdf({
    required int idEstudo,
    int? idCenario,
    Uint8List? imagemMapa,
  }) async {
    chamadas++;
    this.idEstudo = idEstudo;
    this.idCenario = idCenario;
    if (erro != null) throw erro!;
    await _resposta.future;
    return ArquivoExportado(
      nome: 'relatorio-estudo-$idEstudo.pdf',
      bytes: _pdf,
    );
  }
}

class _FakeDownloader implements FileDownloader {
  _FakeDownloader({
    this.falhar = false,
    this.cancelar = false,
    this.celular = false,
  });

  final bool falhar;
  final bool cancelar;
  final bool celular;
  String? nome;
  Uint8List? bytes;
  String? enviadoParaApps;

  @override
  bool get podeEnviarParaApps => celular;

  @override
  Future<ResultadoCompartilhamento> enviarPdfParaApps({
    required String nome,
    required Uint8List bytes,
  }) async {
    if (falhar) throw StateError('sem app');
    if (cancelar) return ResultadoCompartilhamento.cancelado;
    enviadoParaApps = nome;
    return ResultadoCompartilhamento.enviado;
  }

  @override
  Future<String?> salvarPdf({
    required String nome,
    required Uint8List bytes,
  }) async {
    if (falhar) throw StateError('disco cheio');
    this.nome = nome;
    this.bytes = bytes;
    return cancelar ? null : 'C:/Downloads/$nome';
  }
}

class _MapaFalso {
  Future<Uint8List> snapshot() async => Uint8List.fromList([1]);
}
