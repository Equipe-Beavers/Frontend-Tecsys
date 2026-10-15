import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/install_criterion.dart';
import 'package:frontend_tecsys/pages/install_criterion_form.dart';
import 'package:frontend_tecsys/widgets/criterion_type_dialog.dart';

import 'support/criterion_test_support.dart';

void main() {
  testWidgets(
    'editing deduplicates aliases without inserting defaults or changing untouched data',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        host(
          InstallCriterionForm(
            criterion: InstallCriterion.fromJson({
              ...fixture,
              'tipos_elementos_permitidos': ['TORRE', 'TORRES', 'Torres'],
              'tipos_elementos_proibidos': [],
            }),
            userId: 1,
            onSave: (value) async => saved = value,
            onClose: () {},
          ),
        ),
      );
      expect(find.widgetWithText(Chip, 'Torres'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Postes'), findsNothing);
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(saved!.containsKey('tipos_elementos_permitidos'), false);
      await tester.tap(find.text('Adicionar').first);
      await tester.pumpAndSettle();
      final dialog = find.byType(CriterionTypeDialog);
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Postes')),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Adicionar')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(saved!['tipos_elementos_permitidos'], ['TORRES', 'POSTES']);
      final torre = find.widgetWithText(Chip, 'Torres');
      await tester.tap(
        find.descendant(of: torre, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      expect(torre, findsNothing);
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(saved!['tipos_elementos_permitidos'], ['POSTES']);
    },
  );

  testWidgets(
    'custom types can be added and aliases of existing types are rejected',
    (tester) async {
      List<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<List<String>>(
                    context: context,
                    builder: (_) => const CriterionTypeDialog(
                      availableItems: ['TORRES'],
                      existingItems: {'TORRES'},
                      allowCustom: true,
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'torre');
      await tester.pump();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Esse tipo já está permitido ou bloqueado.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Caixa de água');
      await tester.pump();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(result, ['CAIXA_DE_AGUA']);
    },
  );
}
