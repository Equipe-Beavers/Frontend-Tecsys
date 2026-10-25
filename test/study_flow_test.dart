import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/widgets/city_bairro_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/study_area_step.dart';
import 'package:frontend_tecsys/widgets/study_location_step.dart';

void main() {
  testWidgets('localização não pode ser aberta antes da distribuidora', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyLocationStep(
            distribuidoras: const [],
            ativos: const [],
            distribuidoraSelecionada: null,
            municipioSelecionado: null,
            bairroSelecionado: null,
            localizacaoHabilitada: false,
            onDistribuidoraChanged: (_) {},
            onLocationConfirmed: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cidade / bairro'));
    await tester.pump();

    expect(
      find.text(
        'Selecione uma distribuidora e aguarde o carregamento dos ativos.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CidadeBairroBottomSheet), findsNothing);
  });

  testWidgets('município é obrigatório para confirmar a localização', (
    tester,
  ) async {
    String? municipioConfirmado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CidadeBairroBottomSheet(
            cidades: const [],
            bairrosPorCidade: const {},
            allowEmptySelection: false,
            onProsseguir: (municipio, _) {
              municipioConfirmado = municipio;
            },
          ),
        ),
      ),
    );

    final continuar = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Prosseguir'),
    );

    expect(continuar.onPressed, isNull);
    expect(municipioConfirmado, isNull);
  });

  testWidgets('etapa de distribuidora pode avançar sem opções carregadas', (
    tester,
  ) async {
    String? distribuidoraConfirmada = 'não avançou';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionBottomSheet<String>(
            title: 'Distribuidora',
            items: const [],
            selectedValue: null,
            onSelected: (distribuidora) {
              distribuidoraConfirmada = distribuidora;
            },
          ),
        ),
      ),
    );

    final continuar = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Prosseguir'),
    );
    expect(continuar.onPressed, isNotNull);

    await tester.tap(find.text('Prosseguir'));
    await tester.pump();

    expect(distribuidoraConfirmada, isNull);
  });

  testWidgets('localização vazia permite avançar para demonstrar o desenho', (
    tester,
  ) async {
    String? municipioConfirmado = 'não avançou';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CidadeBairroBottomSheet(
            cidades: const [],
            bairrosPorCidade: const {},
            allowEmptySelection: true,
            onProsseguir: (municipio, _) {
              municipioConfirmado = municipio;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Prosseguir'));
    await tester.pump();

    expect(municipioConfirmado, isNull);
  });

  testWidgets('confirmação de cidade encaminha ao próximo passo', (
    tester,
  ) async {
    String? municipioConfirmado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CidadeBairroBottomSheet(
            cidades: const ['Cidade A'],
            bairrosPorCidade: const {
              'Cidade A': ['Centro'],
            },
            allowEmptySelection: false,
            onProsseguir: (municipio, _) {
              municipioConfirmado = municipio;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cidade A'));
    await tester.pump();
    await tester.tap(find.text('Centro'));
    await tester.pump();
    await tester.tap(find.text('Prosseguir'));
    await tester.pump();

    expect(municipioConfirmado, 'Cidade A');
  });

  testWidgets('etapa da área só oferece prosseguir com área desenhada', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyAreaStep(
            locationLabel: 'CEMIG · Uberaba · Zona Oeste',
            areaDesenhada: false,
            areaKm2: 0,
            ativosNaArea: 0,
            onCancelar: _noop,
            onRefazer: _noop,
            onProsseguir: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Selecionar área'), findsOneWidget);
    expect(find.text('PASSO 3 DE 4'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('Prosseguir'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyAreaStep(
            locationLabel: 'CEMIG · Uberaba · Zona Oeste',
            areaDesenhada: true,
            areaKm2: 38.4,
            ativosNaArea: 1956,
            onCancelar: _noop,
            onRefazer: _noop,
            onProsseguir: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Prosseguir'), findsOneWidget);
    expect(find.text('Área selecionada'), findsOneWidget);
    expect(find.text('Refazer'), findsOneWidget);
    expect(find.text('38,4 km²'), findsOneWidget);
    expect(find.text('1.956'), findsOneWidget);
  });

  testWidgets('desenho está ativo sem botão e permite refazer/avançar', (
    tester,
  ) async {
    var redone = false;
    var proceeded = false;

    Widget buildStep({required bool areaDesenhada}) {
      return MaterialApp(
        home: Scaffold(
          body: StudyAreaStep(
            locationLabel: '',
            areaDesenhada: areaDesenhada,
            areaKm2: areaDesenhada ? 2 : 0,
            ativosNaArea: 0,
            onCancelar: _noop,
            onRefazer: () => redone = true,
            onProsseguir: () => proceeded = true,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildStep(areaDesenhada: true));
    expect(find.text('Desenhar'), findsNothing);
    expect(find.text('Concluir desenho'), findsNothing);
    await tester.tap(find.text('Refazer'));
    expect(redone, isTrue);
    await tester.tap(find.text('Prosseguir'));
    expect(proceeded, isTrue);
  });
}

void _noop() {}
