import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/pages/map_page.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/study_area_step.dart';

void main() {
  Future<void> mount(WidgetTester tester, _DelayedAtivos service) async {
    await tester.pumpWidget(MaterialApp(home: MapPage(ativosService: service)));
    await tester.pumpAndSettle();
  }

  Future<void> confirmDistributor(WidgetTester tester) async {
    await tester.tap(find.text('Distribuidora A'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Prosseguir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('cidades carregam com o filtro ainda aberto', (tester) async {
    final service = _DelayedAtivos();
    addTearDown(service.dispose);
    await mount(tester, service);
    await tester.tap(find.text('DIST.'));
    await tester.pumpAndSettle();
    await confirmDistributor(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Filtrar por cidade'), findsOneWidget);
    expect(find.text('Carregando cidades...'), findsOneWidget);
    expect(find.text('Cidade A'), findsNothing);

    service.municipios.complete(const [
      MunicipioResumo(nome: 'Cidade A', uf: 'SP'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Filtrar por cidade'), findsOneWidget);
    expect(find.text('Cidade A'), findsOneWidget);
    expect(find.text('Carregando cidades...'), findsNothing);
    await tester.tap(find.text('Cidade A'));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar por cidade'), findsNothing);
    expect(find.text('Cidade A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro na consulta aparece sem reabrir o filtro', (tester) async {
    final service = _DelayedAtivos();
    addTearDown(service.dispose);
    await mount(tester, service);
    await tester.tap(find.text('DIST.'));
    await tester.pumpAndSettle();
    await confirmDistributor(tester);
    await tester.pump(const Duration(milliseconds: 500));
    service.municipios.completeError(StateError('Falha de teste'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível carregar os municípios'),
      findsOneWidget,
    );
    expect(find.text('Filtrar por cidade'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('estudo avança de distribuidora para cidade e desenho', (
    tester,
  ) async {
    final service = _DelayedAtivos();
    addTearDown(service.dispose);
    await mount(tester, service);
    await tester.tap(find.text('Iniciar estudo'));
    await tester.pumpAndSettle();
    await confirmDistributor(tester);
    expect(find.byType(SelectionBottomSheet<String>), findsNothing);
    expect(find.byType(CidadeBottomSheet), findsOneWidget);
    expect(find.text('Carregando cidades...'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Prosseguir'),
          )
          .onPressed,
      isNull,
    );
    service.municipios.complete(const [
      MunicipioResumo(nome: 'Cidade A', uf: 'SP'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(CidadeBottomSheet), findsOneWidget);
    expect(find.text('PASSO 2 DE 4'), findsOneWidget);
    await tester.tap(find.text('Cidade A'));
    await tester.pump();
    await tester.tap(find.text('Prosseguir'));
    await tester.pumpAndSettle();
    expect(find.byType(CidadeBottomSheet), findsNothing);
    expect(find.byType(StudyAreaStep), findsOneWidget);
    expect(find.text('INICIAR ESTUDO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('estudo sem municípios não fecha a etapa seguinte por engano', (
    tester,
  ) async {
    final service = _DelayedAtivos();
    addTearDown(service.dispose);
    await mount(tester, service);
    await tester.tap(find.text('Iniciar estudo'));
    await tester.pumpAndSettle();
    await confirmDistributor(tester);
    service.municipios.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(CidadeBottomSheet), findsOneWidget);
    await tester.tap(find.text('Prosseguir'));
    await tester.pumpAndSettle();
    expect(find.byType(StudyAreaStep), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispensar distribuidora não abre a etapa de cidade', (
    tester,
  ) async {
    final service = _DelayedAtivos();
    addTearDown(service.dispose);
    await mount(tester, service);
    await tester.tap(find.text('Iniciar estudo'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SelectionBottomSheet<String>)))
        .pop();
    await tester.pumpAndSettle();
    expect(find.byType(CidadeBottomSheet), findsNothing);
    expect(find.byType(StudyAreaStep), findsNothing);
    expect(find.text('Iniciar estudo'), findsOneWidget);
  });

  testWidgets(
    'falha no carregamento do estudo permite tentar novamente na mesma etapa',
    (tester) async {
      final service = _DelayedAtivos();
      addTearDown(service.dispose);
      await mount(tester, service);
      await tester.tap(find.text('Iniciar estudo'));
      await tester.pumpAndSettle();
      await confirmDistributor(tester);
      service.municipios.completeError(StateError('temporário'));
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Carregando cidades...'), findsNothing);
      service.municipios = Completer<List<MunicipioResumo>>();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(find.text('Carregando cidades...'), findsOneWidget);
      service.municipios.complete(const [
        MunicipioResumo(nome: 'Cidade A', uf: 'SP'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Cidade A'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DelayedAtivos extends AtivosService {
  var municipios = Completer<List<MunicipioResumo>>();

  @override
  Future<List<DistribuidoraResumo>> getDistribuidoras() async => [
    const DistribuidoraResumo(
      id: 1,
      nome: 'Distribuidora A',
      uf: 'SP',
      anoBdgd: 2024,
    ),
  ];

  @override
  Future<List<MunicipioResumo>> getMunicipios({
    String? distribuidora,
    required String uf,
  }) => municipios.future;
}
