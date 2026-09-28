import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/pages/estudos_page.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/widgets/asset_detail_sheet.dart';
import 'package:frontend_tecsys/widgets/layer_filter_modal.dart';
import 'package:frontend_tecsys/widgets/navbar.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Navbar renderiza abas corretamente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(bottomNavigationBar: Navbar(currentIndex: 0)),
      ),
    );

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Estudos'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets(
    'AssetDetailSheet exibe dados completos do ativo (Figma Tela 2)',
    (WidgetTester tester) async {
      const ativoTeste = AtivoBdgd(
        id: '1548123',
        codId: 'PON-381-1548123',
        tipo: TipoAtivo.poste,
        latitude: -18.9112,
        longitude: -48.2619,
        statusOperacional: 'Em operação',
        material: 'Concreto - Duplo T',
        esforcoTracao: '600 daN - 11 m',
        altura: '12',
        situacaoAtivo: 'Ativo - sem restrições',
        subestacaoConectada: 'SE Boa Vista - 138 kV',
        municipio: 'Uberlândia',
        distribuidora: 'Enel SP',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AssetDetailSheet(ativo: ativoTeste)),
        ),
      );

      // Validação dos elementos do Figma
      expect(find.text('Poste'), findsOneWidget);
      expect(find.text('ID: 1548123'), findsOneWidget);
      expect(find.text('Em operação'), findsOneWidget);
      expect(find.text('-18.9112 / -48.2619'), findsOneWidget);
      expect(find.text('Concreto - Duplo T'), findsOneWidget);
      expect(find.text('600 daN - 11 m'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('SE Boa Vista - 138 kV'), findsOneWidget);
      expect(find.text('Uberlândia'), findsOneWidget);
      expect(find.text('Enel SP'), findsOneWidget);
    },
  );

  testWidgets('LayerFilterModal renderiza grupos e contador (Figma Tela 3)', (
    WidgetTester tester,
  ) async {
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
    expect(find.text('ESTRUTURAS'), findsOneWidget);
    expect(find.text('PROTEÇÃO E MANOBRA'), findsOneWidget);
    expect(find.text('REGULAÇÃO'), findsOneWidget);
    expect(find.text('0 de 10 camadas ativas'), findsOneWidget);
    expect(find.text('Salvar filtro'), findsOneWidget);

    // Todas as camadas iniciam desmarcadas
    for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(checkbox.value, isFalse);
    }

    // Marca a primeira camada (Poste) e confirma a contagem
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('1 de 10 camadas ativas'), findsOneWidget);

    // Acionar botão "Salvar filtro"
    await tester.tap(find.text('Salvar filtro'));
    await tester.pump();

    expect(camadasSalvas, isNotNull);
    expect(camadasSalvas![TipoAtivo.poste], isTrue);
    expect(camadasSalvas![TipoAtivo.transformador], isFalse);
  });

  testWidgets('Limpar zera as checkboxes de todos os grupos', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerFilterModal(
            camadasAtivasAtuais: CatalogoCamadas.obterEstadoInicialPadrao(),
            onSalvarFiltro: (_) {},
          ),
        ),
      ),
    );

    // Marca uma camada de cada grupo: Estruturas, Proteção e Regulação.
    await tester.tap(find.text('Poste'));
    await tester.pump();
    await tester.tap(find.text('Religador'));
    await tester.pump();
    await tester.tap(find.text('Regulador de Tensão'));
    await tester.pump();
    expect(find.text('3 de 10 camadas ativas'), findsOneWidget);

    await tester.tap(find.text('Limpar'));
    await tester.pump();

    expect(find.text('0 de 10 camadas ativas'), findsOneWidget);
    for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(checkbox.value, isFalse);
    }
  });

  testWidgets('Spinner do AppBar do Estudos não fica preso após recarregar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      final url = request.url.path;
      if (url.contains('estudo-pontos')) {
        return http.Response('{"pontos": []}', 200);
      }
      return http.Response('{"estudos": []}', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EstudosPage(estudosService: EstudosService(client: client)),
      ),
    );

    // Carga inicial pendente: ícone de refresh ainda no AppBar.
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    // Carga inicial conclui -> lista vazia, sem spinner preso.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Nenhum estudo cadastrado'), findsOneWidget);

    // Recarregar: _atualizando = true -> refresh vira spinner nos dois pontos.
    final state = tester.state<EstudosPageState>(find.byType(EstudosPage));
    final recarga = state.recarregar();
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Conclui -> _atualizando = false e o ícone volta.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await recarga;

    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Nenhum estudo cadastrado'), findsOneWidget);
  });
}
