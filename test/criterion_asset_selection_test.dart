import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/install_criterion.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/pages/install_criterion_form.dart';

import 'support/criterion_test_support.dart';

void main() {
  test('criteria catalogue uses exactly the map layers', () {
    expect(
      criterionAssetTypes.values.toList(),
      CatalogoCamadas.obterGrupos()
          .expand((group) => group.itens)
          .map((item) => item.titulo)
          .toList(),
    );
    expect(criterionAssetTypes.keys, isNot(contains('TORRES')));
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'neutral defaults and mutually exclusive rules at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? saved;
        await tester.pumpWidget(
          host(
            InstallCriterionForm(
              userId: 1,
              onSave: (value) async => saved = value,
              onClose: () {},
            ),
          ),
        );
        final section = find.byKey(const ValueKey('section-assets'));
        if (section.evaluate().isNotEmpty) {
          await tester.ensureVisible(section);
          await tester.tap(section);
          await tester.pumpAndSettle();
        }
        expect(find.text('Tipo personalizado'), findsNothing);
        final rules = tester.widgetList<SegmentedButton<int>>(
          find.byType(SegmentedButton<int>),
        );
        expect(rules.length, criterionAssetTypes.length);
        expect(rules.every((rule) => rule.selected.single == 2), isTrue);
        final poste = find.byKey(const ValueKey('asset-rule-POSTE'));
        expect(
          tester
              .widget<SegmentedButton<int>>(poste)
              .segments
              .map((segment) => (segment.label as Text).data)
              .toList(),
          ['Permitido', 'Bloqueado', 'Neutro'],
        );
        Future<void> select(String label) async {
          final option = find.descendant(of: poste, matching: find.text(label));
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pump();
        }

        await select('Permitido');
        await tester.pump();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Regras elétricas',
        );
        await tester.tap(find.text('Salvar critério'));
        await tester.pumpAndSettle();
        expect(saved!['tipos_elementos_permitidos'], ['POSTE']);
        expect(saved!['tipos_elementos_proibidos'], isEmpty);
        await select('Bloqueado');
        await tester.pump();
        await tester.tap(find.text('Salvar critério'));
        await tester.pumpAndSettle();
        expect(saved!['tipos_elementos_permitidos'], isEmpty);
        expect(saved!['tipos_elementos_proibidos'], ['POSTE']);
        await select('Neutro');
        await tester.pump();
        await tester.tap(find.text('Salvar critério'));
        await tester.pumpAndSettle();
        expect(saved!['tipos_elementos_permitidos'], isEmpty);
        expect(saved!['tipos_elementos_proibidos'], isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('legacy assets require explicit removal before editing rules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      host(
        InstallCriterionForm(
          userId: 1,
          criterion: InstallCriterion.fromJson({
            ...fixture,
            'tipos_elementos_permitidos': ['POSTES', 'TORRE'],
          }),
          onSave: (value) async => saved = value,
          onClose: () {},
        ),
      ),
    );
    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const ValueKey('asset-rule-POSTE')),
          )
          .onSelectionChanged,
      isNull,
    );
    await tester.tap(find.text('Remover regras antigas'));
    await tester.pump();
    await tester.tap(find.text('Salvar critério'));
    await tester.pumpAndSettle();
    expect(saved!['tipos_elementos_permitidos'], ['POSTE']);
  });
}
