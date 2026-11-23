import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';
import 'package:frontend_tecsys/pages/recomendacao_resultado_page.dart';
import 'package:frontend_tecsys/services/exportacao_service.dart';
import 'package:frontend_tecsys/services/file_download_service.dart';
import 'package:frontend_tecsys/services/recomendacao_service.dart';
import 'package:frontend_tecsys/widgets/recommendation/scenario_map_capture.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.3 teste'));

ResultadoRecomendacao _cenario(int id, {bool otimizado = false}) {
  final base = buildRecommendationMock();
  return ResultadoRecomendacao(
    idCenario: id,
    name: otimizado ? 'Otimizada' : 'Alternativa ${id % 100}',
    optimized: otimizado,
    quantidadeGateways: base.quantidadeGateways,
    percentualCobertura: base.percentualCobertura,

    pontosInteresse: base.pontosInteresse,
    pontosCobertos: base.pontosCobertos,
    pontosNaoCobertos: base.pontosNaoCobertos,
    porCategoria: base.porCategoria,
    gateways: base.gateways,
    ativosMapa: base.ativosMapa,
  );
}

ScenarioMapData _dados(int id) => ScenarioMapData.fromResult(_cenario(id));

void main() {
  group('ExportacaoService · imagens_mapa', () {
    test('envia o mapa de cada um dos demais cenários por id', () async {
      late http.Request enviado;
      final service = ExportacaoService(
        baseUrl: 'http://api.test',
        client: MockClient((request) async {
          enviado = request;
          return http.Response.bytes(_pdf, 200);
        }),
      );

      await service.exportarPdf(
        idEstudo: 27,
        idCenario: 104,
        imagemMapa: Uint8List.fromList([1]),
        imagensMapa: {
          105: Uint8List.fromList([2]),
          106: Uint8List.fromList([3]),
          104: Uint8List.fromList([9]),
          107: Uint8List(0),
        },
      );

      expect(jsonDecode(enviado.body), {
        'id_cenario': 104,
        'imagem_mapa': base64Encode([1]),
        'imagens_mapa': {
          '105': base64Encode([2]),
          '106': base64Encode([3]),
        },
      });
    });
  });

  group('OtherScenarioMapsCollector', () {
    test('captura as outras abas com os dados delas e ignora falhas', () async {
      final capturados = <int>[];
      final collector = OtherScenarioMapsCollector(
        capturar: (data) async {
          capturados.add(data.idCenario);
          if (data.idCenario == 107) throw StateError('mapa não carregou');
          return Uint8List.fromList([data.idCenario % 256]);
        },
      );

      final imagens = await collector.coletar(
        cenarios: [_dados(104), _dados(105), _dados(106), _dados(107)],
        idCenarioVisivel: 104,
      );

      expect(capturados, [105, 106, 107]);
      expect(imagens.keys, [105, 106]);
    });

    test('respeita os limites de quantidade e de tamanho', () async {
      final collector = OtherScenarioMapsCollector(
        capturar: (_) async => Uint8List(30),
        maxCenarios: 3,
        limiteTotalBase64: 100,
      );

      final imagens = await collector.coletar(
        cenarios: [_dados(1), _dados(2), _dados(3), _dados(4)],
        idCenarioVisivel: null,
        imagemVisivel: Uint8List(15),
      );

      expect(imagens.keys, [1, 2]);
    });
  });

  group('Página de resultado · PDF', () {
    Future<_RecordingExportRepository> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _RecordingExportRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: RecomendacaoResultadoPage(
            idEstudo: 27,
            idPerfilRf: 8,
            showBaseMap: false,
            repository: _GroupRepository([
              _cenario(900, otimizado: true),
              _cenario(901),
            ]),
            exportRepository: repository,
            fileDownloader: _NoopDownloader(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> exportar(
      WidgetTester tester, {
      required int mapaOculto,
    }) async {
      await tester.tap(find.byKey(const ValueKey('export-pdf-button')));
      await tester.pump();
      expect(find.text('Capturando mapas dos cenários...'), findsOneWidget);
      expect(
        find.byKey(ValueKey('scenario-capture-map-$mapaOculto')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('scenario-capture-map-$mapaOculto')),
        findsNothing,
      );
    }

    testWidgets('destaca a aba aberta e desenha o mapa das outras', (
      tester,
    ) async {
      final repository = await abrir(tester);

      await exportar(tester, mapaOculto: 901);

      expect(repository.chamadas, 1);
      expect(repository.idCenario, 900);
      expect(repository.imagensMapa, isEmpty);
    });

    testWidgets('com outra aba aberta, ela vira a alternativa do PDF', (
      tester,
    ) async {
      final repository = await abrir(tester);
      await tester.tap(find.byKey(const ValueKey('scenario-tab-901')));
      await tester.pumpAndSettle();

      await exportar(tester, mapaOculto: 900);

      expect(repository.idCenario, 901);
    });
  });
}

class _GroupRepository implements RecommendationRepository {
  _GroupRepository(this.scenarios);

  final List<ResultadoRecomendacao> scenarios;

  @override
  Future<RecommendationScenarios> loadScenarios({
    required int studyId,
    required int profileId,
    int? criterionId,
  }) async => RecommendationScenarios(scenarios: scenarios);

  @override
  Future<void> selectScenario({
    required int studyId,
    required int scenarioId,
  }) async {}

  @override
  Future<ResultadoRecomendacao> gerarRecomendacao({
    required int idEstudo,
    required int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  }) async => scenarios.first;
}

class _RecordingExportRepository implements StudyExportRepository {
  int chamadas = 0;
  int? idCenario;
  Map<int, Uint8List>? imagensMapa;

  @override
  Future<ArquivoExportado> exportarPdf({
    required int idEstudo,
    int? idCenario,
    Uint8List? imagemMapa,
    Map<int, Uint8List> imagensMapa = const {},
  }) async {
    chamadas++;
    this.idCenario = idCenario;
    this.imagensMapa = imagensMapa;
    return ArquivoExportado(nome: 'r.pdf', bytes: _pdf);
  }
}

class _NoopDownloader implements FileDownloader {
  @override
  bool get podeEnviarParaApps => false;

  @override
  Future<ResultadoCompartilhamento> enviarPdfParaApps({
    required String nome,
    required Uint8List bytes,
  }) async => ResultadoCompartilhamento.enviado;

  @override
  Future<String?> salvarPdf({
    required String nome,
    required Uint8List bytes,
  }) async => 'C:/Downloads/$nome';
}
