import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/install_criterion.dart';
import 'package:frontend_tecsys/widgets/criterion_type_dialog.dart';
import 'package:frontend_tecsys/widgets/editable_chip_field.dart';

void main() {
  testWidgets(
    'dialog shows existing items and adds multiple selected options',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => EditableChipField(
                defaultItems: const ['POSTES'],
                availableItems: criterionAssetTypes.keys.toList(),
                itemLabels: criterionAssetTypes,
                onAdd: (availableItems, existingItems) =>
                    showDialog<List<String>>(
                      context: context,
                      builder: (_) => CriterionTypeDialog(
                        availableItems: availableItems,
                        existingItems: existingItems,
                      ),
                    ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      var dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Postes')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Já adicionado')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Subestações')),
        findsOneWidget,
      );
      await tester.tap(find.text('Subestações'));
      await tester.tap(find.text('Torres'));
      await tester.pump();
      expect(find.text('Adicionar'), findsNWidgets(2));
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Adicionar')),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'Subestações'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Torres'), findsOneWidget);

      final substationChip = find.widgetWithText(Chip, 'Subestações');
      await tester.tap(
        find.descendant(of: substationChip, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      expect(substationChip, findsNothing);

      await tester.tap(find.text('Adicionar').first);
      await tester.pumpAndSettle();
      dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Subestações')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Já adicionado')),
        findsNWidgets(2),
      );
    },
  );
}
