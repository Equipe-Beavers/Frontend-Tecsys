import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';
import 'package:frontend_tecsys/pages/studies_page.dart';
import 'package:frontend_tecsys/pages/study_form.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/services/install_criterion_service.dart';
import 'package:frontend_tecsys/services/rf_profile_service.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/name_filter_field.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'support/criterion_test_support.dart';

void main() {
  testWidgets('seletor filtra pelo nome e limpa busca sem perder seleção', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => SelectionBottomSheet.show<int>(
              context: context,
              title: 'Selecionar registro',
              notFoundMessage: 'Nenhum registro encontrado',
              items: const [
                SelectionItem(
                  title: 'Perfil urbano',
                  subtitle: '915 MHz',
                  value: 1,
                ),
                SelectionItem(
                  title: 'Perfil rural',
                  subtitle: '868 MHz',
                  value: 2,
                ),
              ],
              selectedValue: 2,
              onSelected: (value) => selected = value,
            ),
            child: const Text('Abrir seletor'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir seletor'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar pelo nome'), findsOneWidget);
    expect(find.byType(NameFilterField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  URB  ');
    await tester.pump();
    expect(find.widgetWithText(ListTile, 'Perfil urbano'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Perfil rural'), findsNothing);
    await tester.enterText(find.byType(TextField), '915');
    await tester.pump();
    expect(find.text('Nenhum registro encontrado'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.widgetWithText(ListTile, 'Perfil urbano'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Perfil rural'), findsOneWidget);
    expect(find.byTooltip('Limpar busca'), findsNothing);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Prosseguir'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });

  EstudosService serviceWith(http.Response response) {
    final service = EstudosService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/estudos');
        return response;
      }),
    );
    addTearDown(service.dispose);
    return service;
  }

  test('carrega estudos conforme o contrato da API', () async {
    final service = serviceWith(
      http.Response(
        jsonEncode({
          'estudos': [
            {'id_estudo': 1, 'nome': 'Centro'},
          ],
        }),
        200,
      ),
    );
    expect((await service.list()).single['nome'], 'Centro');
  });

  test('filtra estudos pelo usuário solicitado', () async {
    final service = EstudosService(
      client: MockClient((request) async {
        expect(request.url.path, '/estudos');
        expect(request.url.queryParameters['id_usuario'], '9');
        return http.Response('{"estudos": []}', 200);
      }),
    );
    addTearDown(service.dispose);

    expect(await service.list(userId: 9), isEmpty);
  });

  test('cria ponto de estudo com relevo na rota do backend', () async {
    final ponto = NovoEstudoPonto(
      idEstudo: 81,
      latitude: -23.55,
      longitude: -46.63,
      relevoM: 760.4,
      rotulo: 'Vértice 1',
      indice: 0,
    );
    final service = EstudosService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/study/81/points');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'id_estudo': 81,
          'origem': 'manual',
          'id_ativo_bdgd': null,
          'tipo_ativo': null,
          'rotulo': 'Vértice 1',
          'papel': 'ambos',
          'prioridade': null,
          'latitude': -23.55,
          'longitude': -46.63,
          'atributos': {'tipo_ponto': 'vertice_area', 'indice': 0},
          'relevo_m': 760.4,
        });
        return http.Response(
          jsonEncode({
            'message': 'Ponto adicionado ao estudo com sucesso!',
            'data': {'id_estudo_ponto': 4},
          }),
          201,
        );
      }),
    );
    addTearDown(service.dispose);

    expect((await service.criarPontoEstudo(ponto))['id_estudo_ponto'], 4);
  });

  test('rejeita erros HTTP e respostas inválidas', () async {
    await expectLater(
      serviceWith(http.Response('Indisponível', 500)).list(),
      throwsStateError,
    );
    await expectLater(
      serviceWith(http.Response('{"estudos": {}}', 200)).list(),
      throwsFormatException,
    );
  });

  testWidgets('exibe estudos e filtra somente pelo nome', (tester) async {
    final service = serviceWith(
      http.Response(
        jsonEncode({
          'estudos': [
            {
              'nome': 'Testando',
              'municipio': 'São Paulo',
              'status': 'DEFINITIVO',
              'nome_criterio_instalacao': 'Critério urbano',
              'nome_perfil_rf': 'Perfil LoRa',
            },
            {
              'nome': 'Teste',
              'descricao': 'Testando',
              'municipio': 'Campinas',
              'uf': 'SP',
              'bairro': 'Centro',
              'distribuidora': 'Distribuidora local',
            },
          ],
        }),
        200,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudiesPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Testando'), findsOneWidget);
    expect(find.text('Teste'), findsOneWidget);
    expect(find.byType(NameFilterField), findsOneWidget);
    expect(find.text('Definitivo'), findsOneWidget);
    expect(find.text('Critério: Critério urbano'), findsOneWidget);
    expect(find.text('Perfil RF: Perfil LoRa'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  TANDO  ');
    await tester.pump();
    expect(find.text('Testando'), findsOneWidget);
    expect(find.text('Teste'), findsNothing);
    for (final query in [
      'campinas',
      'são paulo',
      'sp',
      'centro',
      'distribuidora local',
      'inexistente',
    ]) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
      expect(find.text('Testando'), findsNothing);
      expect(find.text('Teste'), findsNothing);
      expect(find.text('Nenhum estudo encontrado'), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), 'Testando');
    await tester.pump();
    expect(find.text('Teste'), findsNothing);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();
    expect(find.text('Testando'), findsOneWidget);
    expect(find.text('Teste'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('estudo sem delimitação não envia um polígono vazio', () {
    const study = NovoEstudo(
      idRfProfile: 1,
      idCriterioInstalacao: 1,
      pontosArea: [],
      nome: 'Centro',
    );
    expect(study.toJson()['geom'], isNull);
    expect(study.toJson()['id_perfil_rf'], 1);
  });

  testWidgets('salva dados do formulário com o perfil e critério escolhidos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rfService = RFProfileService(
      client: MockClient((request) async {
        expect(request.url.path, '/list-rf-profiles');
        expect(request.url.queryParameters['id_usuario'], '9');
        return jsonResponse({
          'data': [
            {
              'id_perfil_rf': 32,
              'id_usuario': 9,
              'nome': 'Perfil cadastrado',
              'frequencia_mhz': 915,
              'potencia_transmissao_dbm': 20,
              'sensibilidade_recepcao_dbm': -130,
            },
          ],
        }, 200);
      }),
    );
    final criterionService = InstallCriterionService(
      client: MockClient((request) async {
        expect(request.url.queryParameters['id_usuario'], '9');
        return jsonResponse({
          'data': [
            {
              ...fixture,
              'id_usuario': 9,
              'id_criterio_instalacao': 47,
              'nome': 'Critério cadastrado',
            },
          ],
        }, 200);
      }),
    );
    final payloads = <Map<String, dynamic>>[];
    final pontosPayloads = <Map<String, dynamic>>[];
    var requisicoesEstudo = 0;
    var requisicoesPonto = 0;
    final studyService = EstudosService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        final payload = Map<String, dynamic>.from(
          jsonDecode(request.body) as Map,
        );
        if (request.url.path == '/create-study') {
          payloads.add(payload);
          requisicoesEstudo++;
          return requisicoesEstudo == 1
              ? jsonResponse({'message': 'Falha de gravação'}, 500)
              : jsonResponse({
                  'estudo': {'id_estudo': 81},
                }, 201);
        }
        expect(request.url.path, '/study/81/points');
        pontosPayloads.add(payload);
        requisicoesPonto++;
        return requisicoesPonto == 1
            ? jsonResponse({'message': 'Falha ao salvar ponto'}, 400)
            : jsonResponse({
                'message': 'Ponto adicionado ao estudo com sucesso!',
                'data': {'id_estudo_ponto': 4},
              }, 201);
      }),
    );
    addTearDown(rfService.dispose);
    addTearDown(criterionService.dispose);
    addTearDown(studyService.dispose);
    bool? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NovoEstudoPage(
                      distribuidora: 'Distribuidora local',
                      municipio: null,
                      areaKm2: 0,
                      pontosArea: const [LatLng(-23.55, -46.63)],
                      relevoPontos: const [760.4],
                      userId: 9,
                      rfProfileService: rfService,
                      criterionService: criterionService,
                      studyService: studyService,
                    ),
                  ),
                );
              },
              child: const Text('Abrir formulário'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir formulário'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), ' Estudo local ');
    await tester.enterText(fields.at(1), ' Descrição local ');
    await tester.enterText(fields.at(2), 'São Paulo');
    await tester.enterText(fields.at(3), 'sp');
    await tester.enterText(fields.at(4), 'Centro');
    await tester.tap(find.text('Criar estudo e simular'));
    await tester.pumpAndSettle();
    expect(find.text('Selecione um perfil RF.'), findsOneWidget);
    expect(payloads, isEmpty);
    ScaffoldMessenger.of(tester.element(find.byType(NovoEstudoPage)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar perfil RF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil cadastrado'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Prosseguir'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil cadastrado'), findsOneWidget);
    await tester.tap(find.text('Criar estudo e simular'));
    await tester.pumpAndSettle();
    expect(find.text('Selecione um critério de instalação.'), findsOneWidget);
    expect(payloads, isEmpty);
    ScaffoldMessenger.of(tester.element(find.byType(NovoEstudoPage)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar critério'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critério cadastrado'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Prosseguir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar estudo e simular'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Falha de gravação'), findsOneWidget);
    expect(find.byType(NovoEstudoPage), findsOneWidget);
    expect(payloads.single, containsPair('id_perfil_rf', 32));
    expect(payloads.single, containsPair('id_criterio_instalacao', 47));
    expect(payloads.single, containsPair('id_usuario', 9));
    expect(payloads.single, containsPair('nome', 'Estudo local'));
    expect(payloads.single, containsPair('descricao', 'Descrição local'));
    expect(payloads.single, containsPair('municipio', 'São Paulo'));
    expect(payloads.single, containsPair('uf', 'SP'));
    expect(payloads.single, containsPair('bairro', 'Centro'));
    expect(
      payloads.single,
      containsPair('distribuidora', 'Distribuidora local'),
    );
    expect(payloads.last['geom'], isNotNull);
    ScaffoldMessenger.of(tester.element(find.byType(NovoEstudoPage)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar estudo e simular'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Estudo criado.'), findsOneWidget);
    expect(requisicoesEstudo, 2);
    expect(requisicoesPonto, 1);
    expect(pontosPayloads.single['relevo_m'], 760.4);
    expect(pontosPayloads.single['origem'], 'manual');
    expect(pontosPayloads.single['papel'], 'ambos');
    ScaffoldMessenger.of(tester.element(find.byType(NovoEstudoPage)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar salvamento'));
    await tester.pumpAndSettle();
    expect(created, isTrue);
    expect(find.byType(NovoEstudoPage), findsNothing);
    expect(payloads.length, 2);
    expect(pontosPayloads.length, 2);
    expect(requisicoesEstudo, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trata ausência de perfis e falha ao carregá-los', (
    tester,
  ) async {
    int requests = 0;
    final service = RFProfileService(
      client: MockClient((_) async {
        requests++;
        return requests == 1
            ? jsonResponse({'data': []}, 200)
            : jsonResponse({'message': 'Indisponível'}, 500);
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: NovoEstudoPage(
          distribuidora: '',
          municipio: null,
          areaKm2: 0,
          pontosArea: const [],
          rfProfileService: service,
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Selecionar perfil RF'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Selecionar perfil RF'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhum perfil RF cadastrado. Crie um na Biblioteca.'),
      findsOneWidget,
    );
    ScaffoldMessenger.of(tester.element(find.byType(NovoEstudoPage)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar perfil RF'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os perfis RF. Tente novamente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edita pelo menu, preenche campos e preserva dados não editáveis',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var study = <String, dynamic>{
        'id_estudo': 81,
        'id_usuario': 9,
        'id_perfil_rf': 32,
        'id_criterio_instalacao': 47,
        'nome': 'Estudo salvo',
        'descricao': 'Descrição salva',
        'municipio': 'São Paulo',
        'uf': 'SP',
        'bairro': 'Centro',
        'distribuidora': 'Distribuidora local',
        'status': 'DEFINITIVO',
        'versao_bdgd': '2026-10',
        'geom': {
          'type': 'Polygon',
          'coordinates': [
            [
              [-46.6, -23.5],
              [-46.5, -23.5],
              [-46.5, -23.4],
              [-46.6, -23.5],
            ],
          ],
        },
      };
      final payloads = <Map<String, dynamic>>[];
      final service = EstudosService(
        client: MockClient((request) async {
          if (request.method == 'PATCH') {
            expect(request.url.path, '/estudos/81');
            final values = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map,
            );
            payloads.add(values);
            if (payloads.length == 1) {
              return jsonResponse({'message': 'Falha ao atualizar'}, 500);
            }
            study = {...study, ...values};
            return jsonResponse({'estudo': study}, 200);
          }
          expect(request.method, 'GET');
          return request.url.path == '/estudos'
              ? jsonResponse({
                  'estudos': [study],
                }, 200)
              : jsonResponse({'estudo': study}, 200);
        }),
      );
      final rfService = RFProfileService(
        client: MockClient((request) async {
          expect(request.url.path, '/get-rf-profile/32');
          return jsonResponse({
            'data': {
              'id_perfil_rf': 32,
              'id_usuario': 9,
              'nome': 'Perfil salvo',
              'frequencia_mhz': 915,
              'potencia_transmissao_dbm': 20,
              'sensibilidade_recepcao_dbm': -130,
            },
          }, 200);
        }),
      );
      final criterionService = InstallCriterionService(
        client: MockClient((request) async {
          expect(request.url.path, '/get-install-criterion/47');
          return jsonResponse({
            'data': {
              ...fixture,
              'id_usuario': 9,
              'id_criterio_instalacao': 47,
              'nome': 'Critério salvo',
            },
          }, 200);
        }),
      );
      addTearDown(service.dispose);
      addTearDown(rfService.dispose);
      addTearDown(criterionService.dispose);
      await tester.pumpWidget(
        host(
          StudiesPage(
            service: service,
            rfProfileService: rfService,
            criterionService: criterionService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações de Estudo salvo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar estudo'), findsOneWidget);
      expect(find.text('Perfil salvo'), findsOneWidget);
      expect(find.text('Critério salvo'), findsOneWidget);
      expect(find.text('Área do estudo preservada'), findsOneWidget);
      final fields = find.byType(TextFormField);
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'Estudo salvo',
      );
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        'Descrição salva',
      );
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        'São Paulo',
      );
      expect(tester.widget<TextFormField>(fields.at(3)).controller!.text, 'SP');
      expect(
        tester.widget<TextFormField>(fields.at(4)).controller!.text,
        'Centro',
      );
      await tester.enterText(fields.at(0), ' Estudo revisado ');
      await tester.enterText(fields.at(1), '');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Falha ao atualizar'), findsOneWidget);
      expect(find.byType(NovoEstudoPage), findsOneWidget);
      expect(payloads.single, {
        'id_perfil_rf': 32,
        'id_criterio_instalacao': 47,
        'nome': 'Estudo revisado',
        'descricao': null,
        'uf': 'SP',
        'municipio': 'São Paulo',
        'bairro': 'Centro',
      });
      ScaffoldMessenger.of(tester.element(find.byType(NovoEstudoPage)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(find.byType(NovoEstudoPage), findsNothing);
      expect(find.text('Estudo revisado'), findsOneWidget);
      expect(study['geom'], isNotNull);
      expect(study['status'], 'DEFINITIVO');
      expect(study['versao_bdgd'], '2026-10');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exclusão exige confirmação e atualiza a lista', (tester) async {
    bool deleted = false;
    int deleteRequests = 0;
    final service = EstudosService(
      client: MockClient((request) async {
        if (request.method == 'DELETE') {
          expect(request.url.path, '/estudos/81');
          deleteRequests++;
          deleted = true;
          return http.Response('', 204);
        }
        return jsonResponse({
          'estudos': deleted
              ? []
              : [
                  {'id_estudo': 81, 'nome': 'Estudo salvo'},
                ],
        }, 200);
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(host(StudiesPage(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações de Estudo salvo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir estudo?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleteRequests, 0);
    expect(find.text('Estudo salvo'), findsOneWidget);
    await tester.tap(find.byTooltip('Ações de Estudo salvo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(deleteRequests, 1);
    expect(find.text('Nenhum estudo cadastrado'), findsOneWidget);
    expect(find.text('Estudo excluído.'), findsOneWidget);
  });

  testWidgets('mantém estudo quando há dependências que impedem excluir', (
    tester,
  ) async {
    final service = EstudosService(
      client: MockClient((request) async {
        return request.method == 'DELETE'
            ? jsonResponse({
                'message': 'Estudo vinculado a outros registros.',
              }, 409)
            : jsonResponse({
                'estudos': [
                  {'id_estudo': 81, 'nome': 'Estudo salvo'},
                ],
              }, 200);
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(host(StudiesPage(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações de Estudo salvo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Estudo salvo'), findsOneWidget);
    expect(find.text('Estudo vinculado a outros registros.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abre formulário e atualiza a lista após criação', (
    tester,
  ) async {
    int requests = 0;
    final service = EstudosService(
      client: MockClient((_) async {
        requests++;
        return http.Response('{"estudos": []}', 200);
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudiesPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Atualizar estudos'), findsNothing);
    await tester.tap(find.text('Novo estudo'));
    await tester.pumpAndSettle();
    expect(find.byType(NovoEstudoPage), findsOneWidget);
    expect(find.text('Área não definida'), findsOneWidget);
    expect(find.text('PASSO 4 DE 4'), findsNothing);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(NovoEstudoPage))).pop(true);
    await tester.pumpAndSettle();
    expect(requests, 2);
  });

  testWidgets('exibe lista vazia', (tester) async {
    final service = serviceWith(http.Response('{"estudos": []}', 200));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudiesPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum estudo cadastrado'), findsOneWidget);
  });

  testWidgets('permite tentar novamente após falha', (tester) async {
    int requests = 0;
    final service = EstudosService(
      client: MockClient((_) async {
        requests++;
        return requests == 1
            ? http.Response('', 500)
            : http.Response('{"estudos": []}', 200);
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudiesPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar os estudos'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum estudo cadastrado'), findsOneWidget);
    expect(requests, 2);
  });
}
