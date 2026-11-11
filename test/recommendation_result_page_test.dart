import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/models/mancha_cenario.dart';
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';
import 'package:frontend_tecsys/pages/gateway_detail_page.dart';
import 'package:frontend_tecsys/pages/recomendacao_resultado_page.dart';
import 'package:frontend_tecsys/services/recomendacao_service.dart';
import 'package:frontend_tecsys/services/mancha_cenario_service.dart';
import 'package:frontend_tecsys/widgets/recommendation_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend_tecsys/widgets/recommendation/recommendation_result_panel.dart';

void main() {
  testWidgets('switches all six scenarios without changing another result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ScenarioRepository();
    final original = repository.scenarios.first;
    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 1,
          idPerfilRf: 1,
          repository: repository,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final scenario in repository.scenarios) {
      await tester.tap(
        find.byKey(ValueKey('scenario-tab-${scenario.idCenario}')),
      );
      await tester.pumpAndSettle();
      final map = tester.widget<RecommendationMap>(
        find.byType(RecommendationMap),
      );
      final panel = tester.widget<RecommendationResultPanel>(
        find.byType(RecommendationResultPanel),
      );
      expect(map.gateways, same(scenario.gateways));
      expect(map.assets, same(scenario.ativosMapa));
      expect(panel.result, same(scenario));
      expect(
        map.gateways.single.manchasCobertura.single.first.latitude,
        scenario.gateways.single.latitude,
      );
    }
    await tester.tap(
      find.byKey(ValueKey('scenario-tab-${original.idCenario}')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RecommendationResultPanel>(
            find.byType(RecommendationResultPanel),
          )
          .result,
      same(original),
    );
    expect(repository.selectedId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves the chosen scenario and restores it when reopening', (
    tester,
  ) async {
    final repository = _ScenarioRepository();
    Future<void> open(String key) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecomendacaoResultadoPage(
            key: ValueKey(key),
            idEstudo: 1,
            idPerfilRf: 1,
            repository: repository,
            showBaseMap: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open('first');
    await tester.ensureVisible(find.byKey(const ValueKey('scenario-tab-1003')));
    await tester.tap(find.byKey(const ValueKey('scenario-tab-1003')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keep-scenario')));
    await tester.pumpAndSettle();
    expect(repository.selectedId, 1003);
    expect(find.text('Cenário mantido no estudo'), findsOneWidget);
    await open('reopened');
    expect(
      tester
          .widget<RecommendationResultPanel>(
            find.byType(RecommendationResultPanel),
          )
          .result
          .idCenario,
      1003,
    );
    expect(repository.loadCount, 2);
  });

  testWidgets('selection failures do not mark a scenario as kept', (
    tester,
  ) async {
    final repository = _ScenarioRepository()..failSelection = true;
    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 1,
          idPerfilRf: 1,
          repository: repository,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keep-scenario')));
    await tester.pumpAndSettle();
    expect(repository.selectedId, isNull);
    expect(
      find.text('Não foi possível manter o cenário. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Manter este cenário'), findsOneWidget);
  });

  testWidgets('mobile allows reaching the fifth alternative without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ScenarioRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 1,
          idPerfilRf: 1,
          repository: repository,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('scenario-tab-1005')));
    await tester.tap(find.byKey(const ValueKey('scenario-tab-1005')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RecommendationResultPanel>(
            find.byType(RecommendationResultPanel),
          )
          .result
          .idCenario,
      1005,
    );
    expect(tester.getSize(find.byType(RecommendationMap)).width, 296);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late coverage belongs only to its own scenario', (tester) async {
    final repository = _ScenarioRepository();
    final coverage = _DelayedCoverageRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 1,
          idPerfilRf: 1,
          repository: repository,
          coverageRepository: coverage,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scenario-tab-1001')));
    await tester.pumpAndSettle();
    coverage.requests[1000]!.complete(
      const ManchaCenario(manchaConsolidada: [], gateways: []),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<RecommendationMap>(find.byType(RecommendationMap)).gateways,
      same(repository.scenarios[1].gateways),
    );
    expect(
      tester
          .widget<RecommendationMap>(find.byType(RecommendationMap))
          .scenarioCoverage,
      isEmpty,
    );
    coverage.requests[1001]!.complete(
      const ManchaCenario(manchaConsolidada: [], gateways: []),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('service loads saved groups without regenerating and persists the selection', () async {
    final requests = <http.Request>[];
    final service = RecomendacaoService(
      baseUrl: 'http://localhost:3000',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            request.method == 'GET'
                ? {
                    'alternativas_geradas': true,
                    'cenarios': [_scenarioJson(1)],
                    'id_cenario_selecionado': 1,
                  }
                : {'id_cenario_selecionado': 1},
          ),
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    final group = await service.loadScenarios(studyId: 7, profileId: 2);
    expect(group.selectedScenarioId, 1);
    await service.selectScenario(studyId: 7, scenarioId: 1);
    expect(requests.map((request) => request.method), ['GET', 'PATCH']);
    expect(requests.last.url.path, '/study/7/selected-scenario');
    expect(jsonDecode(requests.last.body), {'id_cenario': 1});
  });

  test(
    'service generates a group only when no current alternatives exist',
    () async {
      final methods = <String>[];
      final service = RecomendacaoService(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'GET')
            return http.Response('{"cenarios": []}', 200);
          expect(jsonDecode(request.body), {
            'id_perfil_rf': 2,
            'id_criterio_instalacao': 3,
          });
          return http.Response(
            jsonEncode({
              'cenarios': List.generate(6, (index) => _scenarioJson(index + 1)),
            }),
            201,
          );
        }),
      );
      addTearDown(service.dispose);
      final group = await service.loadScenarios(
        studyId: 7,
        profileId: 2,
        criterionId: 3,
      );
      expect(group.scenarios, hasLength(6));
      expect(methods, ['GET', 'POST']);
    },
  );

  testWidgets('mobile result uses the full available width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 1,
          idPerfilRf: 1,
          resultadoInicial: buildRecommendationMock(),
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(RecommendationMap)).width, 366);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens gateway details from a result card', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 1,
          idPerfilRf: 1,
          titulo: 'Alimentador SUL-14 — Fase 1',
          resultadoInicial: buildRecommendationMock(),
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecommendationMap), findsOneWidget);
    expect(find.byKey(const ValueKey('gateway-card-14')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gateway-card-14')));
    await tester.pumpAndSettle();

    expect(find.byType(GatewayDetailPage), findsOneWidget);
    expect(find.text('Voltar ao resultado'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('4,2 km'), findsOneWidget);
  });

  testWidgets('accepts an injected recommendation repository', (tester) async {
    final repository = _FakeRecommendationRepository();
    final coverageRepository = _FakeScenarioCoverageRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 27,
          idPerfilRf: 8,
          idCriterioInstalacao: 4,
          repository: repository,
          coverageRepository: coverageRepository,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.request, (27, 8, 4));
    expect(coverageRepository.scenarioId, 1027);
    expect(find.byType(RecommendationMap), findsOneWidget);
    expect(
      tester
          .widget<RecommendationMap>(find.byType(RecommendationMap))
          .scenarioCoverage,
      hasLength(1),
    );
  });
}

