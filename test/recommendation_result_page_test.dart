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

void main() {
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
