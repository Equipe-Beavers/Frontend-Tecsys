import 'dart:convert';

import 'support/criterion_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend_tecsys/models/install_criterion.dart';
import 'package:frontend_tecsys/pages/criteria_library_page.dart';
import 'package:frontend_tecsys/pages/install_criterion_form.dart';
import 'package:frontend_tecsys/services/install_criterion_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

void main() {
  test(
    'service paginates, filters the user and uses PATCH and DELETE',
    () async {
      final requests = <http.Request>[];
      final service = InstallCriterionService(
        baseUrl: 'http://example.test/',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'DELETE') return http.Response('', 204);
          if (request.url.path == '/list-install-criteria') {
            return jsonResponse({
              'data': request.url.queryParameters['page'] == '1'
                  ? List.filled(100, fixture)
                  : [],
            }, 200);
          }
          return jsonResponse({
            'data': fixture,
          }, request.method == 'POST' ? 201 : 200);
        }),
      );
      addTearDown(service.dispose);
      expect((await service.list(userId: 12, limit: 100)).items.length, 100);
      expect(requests.length, 1);
      expect(
        (await service.list(userId: 12, page: 2, limit: 100)).items,
        isEmpty,
      );
      expect(requests.first.url.queryParameters['id_usuario'], '12');
      expect(requests[1].url.queryParameters['page'], '2');
      expect((await service.get(7)).name, fixture['nome']);
      await service.save({'nome': 'Novo', 'id_usuario': 12});
      expect(requests.last.url.path, '/create-install-criterion');
      await service.save({'limite_gateways': null}, id: 7);
      expect(requests.last.method, 'PATCH');
      expect(jsonDecode(requests.last.body), {'limite_gateways': null});
      await service.delete(7);
      expect(requests.last.url.path, '/delete-install-criterion/7');
    },
  );

  test('service preserves conflict message', () async {
    final service = InstallCriterionService(
      client: MockClient(
        (_) async => jsonResponse({'message': 'Critério em uso.'}, 409),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.delete(7),
      throwsA(
        isA<CriterionApiException>().having((e) => e.status, 'status', 409),
      ),
    );
  });

  testWidgets('library creates, refreshes and edits a saved criterion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? payload;
    var saved = false;
    final service = InstallCriterionService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          saved = true;
          return jsonResponse({'data': fixture}, 201);
        }
        if (request.url.path.startsWith('/get-')) {
          return jsonResponse({'data': fixture}, 200);
        }
        return jsonResponse({
          'data': saved ? [fixture] : [],
        }, 200);
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      host(CriteriaLibraryPage(service: service, userId: 9)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sua biblioteca começa aqui'), findsOneWidget);
    await tester.tap(find.text('Novo critério'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar critério'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome do critério.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Novo critério de teste',
    );
    await tester.tap(find.text('Salvar critério'));
    await tester.pumpAndSettle();
    expect(payload!['id_usuario'], 9);
    expect(payload!.containsKey('altura_minima_m'), false);
    expect(find.text(fixture['nome'] as String), findsOneWidget);
    await tester.tap(find.text(fixture['nome'] as String));
    await tester.pumpAndSettle();
    expect(find.text('Editar critério'), findsOneWidget);
  });

  testWidgets('edit preserves structured JSON and validates numeric input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? payload;
    await tester.pumpWidget(
      host(
        InstallCriterionForm(
          criterion: InstallCriterion.fromJson({
            ...fixture,
            'locais_autorizados': {
              'custom': ['a'],
            },
          }),
          userId: 1,
          onClose: () {},
          onSave: (value) async => payload = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Máximo de gateways'),
      '-1',
    );
    await tester.tap(find.text('Salvar critério'));
    await tester.pumpAndSettle();
    expect(payload, isNull);
    expect(find.text('Informe um inteiro positivo válido.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Máximo de gateways'),
      '',
    );
    await tester.tap(find.text('Salvar critério'));
    await tester.pumpAndSettle();
    expect(payload!['limite_gateways'], isNull);
    expect(payload!.containsKey('locais_autorizados'), false);
    expect(payload!.containsKey('id_usuario'), false);
  });

  testWidgets('library saves edits with PATCH and removes deleted criteria', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? current = {...fixture};
    Map<String, dynamic>? patch;
    final service = InstallCriterionService(
      client: MockClient((request) async {
        if (request.method == 'PATCH') {
          patch = jsonDecode(request.body) as Map<String, dynamic>;
          current = {...current!, ...patch!};
          return jsonResponse({'data': current}, 200);
        }
        if (request.method == 'DELETE') {
          current = null;
          return http.Response('', 204);
        }
        if (request.url.path.startsWith('/get-')) {
          return jsonResponse({'data': current}, 200);
        }
        return jsonResponse({
          'data': current == null ? [] : [current],
        }, 200);
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(host(CriteriaLibraryPage(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(fixture['nome'] as String));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Critério revisado',
    );
    await tester.tap(find.text('Salvar critério'));
    await tester.pumpAndSettle();
    expect(patch!['nome'], 'Critério revisado');
    expect(find.text('Critério revisado'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Critério revisado'), findsNothing);
    expect(find.text('Sua biblioteca começa aqui'), findsOneWidget);
  });

  testWidgets('failed save keeps input and cancel asks to discard', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      host(
        InstallCriterionForm(
          userId: 1,
          onClose: () => closed = true,
          onSave: (_) async =>
              throw const CriterionApiException(500, 'Falha ao salvar.'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Meu critério');
    await tester.tap(find.text('Salvar critério'));
    await tester.pumpAndSettle();
    expect(find.text('Falha ao salvar.'), findsOneWidget);
    expect(find.text('Meu critério'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(closed, false);
  });

  testWidgets('load error supports retry and deletion conflict keeps card', (
    tester,
  ) async {
    var fail = true;
    final service = InstallCriterionService(
      client: MockClient((request) async {
        if (request.method == 'DELETE') {
          return jsonResponse({'message': 'Critério em uso.'}, 409);
        }
        if (fail) return http.Response('{}', 500);
        return jsonResponse({
          'data': [fixture],
        }, 200);
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(host(CriteriaLibraryPage(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Critério em uso.'), findsOneWidget);
    expect(find.text(fixture['nome'] as String), findsOneWidget);
  });

  testWidgets(
    'local requirements switch and kilometer slider save API values',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? payload;
      await tester.pumpWidget(
        host(
          InstallCriterionForm(
            criterion: InstallCriterion.fromJson(fixture),
            userId: 1,
            onClose: () {},
            onSave: (value) async => payload = value,
          ),
        ),
      );
      expect(find.text('1,5 km'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      await tester.pumpAndSettle();
      expect(find.text('2,5 km'), findsOneWidget);
      await tester.tap(find.text('Salvar critério'));
      await tester.pumpAndSettle();
      expect(payload!['requer_alimentacao_eletrica'], false);
      expect(payload!['distancia_maxima_ativos_m'], 2500);
    },
  );

  for (final distance in [null, 0, 7500]) {
    testWidgets(
      'editing preserves existing distance $distance and nullable power',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? payload;
        await tester.pumpWidget(
          host(
            InstallCriterionForm(
              criterion: InstallCriterion.fromJson({
                ...fixture,
                'distancia_maxima_ativos_m': distance,
                'requer_alimentacao_eletrica': null,
              }),
              userId: 1,
              onClose: () {},
              onSave: (value) async => payload = value,
            ),
          ),
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          'Nome revisado',
        );
        await tester.tap(find.text('Salvar critério'));
        await tester.pumpAndSettle();
        expect(payload!['distancia_maxima_ativos_m'], distance);
        expect(payload!['requer_alimentacao_eletrica'], isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    for (final form in [false, true]) {
      final name = '${form ? 'form' : 'library'}_${size.width.toInt()}';
      testWidgets('responsive layout $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = InstallCriterionService(
          client: MockClient(
            (_) async => jsonResponse({
              'data': [fixture],
            }, 200),
          ),
        );
        addTearDown(service.dispose);
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: const Key('preview'),
              child: ColoredBox(
                color: AppColors.surfaceBackground,
                child: form
                    ? InstallCriterionForm(
                        criterion: InstallCriterion.fromJson(fixture),
                        userId: 1,
                        onClose: () {},
                        onSave: (_) async {},
                      )
                    : CriteriaLibraryPage(service: service),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const Key('preview')),
          matchesGoldenFile('goldens/criteria_$name.png'),
        );
      });
    }
  }
}