class _FakeScenarioCoverageRepository implements ScenarioCoverageRepository {
  int? scenarioId;

  @override
  Future<ManchaCenario> getManchaCenario(int idCenario) async {
    scenarioId = idCenario;
    return const ManchaCenario(
      manchaConsolidada: [],
      gateways: [
        ManchaGatewayCenario(
          idEstudoPonto: 14,
          rotulo: 'GW-14',
          posicao: LatLng(-23.1914, -45.8840),
          alcanceMedioM: 4200,
          mancha: [
            LatLng(-23.18, -45.90),
            LatLng(-23.18, -45.87),
            LatLng(-23.21, -45.88),
          ],
        ),
      ],
    );
  }
}

class _FakeRecommendationRepository implements RecommendationRepository {
  (int, int, int?)? request;

  @override
  Future<RecommendationScenarios> loadScenarios({
    required int studyId,
    required int profileId,
    int? criterionId,
  }) async {
    request = (studyId, profileId, criterionId);
    return RecommendationScenarios(
      scenarios: [buildRecommendationMock(studyId: studyId)],
    );
  }

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
  }) async {
    request = (idEstudo, idPerfilRf, idCriterioInstalacao);
    return buildRecommendationMock(studyId: idEstudo);
  }
}

Map<String, dynamic> _scenarioJson(int id) => {
  'id_cenario': id,
  'nome': id == 1 ? 'Otimizada' : 'Alternativa ${id - 1}',
  'otimizado': id == 1,
  'quantidade_gateways': 1,
  'percentual_cobertura': 50,
  'custo_total_estimado': 100,
  'pontos_interesse': 2,
  'pontos_cobertos': 1,
  'pontos_nao_cobertos': 1,
  'capacidade_utilizada_media_pct': 25,
};

