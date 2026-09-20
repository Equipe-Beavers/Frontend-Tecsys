import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/widgets/asset_detail_sheet.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/navbar.dart';

void main() {
  testWidgets('Navbar renderiza abas corretamente', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: Navbar(currentIndex: 0),
        ),
      ),
    );

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Estudos'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('AssetDetailSheet exibe dados completos do ativo (Figma Tela 2)', (WidgetTester tester) async {
    const ativoTeste = AtivoBdgd(
      id: '1548123',
      codId: 'PON-381-1548123',
      tipo: TipoAtivo.poste,
      latitude: -18.9112,
      longitude: -48.2619,
      statusOperacional: 'Em operação',
      material: 'Concreto - Duplo T',
      esforcoTracao: '600 daN - 11 m',
      ordemImobilizacao: 'OI-2023-554812',
      situacaoAtivo: 'Ativo - sem restrições',
      subestacaoConectada: 'SE Boa Vista - 138 kV',
      pontoAcesso: 'PAC 10417',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssetDetailSheet(ativo: ativoTeste),
        ),
      ),
    );

    // Validação dos elementos do Figma
    expect(find.text('Poste'), findsOneWidget);
    expect(find.text('ID: 1548123'), findsOneWidget);
    expect(find.text('Em operação'), findsOneWidget);
    expect(find.text('-18.9112 / -48.2619'), findsOneWidget);
    expect(find.text('Concreto - Duplo T'), findsOneWidget);
    expect(find.text('600 daN - 11 m'), findsOneWidget);
    expect(find.text('OI-2023-554812'), findsOneWidget);
    expect(find.text('Ativo - sem restrições'), findsOneWidget);
    expect(find.text('SE Boa Vista - 138 kV'), findsOneWidget);
    expect(find.text('PAC 10417'), findsOneWidget);
  });

  testWidgets('LayerFilterModal renderiza grupos e contador (Figma Tela 3)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final camadasIniciais = CatalogoCamadas.obterEstadoInicialPadrao();
    Map<TipoAtivo, bool>? camadasSalvas;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerFilterModal(
            camadasAtivasAtuais: camadasIniciais,
            onSalvarFiltro: (novas) {
              camadasSalvas = novas;
            },
          ),
        ),
      ),
    );

    // Validação dos grupos do modal
    expect(find.text('Camadas'), findsOneWidget);
    expect(find.text('REDE'), findsOneWidget);
    expect(find.text('ESTRUTURAS'), findsOneWidget);
    expect(find.text('PROTEÇÃO E MANOBRA'), findsOneWidget);
    expect(find.text('REGULAÇÃO'), findsOneWidget);
    expect(find.text('7 de 12 camadas ativas'), findsOneWidget);
    expect(find.text('Salvar filtro'), findsOneWidget);

    // Acionar botão "Salvar filtro"
    await tester.tap(find.text('Salvar filtro'));
    await tester.pump();

    expect(camadasSalvas, isNotNull);
    expect(camadasSalvas![TipoAtivo.poste], isTrue);
  });
}
