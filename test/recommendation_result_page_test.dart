import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend_tecsys/widgets/branded_loading_screen.dart';
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
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('loading do estudo reutiliza visual de autenticação em $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _PendingRecommendationRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: RecomendacaoResultadoPage(
            idEstudo: 27,
            idPerfilRf: 8,
            titulo: 'Meu estudo',
            repository: repository,
            showBaseMap: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BrandedLoadingScreen), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Calculando a recomendação de cobertura...'),
        findsOneWidget,
      );
      expect(find.text('GEOMASH'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(tester.getSize(find.byType(BrandedLoadingScreen)), size);
      repository.result.complete(buildRecommendationMock(studyId: 27));
      await tester.pumpAndSettle();
      expect(find.byType(BrandedLoadingScreen), findsNothing);
      expect(find.byType(RecommendationMap), findsOneWidget);
      expect(find.text('Meu estudo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('falha encerra novo loading e preserva a mensagem de erro', (
    tester,
  ) async {
    final repository = _PendingRecommendationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 27,
          idPerfilRf: 8,
          repository: repository,
          showBaseMap: false,
        ),
      ),
    );
    expect(
      find.text('Calculando a recomendação de cobertura...'),
      findsOneWidget,
    );
    repository.result.completeError(StateError('Falha de teste'));
    await tester.pumpAndSettle();
    expect(find.byType(BrandedLoadingScreen), findsNothing);
    expect(
      find.textContaining('Não foi possível gerar a recomendação.'),
      findsOneWidget,
    );
    expect(find.textContaining('Falha de teste'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets(
    'falha na recomendação aparece sem erro assíncrono de cobertura',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecomendacaoResultadoPage(
            idEstudo: 27,
            idPerfilRf: 8,
            repository: _FailedRecommendationRepository(),
            coverageRepository: _FakeScenarioCoverageRepository(),
            showBaseMap: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Não foi possível gerar a recomendação.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

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

class _FailedRecommendationRepository implements RecommendationRepository {
  @override
  Future<ResultadoRecomendacao> gerarRecomendacao({
    required int idEstudo,
    required int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  }) async {
    throw StateError('Falha de teste');
  }
}

class _PendingRecommendationRepository implements RecommendationRepository {
  final result = Completer<ResultadoRecomendacao>();

  @override
  Future<ResultadoRecomendacao> gerarRecomendacao({
    required int idEstudo,
    required int idPerfilRf,
    int? idCriterioInstalacao,
    String? nomeCenario,
  }) => result.future;
}
