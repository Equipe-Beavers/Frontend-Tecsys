import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';

void main() {
  Future<void> mount(WidgetTester tester, _Filters filters) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => LayerFilterModal.exibir(
                context,
                camadasAtivas: filters.layers,
                vegetacaoAtiva: filters.vegetation,
                antenasAtivas: filters.antennas,
                edificacoesAtivas: filters.buildings,
                relevoAtivo: filters.terrain,
                onSalvarRelevo: (value) {
                  filters.terrain = value;
                  filters.saves++;
                },
                onSalvarVegetacao: (value) {
                  filters.vegetation = value;
                  filters.saves++;
                },
                onSalvarAntenas: (value) {
                  filters.antennas = value;
                  filters.saves++;
                },
                onSalvarEdificacoes: (value) {
                  filters.buildings = value;
                  filters.saves++;
                },
                onSalvarFiltro: (value) {
                  filters.layers = Map.of(value);
                  filters.saves++;
                },
              ),
              child: const Text('Abrir camadas'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir camadas'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'limpar desmarca as 14 camadas e salvar mantém todas desligadas',
    (tester) async {
      final filters = _Filters();
      await mount(tester, filters);
      expect(find.text('14 de 14 camadas ativas'), findsOneWidget);
      await tester.tap(find.text('Limpar'));
      await tester.pump();
      expect(find.text('0 de 14 camadas ativas'), findsOneWidget);
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(checkboxes, hasLength(14));
      expect(checkboxes.every((checkbox) => checkbox.value == false), isTrue);
      expect(filters.saves, 0);
      expect(filters.layers.values.every((value) => value), isTrue);
      await tester.tap(find.text('Salvar filtro'));
      await tester.pumpAndSettle();
      expect(filters.layers.values.every((value) => !value), isTrue);
      expect(filters.vegetation, isFalse);
      expect(filters.antennas, isFalse);
      expect(filters.buildings, isFalse);
      expect(filters.terrain, isFalse);
      await tester.tap(find.text('Abrir camadas'));
      await tester.pumpAndSettle();
      expect(find.text('0 de 14 camadas ativas'), findsOneWidget);
      await tester.tap(find.text('Limpar'));
      await tester.pump();
      await tester.tap(find.text('Chave Seccionadora'));
      await tester.tap(find.text('Edifícios'));
      await tester.pump();
      expect(find.text('2 de 14 camadas ativas'), findsOneWidget);
      await tester.tap(find.text('Salvar filtro'));
      await tester.pumpAndSettle();
      expect(filters.layers[TipoAtivo.chaveSeccionadora], isTrue);
      expect(filters.buildings, isTrue);
      expect(filters.layers.values.where((value) => value), hasLength(1));
      expect(filters.vegetation, isFalse);
      expect(filters.antennas, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fechar depois de limpar descarta o rascunho sem modificar o mapa',
    (tester) async {
      final filters = _Filters();
      await mount(tester, filters);
      await tester.tap(find.text('Limpar'));
      await tester.pump();
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(filters.saves, 0);
      expect(filters.layers.values.every((value) => value), isTrue);
      expect(filters.vegetation, isTrue);
      expect(filters.antennas, isTrue);
      expect(filters.buildings, isTrue);
      expect(filters.terrain, isTrue);
      await tester.tap(find.text('Abrir camadas'));
      await tester.pumpAndSettle();
      expect(find.text('14 de 14 camadas ativas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Filters {
  Map<TipoAtivo, bool> layers = CatalogoCamadas.obterEstadoInicialPadrao().map(
    (key, _) => MapEntry(key, true),
  );
  bool vegetation = true, antennas = true, buildings = true, terrain = true;
  int saves = 0;
}
