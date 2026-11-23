import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/widgets/recommendation/coverage_summary.dart';

void main() {
  testWidgets('US72: resumo mostra contagens de ativos por tipo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CoverageSummaryCard(result: buildRecommendationMock()),
        ),
      ),
    ));
    expect(find.text('Ativos elétricos'), findsOneWidget);
    expect(find.text('6 de 9'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('sem cobertura', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
