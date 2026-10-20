import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/install_criterion_draft.dart';
import 'package:frontend_tecsys/pages/install_criterion_form.dart';

import 'support/criterion_test_support.dart';

void main() {
  test('semantic conflicts, aliases and numeric limits', () {
    final draft = InstallCriterionDraft();
    expect(
      draft.validatePayload({
        'tipos_elementos_permitidos': ['TORRE'],
        'tipos_elementos_proibidos': ['Torres'],
      }),
      isNotNull,
    );
    expect(
      draft.validatePayload({
        'vegetacoes': {
          'permitidas': ['Mangue'],
          'proibidas': ['MANGUE'],
        },
      }),
      isNotNull,
    );
    expect(
      draft.validatePayload({
        'relevo': {'altitude_minima_m': 500, 'altitude_maxima_m': 100},
      }),
      isNotNull,
    );
    expect(
      draft.validatePayload({
        'relevo': {'declividade_maxima_graus': 91},
      }),
      isNotNull,
    );
    expect(
      draft.validatePayload({
        'relevo': {
          'altitude_minima_m': -100,
          'altitude_maxima_m': 0,
          'declividade_maxima_graus': 90,
        },
      }),
      isNull,
    );
    expect(
      InstallCriterionDraft.validateOptionalInteger('2147483648'),
      isNotNull,
    );
    expect(InstallCriterionDraft.validateOptionalNumber('Infinity'), isNotNull);
    expect(InstallCriterionDraft.validateOptionalNumber('-1'), isNotNull);
  });
  testWidgets(
    'invalid altitude interval stays in the form without calling API',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saves = 0;
      await tester.pumpWidget(
        host(
          InstallCriterionForm(
            userId: 1,
            onSave: (_) async {
              saves++;
            },
            onClose: () {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Validação');
      final minimum = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Mínima',
      );
      final maximum = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Máxima',
      );
      await tester.enterText(minimum, '500');
      await tester.enterText(maximum.first, '100');
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(
        find.text('A altitude mínima não pode ultrapassar a altitude máxima.'),
        findsOneWidget,
      );
      await tester.enterText(maximum.first, '600');
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(saves, 1);
    },
  );
}
