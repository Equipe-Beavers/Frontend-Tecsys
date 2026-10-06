import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend_tecsys/controllers/criteria_page_controller.dart';
import 'package:frontend_tecsys/models/install_criterion.dart';
import 'package:frontend_tecsys/models/install_criterion_draft.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';
import 'package:frontend_tecsys/pages/criteria_library_page.dart';
import 'package:frontend_tecsys/pages/novo_estudo_page.dart';
import 'package:frontend_tecsys/services/install_criterion_service.dart';

import 'support/criterion_test_support.dart';

Map<String, dynamic> item(int id) => {
  ...fixture,
  'id_criterio_instalacao': id,
  'nome': 'Critério $id',
};
List<Map<String, dynamic>> firstPage() =>
    List.generate(20, (index) => item(index + 1));

void main() {
  test('typed model parses database scalars and preserves unedited JSON', () {
    final criterion = InstallCriterion.fromJson({
      ...fixture,
      'id_criterio_instalacao': '7',
      'distancia_maxima_ativos_m': '1500.25',
      'requer_alimentacao_eletrica': false,
      'criado_em': '2026-10-06T10:00:00',
      'locais_autorizados': {
        'ids': [10, 20],
      },
    });
    expect(criterion.id, 7);
    expect(criterion.maxDistanceMeters, 1500.25);
    expect(criterion.requiresPower, false);
    expect(criterion.createdAt?.year, 2026);
    final draft = InstallCriterionDraft(original: criterion)
      ..name = 'Nome revisado';
    expect(draft.toPayload(userId: 1).containsKey('locais_autorizados'), false);
    expect(
      draft.preservesStructuredSelection(
        CriterionCollection.authorizedLocations,
      ),
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

  test('draft moves conflicting types, normalizes locations and preserves unrelated JSON', () {
    final draft = InstallCriterionDraft(
      original: InstallCriterion.fromJson({
        ...fixture,
        'locais_proibidos': {'custom': true},
      }),
    );
    draft.selectType('POSTE', blocked: true, selected: true);
    draft.setLocations(
      CriterionCollection.authorizedLocations,
      ' POSTE:1\n\nPOSTE:1\nTORRE:2 ',
    );
    final payload = draft.toPayload(userId: 1);
    expect(payload['tipos_elementos_permitidos'], ['SUBESTACAO']);
    expect(payload['tipos_elementos_proibidos'], contains('POSTE'));
    expect(payload['locais_autorizados'], ['POSTE:1', 'TORRE:2']);
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
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Critério 21'));
      await tester.pumpAndSettle();
      expect(find.text('Critério 21'), findsOneWidget);
      expect(find.textContaining('Altura mín.'), findsNothing);
      expect(
        const NovoEstudo(
          nome: 'Teste',
          pontosArea: [],
          idCriterioInstalacao: 21,
        ).toJson()['id_criterio_instalacao'],
        21,
      );
    },
  );
}
