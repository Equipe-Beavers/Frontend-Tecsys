import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/pages/gateway_detail_page.dart';
import 'package:frontend_tecsys/widgets/recommendation_map.dart';

void main() {
  testWidgets('mobile map and details use the full available width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = buildRecommendationMock();
    await tester.pumpWidget(
      MaterialApp(
        home: GatewayDetailPage(
          gateway: result.gateways.first,
          assets: result.ativosMapa,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(RecommendationMap)).width, 366);
    expect(
      tester.getSize(find.byKey(const ValueKey('gateway-details-panel'))).width,
      390,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop gateway panel fills the right side from the header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = buildRecommendationMock();
    await tester.pumpWidget(
      MaterialApp(
        home: GatewayDetailPage(
          gateway: result.gateways.first,
          assets: result.ativosMapa,
          showBaseMap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('gateway-details-panel')),
    );
    expect(panelRect.width, 360);
    expect(panelRect.top, 64);
    expect(panelRect.bottom, 800);
    expect(tester.getTopLeft(find.text('GW-14 · Poste MT 88213')).dy, 82);
    expect(tester.takeException(), isNull);
  });
}
