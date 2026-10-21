import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';
import 'package:frontend_tecsys/pages/gateway_detail_page.dart';
import 'package:frontend_tecsys/pages/recomendacao_resultado_page.dart';
import 'package:frontend_tecsys/services/recomendacao_service.dart';
import 'package:frontend_tecsys/widgets/recommendation_map.dart';

void main() {
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
    await tester.pumpWidget(
      MaterialApp(
        home: RecomendacaoResultadoPage(
          idEstudo: 27,
          idPerfilRf: 8,
          idCriterioInstalacao: 4,
          repository: repository,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.request, (27, 8, 4));
    expect(find.byType(RecommendationMap), findsOneWidget);
  });
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
