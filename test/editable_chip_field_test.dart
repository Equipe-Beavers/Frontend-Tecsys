import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/widgets/editable_chip_field.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('displayed chips are present without selection interactions', (
    tester,
  ) async {
    var changes = 0;
    await tester.pumpWidget(
      _host(
        EditableChipField(
          defaultItems: const ['POSTE', 'TORRE'],
          availableItems: const ['POSTE', 'TORRE'],
          onItemsChanged: (_) => changes++,
        ),
      ),
    );

    expect(find.widgetWithText(Chip, 'POSTE'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'TORRE'), findsOneWidget);
    await tester.tap(find.text('POSTE'));
    await tester.pump();
    expect(find.widgetWithText(Chip, 'POSTE'), findsOneWidget);
    expect(changes, 0);
  });

  testWidgets('removing a chip updates parent and survives rebuilds', (
    tester,
  ) async {
    final removedItems = <String>[];
    final itemUpdates = <List<String>>[];
    var revision = 0;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              Text('$revision'),
              EditableChipField(
                defaultItems: const ['POSTE', 'TORRE'],
                availableItems: const ['POSTE', 'TORRE'],
                onRemove: removedItems.add,
                onItemsChanged: (items) {
                  itemUpdates.add(items);
                  setState(() => revision++);
                },
              ),
            ],
          ),
        ),
      ),
    );

    final posteChip = find.widgetWithText(Chip, 'POSTE');
    await tester.tap(
      find.descendant(of: posteChip, matching: find.byIcon(Icons.close)),
    );
    await tester.pump();
    expect(find.widgetWithText(Chip, 'POSTE'), findsNothing);
    expect(removedItems, ['POSTE']);
    expect(itemUpdates.single, ['TORRE']);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('add button adds items once and supports an empty field', (
    tester,
  ) async {
    var addCalls = 0;
    final itemUpdates = <List<String>>[];
    await tester.pumpWidget(
      _host(
        EditableChipField(
          defaultItems: const [],
          availableItems: const ['NEW_ITEM', 'ANOTHER_ITEM'],
          onItemsChanged: itemUpdates.add,
          onAdd: (availableItems, existingItems) async {
            addCalls++;
            expect(availableItems, ['NEW_ITEM', 'ANOTHER_ITEM']);
            expect(existingItems, isEmpty);
            return ['NEW_ITEM', 'ANOTHER_ITEM'];
          },
        ),
      ),
    );

    expect(find.byType(Chip), findsNothing);
    expect(find.text('Adicionar'), findsOneWidget);
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'NEW ITEM'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'ANOTHER ITEM'), findsOneWidget);
    expect(addCalls, 1);
    expect(itemUpdates, [
      ['NEW_ITEM', 'ANOTHER_ITEM'],
    ]);
  });

  testWidgets('excluded items cannot be offered or added by the callback', (
    tester,
  ) async {
    final itemUpdates = <List<String>>[];
    var addCalls = 0;
    await tester.pumpWidget(
      _host(
        EditableChipField(
          defaultItems: const ['IN_A'],
          availableItems: const ['IN_A', 'IN_B', 'IN_C'],
          excludedItems: const {'IN_B'},
          onItemsChanged: itemUpdates.add,
          onAdd: (availableItems, existingItems) async {
            addCalls++;
            expect(availableItems, ['IN_A', 'IN_B', 'IN_C']);
            expect(existingItems, {'IN_A', 'IN_B'});
            return ['IN_B', 'IN_C'];
          },
        ),
      ),
    );

    expect(
      tester.widget<ActionChip>(find.byType(ActionChip)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(addCalls, 1);
    expect(find.widgetWithText(Chip, 'IN B'), findsNothing);
    expect(find.widgetWithText(Chip, 'IN C'), findsOneWidget);
    expect(itemUpdates, [
      ['IN_A', 'IN_C'],
    ]);
  });

  testWidgets('enabled and showAddButton control available actions', (
    tester,
  ) async {
    var removeCalls = 0;
    var addCalls = 0;
    await tester.pumpWidget(
      _host(
        EditableChipField(
          defaultItems: const ['TORRE'],
          availableItems: const ['TORRE', 'POSTE'],
          enabled: false,
          onRemove: (_) => removeCalls++,
          onAdd: (_, _) async {
            addCalls++;
            return ['POSTE'];
          },
        ),
      ),
    );
    await tester.tap(find.text('Adicionar'));
    await tester.pump();
    expect(addCalls, 0);
    expect(removeCalls, 0);

    await tester.pumpWidget(
      _host(
        EditableChipField(
          key: const ValueKey('without-add'),
          defaultItems: const ['TORRE'],
          availableItems: const ['TORRE'],
          showAddButton: false,
        ),
      ),
    );
    expect(find.text('Adicionar'), findsNothing);
    expect(find.widgetWithText(Chip, 'TORRE'), findsOneWidget);
  });

  testWidgets('secondary variant applies the orange chip colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const EditableChipField(
          defaultItems: ['POSTES_TERCEIROS'],
          availableItems: ['POSTES_TERCEIROS'],
          colorVariant: ChipColorVariant.secondary,
          itemLabels: {'POSTES_TERCEIROS': 'Postes de terceiros'},
        ),
      ),
    );

    final chip = tester.widget<Chip>(find.byType(Chip));
    expect(chip.backgroundColor, Colors.orange.withValues(alpha: .12));
    expect(chip.side?.color, Colors.orange.withValues(alpha: .55));
  });
}
