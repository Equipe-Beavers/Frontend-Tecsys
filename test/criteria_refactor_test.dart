import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend_tecsys/controllers/criteria_page_controller.dart';
import 'package:frontend_tecsys/models/install_criterion.dart';
import 'package:frontend_tecsys/models/install_criterion_draft.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';
import 'package:frontend_tecsys/pages/library_page.dart';
import 'package:frontend_tecsys/pages/study_form.dart';
import 'package:frontend_tecsys/pages/rf_profile_form.dart';
import 'package:frontend_tecsys/services/install_criterion_service.dart';
import 'package:frontend_tecsys/services/rf_profile_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/name_filter_field.dart';

import 'support/criterion_test_support.dart';

Map<String, dynamic> item(int id) => {
  ...fixture,
  'id_criterio_instalacao': id,
  'nome': 'Critério $id',
};
List<Map<String, dynamic>> firstPage() =>
    List.generate(20, (index) => item(index + 1));

void main() {
  for (final rfProfiles in [false, true]) {
    testWidgets(
      '${rfProfiles ? 'RF' : 'criteria'} shared filter searches all pages by name and clears',
      (tester) async {
        final requestedPages = <int>[];
        final criteriaService = InstallCriterionService(
          client: MockClient((request) async {
            final page = int.parse(request.url.queryParameters['page']!);
            if (!rfProfiles) requestedPages.add(page);
            return jsonResponse({
              'data': page == 1
                  ? firstPage()
                  : [
                      {...item(21), 'nome': 'Alvo remoto'},
                    ],
            }, 200);
          }),
        );
        final rfService = RFProfileService(
          client: MockClient((request) async {
            final page = int.parse(request.url.queryParameters['page']!);
            requestedPages.add(page);
            Map<String, dynamic> profile(int id, String name) => {
              'id_perfil_rf': id,
              'id_usuario': 1,
              'nome': name,
              'frequencia_mhz': 915,
              'potencia_transmissao_dbm': 14,
              'sensibilidade_recepcao_dbm': -120,
            };
            return jsonResponse({
              'data': page == 1
                  ? List.generate(
                      20,
                      (index) => profile(index + 1, 'Perfil ${index + 1}'),
                    )
                  : [profile(21, 'Alvo remoto')],
            }, 200);
          }),
        );
        addTearDown(criteriaService.dispose);
        addTearDown(rfService.dispose);
        await tester.pumpWidget(
          host(
            CriteriaLibraryPage(
              service: criteriaService,
              rfProfileService: rfService,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (rfProfiles) {
          await tester.tap(find.text('Perfis de RF'));
          await tester.pumpAndSettle();
        }
        expect(requestedPages, [1]);
        expect(find.byType(NameFilterField), findsOneWidget);
        await tester.enterText(find.byType(TextField), '  ALVO  ');
        await tester.pumpAndSettle();
        expect(requestedPages, [1, 1, 2]);
        expect(find.text('Alvo remoto'), findsOneWidget);
        expect(find.text(rfProfiles ? 'Perfil 1' : 'Critério 1'), findsNothing);
        expect(find.byTooltip('Próxima página'), findsNothing);
        await tester.enterText(
          find.byType(TextField),
          rfProfiles ? '915' : '1500',
        );
        await tester.pumpAndSettle();
        expect(find.text('Alvo remoto'), findsNothing);
        expect(
          find.text(
            rfProfiles
                ? 'Nenhum perfil RF encontrado'
                : 'Nenhum critério encontrado',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Limpar busca'));
        await tester.pumpAndSettle();
        expect(
          find.text(rfProfiles ? 'Perfil 1' : 'Critério 1'),
          findsOneWidget,
        );
        expect(find.byTooltip('Próxima página'), findsOneWidget);
        expect(find.byTooltip('Limpar busca'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'newer name search supersedes a pending search and stops paging',
    () async {
      final pending = Completer<http.Response>();
      var requests = 0;
      final service = InstallCriterionService(
        client: MockClient((_) async {
          requests++;
          if (requests == 1) return pending.future;
          return jsonResponse({
            'data': [
              {...item(22), 'nome': 'Busca recente'},
            ],
          }, 200);
        }),
      );
      final controller = CriteriaPageController(service: service, userId: 1);
      addTearDown(controller.dispose);
      addTearDown(service.dispose);
      final oldSearch = controller.search('Critério');
      await controller.search('recente');
      pending.complete(jsonResponse({'data': firstPage()}, 200));
      await oldSearch;
      expect(controller.items.single.name, 'Busca recente');
      expect(requests, 2);
      expect(controller.loading, false);
    },
  );

  test('typed model parses database scalars and preserves unedited JSON', () {
    final criterion = InstallCriterion.fromJson({
      ...fixture,
      'id_criterio_instalacao': '7',
      'distancia_maxima_ativos_m': '1500.25',
      'requer_alimentacao_eletrica': false,
      'relevo': {'altitude_minima_m': 5.5},
      'criado_em': '2026-10-06T10:00:00',
      'tipos_elementos_permitidos': {
        'ids': [10, 20],
      },
    });
    expect(criterion.id, 7);
    expect(criterion.maxDistanceMeters, 1500.25);
    expect(criterion.requiresPower, false);
    expect(criterion.relief, {'altitude_minima_m': 5.5});
    expect(criterion.createdAt?.year, 2026);
    final draft = InstallCriterionDraft(original: criterion)
      ..name = 'Nome revisado';
    expect(
      draft.toPayload(userId: 1).containsKey('tipos_elementos_permitidos'),
      false,
    );
    expect(
      draft.preservesStructuredSelection(CriterionCollection.allowedTypes),
      true,
    );
    expect(
      () => InstallCriterion.fromJson({
        ...fixture,
        'id_criterio_instalacao': 1.5,
      }),
      throwsFormatException,
    );
    expect(
      () => InstallCriterion.fromJson({
        ...fixture,
        'distancia_maxima_ativos_m': 'invalid',
      }),
      throwsFormatException,
    );
  });

  test('draft updates asset types and preserves unrelated values', () {
    final draft = InstallCriterionDraft(
      original: InstallCriterion.fromJson(fixture),
    );
    draft.setTypes(CriterionCollection.allowedTypes, ['POSTE', 'SUBESTACAO']);
    final payload = draft.toPayload(userId: 1);
    expect(payload['tipos_elementos_permitidos'], ['POSTE', 'SUBESTACAO']);
    expect(payload.containsKey('tipos_elementos_proibidos'), false);
    expect(payload.containsKey('locais_autorizados'), false);
    expect(payload.containsKey('locais_obrigatorios'), false);
    expect(payload.containsKey('locais_proibidos'), false);
    expect(payload.containsKey('id_usuario'), false);
    expect(InstallCriterionDraft.validateGatewayLimit('2147483648'), isNotNull);
    expect(InstallCriterionDraft.validateGatewayLimit('1.5'), isNotNull);
    expect(InstallCriterionDraft.validateGatewayLimit(''), isNull);
  });

  test('pagination preserves the visible page on errors and retries requested page', () async {
    var fail = true;
    final requests = <int>[];
    final service = InstallCriterionService(
      client: MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        requests.add(page);
        expect(request.url.queryParameters['limit'], '20');
        if (page == 2 && fail) return http.Response('{}', 500);
        return jsonResponse({
          'data': page == 1 ? firstPage() : [item(21)],
        }, 200);
      }),
    );
    final controller = CriteriaPageController(service: service, userId: 1);
    addTearDown(() {
      controller.dispose();
      service.dispose();
    });
    await controller.load();
    expect(requests, [1]);
    await controller.load(targetPage: 2);
    expect(controller.page, 1);
    expect(controller.items.first.id, 1);
    expect(controller.error, isNotNull);
    fail = false;
    await controller.retry();
    expect(requests, [1, 2, 2]);
    expect(controller.page, 2);
    expect(controller.items.single.id, 21);
    expect(controller.hasNext, false);
  });

  test('stale responses do not overwrite a newer page request', () async {
    final responses = [Completer<http.Response>(), Completer<http.Response>()];
    var index = 0;
    final service = InstallCriterionService(
      client: MockClient((_) => responses[index++].future),
    );
    final controller = CriteriaPageController(service: service, userId: 1);
    addTearDown(() {
      controller.dispose();
      service.dispose();
    });
    final oldLoad = controller.load();
    final newLoad = controller.load(targetPage: 2);
    responses[1].complete(
      jsonResponse({
        'data': [item(21)],
      }, 200),
    );
    await newLoad;
    responses[0].complete(jsonResponse({'data': firstPage()}, 200));
    await oldLoad;
    expect(controller.page, 2);
    expect(controller.items.single.id, 21);
    expect(controller.loading, false);
  });

  test('empty trailing pages and deletion of the last item recover to previous page', () async {
    var lastDeleted = false;
    final service = InstallCriterionService(
      client: MockClient((request) async {
        final page = request.url.queryParameters['page'];
        return jsonResponse({
          'data': page == '1'
              ? firstPage()
              : lastDeleted
              ? []
              : [item(21)],
        }, 200);
      }),
    );
    final controller = CriteriaPageController(service: service, userId: 1);
    addTearDown(() {
      controller.dispose();
      service.dispose();
    });
    await controller.load(targetPage: 2);
    lastDeleted = true;
    await controller.load();
    expect(controller.page, 1);
    expect(controller.items.length, 20);
    await controller.load(targetPage: 2);
    expect(controller.page, 1);
    expect(controller.items.length, 20);
    expect(controller.hasNext, false);
  });

  testWidgets(
    'library fetches next page only when requested and supports returning',
    (tester) async {
      final pages = <String>[];
      final service = InstallCriterionService(
        client: MockClient((request) async {
          final page = request.url.queryParameters['page']!;
          pages.add(page);
          return jsonResponse({
            'data': page == '1' ? firstPage() : [item(21)],
          }, 200);
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(host(CriteriaLibraryPage(service: service)));
      await tester.pumpAndSettle();
      expect(pages, ['1']);
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pumpAndSettle();
      expect(find.text('Critério 21'), findsOneWidget);
      expect(find.text('Critério 1'), findsNothing);
      await tester.tap(find.byTooltip('Página anterior'));
      await tester.pumpAndSettle();
      expect(pages, ['1', '2', '1']);
      expect(find.text('Critério 1'), findsOneWidget);
    },
  );

  testWidgets(
    'study criterion picker uses library pages and the shared model',
    (tester) async {
      final service = InstallCriterionService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['id_usuario'], '9');
          return jsonResponse({
            'data': request.url.queryParameters['page'] == '1'
                ? firstPage()
                : [item(21)],
          }, 200);
        }),
      );

      addTearDown(service.dispose);
      await tester.pumpWidget(
        host(
          NovoEstudoPage(
            distribuidora: 'Teste',
            municipio: null,
            areaKm2: 1,
            pontosArea: const [],
            criterionService: service,
            userId: 9,
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Selecionar critério'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Selecionar critério'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Critério 21');
      await tester.pump();
      await tester.tap(find.widgetWithText(ListTile, 'Critério 21'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Prosseguir'));
      await tester.pumpAndSettle();
      expect(find.text('Critério 21'), findsOneWidget);
      expect(find.text('Dist. máx. 1500 m'), findsOneWidget);
      expect(find.textContaining('Altura mín.'), findsNothing);
      expect(
        const NovoEstudo(
          idRfProfile: 1,
          nome: 'Teste',
          pontosArea: [],
          idCriterioInstalacao: 21,
        ).toJson()['id_criterio_instalacao'],
        21,
      );
    },
  );

  testWidgets('RF tab loads profiles and creates a profile from the form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final criteriaService = InstallCriterionService(
      client: MockClient(
        (_) async => jsonResponse({'data': [], 'page': 1, 'limit': 20}, 200),
      ),
    );
    final rfRequests = <http.Request>[];
    final savedProfile = <String, dynamic>{
      'id_perfil_rf': 9,
      'id_usuario': 9,
      'nome': 'GW-9200 LoRaWAN',
      'frequencia_mhz': 915,
      'potencia_transmissao_dbm': 8,
      'sensibilidade_recepcao_dbm': -120,
      'altura_gateway_m': 6,
      'altura_dispositivo_m': 5,
      'capacidade_max_equipamentos': 1200,
      'atenuacao_adicional_db': 4.2,
      'considera_relevo': true,
      'considera_vegetacao': true,
      'considera_edificacoes': true,
      'considera_antenas': true,
    };
    Map<String, dynamic>? submittedPayload;
    var saved = false;
    final rfService = RFProfileService(
      baseUrl: 'http://example.test/',
      client: MockClient((request) async {
        rfRequests.add(request);
        if (request.method == 'POST') {
          submittedPayload = jsonDecode(request.body) as Map<String, dynamic>;
          saved = true;
          return jsonResponse({'data': savedProfile}, 201);
        }
        return jsonResponse({
          'data': saved
              ? [savedProfile]
              : [
                  {
                    ...savedProfile,
                    'id_perfil_rf': 8,
                    'nome': 'LoRa urbano',
                    'potencia_transmissao_dbm': 21,
                    'capacidade_max_equipamentos': 40,
                    'atenuacao_adicional_db': null,
                    'considera_edificacoes': false,
                  },
                ],
          'page': 1,
          'limit': 20,
        }, 200);
      }),
    );
    addTearDown(criteriaService.dispose);
    addTearDown(rfService.dispose);

    await tester.pumpWidget(
      host(
        CriteriaLibraryPage(
          service: criteriaService,
          rfProfileService: rfService,
          userId: 9,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Novo critério'), findsOneWidget);
    expect(find.text('Novo Perfil RF'), findsNothing);
    await tester.tap(find.text('Perfis de RF'));
    await tester.pumpAndSettle();

    expect(rfRequests, hasLength(1));
    expect(rfRequests.single.url.path, '/list-rf-profiles');
    expect(rfRequests.single.url.queryParameters['id_usuario'], '9');
    expect(find.text('LoRa urbano'), findsOneWidget);
    expect(find.text('Novo critério'), findsNothing);
    expect(find.text('Novo Perfil RF'), findsOneWidget);

    await tester.tap(find.text('Novo Perfil RF'));
    await tester.pumpAndSettle();
    expect(find.text('Novo perfil de RF'), findsOneWidget);
    expect(find.text('Alcance estimado'), findsNWidgets(2));

    Future<void> enterField(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await enterField('Nome', 'GW-9200 LoRaWAN');
    await enterField('Frequência', '915');
    await enterField('Potência de transmissão', '8');
    await enterField('Sensibilidade de recepção', '-120');
    await enterField('Atenuação adicional', '4.2');
    await enterField('Altura do gateway em relação ao solo', '6');
    await enterField('Altura do dispositivo em relação ao solo', '5');
    await enterField('Máx. equipamentos atendidos', '1200');
    await tester.tap(find.text('Salvar perfil'));
    await tester.pumpAndSettle();
    expect(
      rfRequests.where((request) => request.method == 'POST'),
      hasLength(1),
    );
    expect(submittedPayload, {
      'id_usuario': 9,
      'nome': 'GW-9200 LoRaWAN',
      'frequencia_mhz': 915,
      'potencia_transmissao_dbm': 8,
      'sensibilidade_recepcao_dbm': -120,
      'altura_gateway_m': 6,
      'altura_dispositivo_m': 5,
      'capacidade_max_equipamentos': 1200,
      'atenuacao_adicional_db': 4.2,
      'considera_relevo': true,
      'considera_vegetacao': true,
      'considera_edificacoes': true,
      'considera_antenas': true,
    });
    expect(find.text('GW-9200 LoRaWAN'), findsOneWidget);
    expect(
      rfRequests.where((request) => request.method == 'GET'),
      hasLength(2),
    );
  });

  testWidgets('RF profile form fits mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(RFProfileForm(userId: 1, onClose: () {}, onSave: (_) async {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Novo perfil de RF'), findsOneWidget);
    expect(find.text('Salvar perfil'), findsOneWidget);
    for (final label in [
      'Frequência',
      'Potência de transmissão',
      'Altura do gateway em relação ao solo',
      'Altura do dispositivo em relação ao solo',
    ]) {
      final decorator = find.descendant(
        of: find.widgetWithText(TextFormField, label),
        matching: find.byType(InputDecorator),
      );
      expect(
        tester.widget<InputDecorator>(decorator.first).decoration.fillColor,
        AppColors.surfaceBackground,
      );
    }
    final nameDecorator = find.descendant(
      of: find.widgetWithText(TextFormField, 'Nome'),
      matching: find.byType(InputDecorator),
    );
    expect(
      tester.widget<InputDecorator>(nameDecorator.first).decoration.fillColor,
      AppColors.surfaceCardLight,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('RF profile card confirms deletion and refreshes the list', (
    tester,
  ) async {
    var deleted = false;
    final criteriaService = InstallCriterionService(
      client: MockClient(
        (_) async => jsonResponse({'data': [], 'page': 1, 'limit': 20}, 200),
      ),
    );
    final rfRequests = <http.Request>[];
    final rfService = RFProfileService(
      baseUrl: 'http://example.test/',
      client: MockClient((request) async {
        rfRequests.add(request);
        if (request.method == 'DELETE') {
          deleted = true;
          return http.Response('', 204);
        }
        return jsonResponse({
          'data': deleted
              ? []
              : [
                  {
                    'id_perfil_rf': 8,
                    'id_usuario': 9,
                    'nome': 'LoRa urbano',
                    'frequencia_mhz': 915,
                    'potencia_transmissao_dbm': 21,
                    'sensibilidade_recepcao_dbm': -120,
                    'considera_relevo': true,
                    'considera_vegetacao': true,
                    'considera_edificacoes': true,
                    'considera_antenas': true,
                  },
                ],
          'page': 1,
          'limit': 20,
        }, 200);
      }),
    );
    addTearDown(criteriaService.dispose);
    addTearDown(rfService.dispose);

    await tester.pumpWidget(
      host(
        CriteriaLibraryPage(
          service: criteriaService,
          rfProfileService: rfService,
          userId: 9,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfis de RF'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações de LoRa urbano'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir perfil RF?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Excluir'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      rfRequests.any(
        (request) =>
            request.method == 'DELETE' &&
            request.url.path == '/delete-rf-profile/8',
      ),
      isTrue,
    );
    expect(find.text('Nenhum perfil RF cadastrado'), findsOneWidget);
    expect(find.text('Perfil RF excluído.'), findsOneWidget);
  });

  testWidgets('RF profile card opens prefilled form and updates by ID', (
    tester,
  ) async {
    final profile = <String, dynamic>{
      'id_perfil_rf': 8,
      'id_usuario': 9,
      'nome': 'LoRa urbano',
      'frequencia_mhz': 915,
      'potencia_transmissao_dbm': 21,
      'sensibilidade_recepcao_dbm': -120,
      'altura_gateway_m': 6.5,
      'altura_dispositivo_m': 5.5,
      'capacidade_max_equipamentos': 40,
      'atenuacao_adicional_db': 3.2,
      'considera_relevo': true,
      'considera_vegetacao': false,
      'considera_edificacoes': true,
      'considera_antenas': false,
    };
    final requests = <http.Request>[];
    final criteriaService = InstallCriterionService(
      client: MockClient(
        (_) async => jsonResponse({'data': [], 'page': 1, 'limit': 20}, 200),
      ),
    );
    final rfService = RFProfileService(
      baseUrl: 'http://example.test/',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/list-rf-profiles') {
          return jsonResponse({
            'data': [profile],
            'page': 1,
            'limit': 20,
          }, 200);
        }
        if (request.method == 'GET' &&
            request.url.path == '/get-rf-profile/8') {
          return jsonResponse({'data': profile}, 200);
        }
        if (request.method == 'PATCH') {
          return jsonResponse({'data': profile}, 200);
        }
        return jsonResponse({'message': 'Requisição inesperada.'}, 500);
      }),
    );
    addTearDown(criteriaService.dispose);
    addTearDown(rfService.dispose);

    await tester.pumpWidget(
      host(
        CriteriaLibraryPage(
          service: criteriaService,
          rfProfileService: rfService,
          userId: 9,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfis de RF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LoRa urbano'));
    await tester.pumpAndSettle();

    expect(
      requests.any((request) => request.url.path == '/get-rf-profile/8'),
      isTrue,
    );
    expect(find.text('Editar perfil de RF'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Nome'))
          .controller!
          .text,
      'LoRa urbano',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Frequência'),
          )
          .controller!
          .text,
      '915',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Atenuação adicional'),
          )
          .controller!
          .text,
      '3,2',
    );
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, false);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome'),
      'LoRa urbano revisado',
    );
    await tester.tap(find.text('Salvar perfil'));
    await tester.pumpAndSettle();

    final patch = requests.singleWhere((request) => request.method == 'PATCH');
    expect(patch.url.path, '/update-rf-profile/8');
    expect(jsonDecode(patch.body)['nome'], 'LoRa urbano revisado');
    expect(jsonDecode(patch.body).containsKey('id_usuario'), isFalse);
    expect(
      requests.any((request) => request.url.path == '/list-rf-profiles'),
      isTrue,
    );
  });
}
