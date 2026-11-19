import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/pages/map_page.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/study_area_step.dart';

Future<void> proceed(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Prosseguir'));
  await tester.pumpAndSettle();
}

Future<void> chooseInitial(WidgetTester tester) async {
  await tester.tap(find.text('DIST.'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Distribuidora A'));
  await tester.pump();
  await proceed(tester);
  expect(find.text('Filtrar por cidade'), findsOneWidget);
  await tester.tap(find.text('Cidade A'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('confirmar distribuidora inicial abre cidades automaticamente', (
    tester,
  ) async {
    final service = _SelectionService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: MapPage(ativosService: service)));
    await tester.pumpAndSettle();
    await chooseInitial(tester);
    expect(find.text('DIST. Distribuidora A'), findsOneWidget);
    expect(find.text('Cidade A'), findsOneWidget);
    expect(service.calls, 1);
  });
  testWidgets(
    'iniciar estudo mantém distribuidora e cidade sem nova consulta',
    (tester) async {
      final service = _SelectionService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(home: MapPage(ativosService: service)),
      );
      await tester.pumpAndSettle();
      await chooseInitial(tester);
      await tester.tap(find.text('Iniciar estudo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectionBottomSheet<String>>(
              find.byType(SelectionBottomSheet<String>),
            )
            .selectedValue,
        'Distribuidora A',
      );
      await proceed(tester);
      expect(
        tester
            .widget<CidadeBottomSheet>(find.byType(CidadeBottomSheet))
            .cidadeSelecionada,
        'Cidade A',
      );
      await proceed(tester);
      expect(
        tester.widget<StudyAreaStep>(find.byType(StudyAreaStep)).locationLabel,
        contains('Distribuidora A · SP · Cidade A'),
      );
      expect(service.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('trocar distribuidora no estudo limpa cidade incompatível', (
    tester,
  ) async {
    final service = _SelectionService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: MapPage(ativosService: service)));
    await tester.pumpAndSettle();
    await chooseInitial(tester);
    await tester.tap(find.text('Iniciar estudo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distribuidora B'));
    await tester.pump();
    await proceed(tester);
    final sheet = tester.widget<CidadeBottomSheet>(
      find.byType(CidadeBottomSheet),
    );
    expect(sheet.cidadeSelecionada, isNull);
    expect(sheet.cidades, ['Cidade B']);
    expect(service.calls, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dispensar filtro inicial não abre cidade nem altera seleção', (
    tester,
  ) async {
    final service = _SelectionService();
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(home: MapPage(ativosService: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DIST.'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SelectionBottomSheet<String>)))
        .pop();
    await tester.pumpAndSettle();
    expect(find.text('Filtrar por cidade'), findsNothing);
    expect(service.calls, 0);
  });
}

class _SelectionService extends AtivosService {
  int calls = 0;
  @override
  Future<List<DistribuidoraResumo>> getDistribuidoras() async => [
    const DistribuidoraResumo(
      id: 1,
      nome: 'Distribuidora A',
      uf: 'SP',
      anoBdgd: 2026,
    ),
    const DistribuidoraResumo(
      id: 2,
      nome: 'Distribuidora B',
      uf: 'SP',
      anoBdgd: 2026,
    ),
  ];
  @override
  Future<List<MunicipioResumo>> getMunicipios({
    required String distribuidora,
    required String uf,
  }) async {
    calls++;
    return [
      MunicipioResumo(
        nome: distribuidora == 'Distribuidora A' ? 'Cidade A' : 'Cidade B',
        uf: uf,
      ),
    ];
  }
}
