import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/pages/install_criterion_form.dart';

import 'support/criterion_test_support.dart';

void main() {
  for (final width in [330.0, 390.0, 1440.0]) {
    testWidgets('typed distances and slider stay synchronized at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        host(
          InstallCriterionForm(
            userId: 1,
            onSave: (payload) async => saved = payload,
            onClose: () {},
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Intervalo',
      );
      final minimum = find.byKey(const ValueKey('distance-minimum'));
      final maximum = find.byKey(const ValueKey('distance-maximum'));
      await tester.ensureVisible(minimum);
      await tester.enterText(minimum, '125,5');
      await tester.enterText(maximum, '300');
      await tester.pump();
      expect(
        tester.widget<RangeSlider>(find.byType(RangeSlider)).values,
        const RangeValues(125.5, 300),
      );
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
        const RangeValues(100, 250),
      );
      await tester.pump();
      expect(tester.widget<TextFormField>(minimum).controller!.text, '100');
      expect(tester.widget<TextFormField>(maximum).controller!.text, '250');
      await tester.ensureVisible(find.text('Salvar critério'));
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(saved!['distancia_minima_ativos_m'], 100);
      expect(saved!['distancia_maxima_ativos_m'], 250);
      if (width < 1100) {
        final section = find.byKey(const ValueKey('section-assets'));
        await tester.ensureVisible(section);
        await tester.tap(section);
        await tester.pumpAndSettle();
        expect(find.text('ESTRUTURAS'), findsOneWidget);
        expect(find.text('PROTEÇÃO E MANOBRA'), findsOneWidget);
        expect(find.text('REGULAÇÃO'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'collapsed numeric errors are revealed and values survive folding',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saved = false;
      await tester.pumpWidget(
        host(
          InstallCriterionForm(
            userId: 1,
            onSave: (_) async => saved = true,
            onClose: () {},
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Relevo',
      );
      final section = find.byKey(const ValueKey('section-relief'));
      await tester.ensureVisible(section);
      await tester.tap(section);
      await tester.pump();
      final minimum = find.widgetWithText(TextFormField, 'Mínima');
      await tester.ensureVisible(minimum);
      await tester.enterText(minimum, 'abc');
      await tester.ensureVisible(section);
      await tester.tap(section);
      await tester.pump();
      expect(minimum, findsNothing);
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(saved, isFalse);
      expect(find.text('Informe um número válido.'), findsOneWidget);
      expect(tester.widget<TextFormField>(minimum).controller!.text, 'abc');
      await tester.enterText(minimum, '300');
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
    },
  );
}