class _ScenarioRepository implements RecommendationRepository {
  final scenarios = List.generate(6, (index) {
    final base = buildRecommendationMock();
    final gateway = base.gateways.first;
    final covered = index + 1;
    return ResultadoRecomendacao(
      idCenario: 1000 + index,
      name: index == 0 ? 'Otimizada' : 'Alternativa $index',
      optimized: index == 0,
      quantidadeGateways: 1,
      percentualCobertura: (covered / base.pontosInteresse * 100).round(),
      custoTotalEstimado: 100,
      pontosInteresse: base.pontosInteresse,
      pontosCobertos: covered,
      pontosNaoCobertos: base.pontosInteresse - covered,
      capacityUsedPercent: covered / 10 * 100,
      porCategoria: const [],
      gateways: [
        GatewayProposto(
          idEstudoPonto: 14 + index,
          idAtivoBdgd: null,
          rotulo: 'GW-${14 + index}',
          latitude: gateway.latitude + index * .001,
          longitude: gateway.longitude,
          quantidadeAtendidos: covered,
          atributos: const {},
          atendidos: const [],
          manchasCobertura: [
            [
              LatLng(gateway.latitude + index * .001, gateway.longitude),
              LatLng(gateway.latitude + .01, gateway.longitude),
              LatLng(gateway.latitude, gateway.longitude + .01),
            ],
          ],
        ),
      ],
      ativosMapa: [
        for (final (assetIndex, asset) in base.ativosMapa.indexed)
          AtivoResultadoMapa(
            idEstudoPonto: asset.idEstudoPonto,
            idAtivoBdgd: asset.idAtivoBdgd,
            tipoAtivo: asset.tipoAtivo,
            latitude: asset.latitude,
            longitude: asset.longitude,
            coberto: assetIndex < covered,
            idGatewayReferencia: assetIndex < covered ? 14 + index : null,
          ),
      ],
    );
  });
  int? selectedId;
  bool failSelection = false;
  int loadCount = 0;

  @override
  Future<RecommendationScenarios> loadScenarios({
    required int studyId,
    required int profileId,
    int? criterionId,
  }) async {
    loadCount++;
    return RecommendationScenarios(
      scenarios: scenarios,
      selectedScenarioId: selectedId,
    );
  }

  @override
  Future<void> selectScenario({
    required int studyId,
    required int scenarioId,
  }) async {
    if (failSelection) throw StateError('failed');
    selectedId = scenarioId;
  }

  @override
  Future<ResultadoRecomendacao> gerarRecomendacao({
    required int idEstudo,
    required int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  }) async => scenarios.first;
}

class _DelayedCoverageRepository implements ScenarioCoverageRepository {
  final requests = <int, Completer<ManchaCenario>>{};

  @override
  Future<ManchaCenario> getManchaCenario(int idCenario) =>
      (requests[idCenario] = Completer<ManchaCenario>()).future;
}
