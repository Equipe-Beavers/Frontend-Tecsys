import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:frontend_tecsys/pages/library_page.dart';
import 'package:frontend_tecsys/services/install_criterion_service.dart';

import 'support/criterion_test_support.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  testWidgets(
    'criteria UI persists create, edit and delete in local PostgreSQL',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Real HTTP is intentional: this opt-in test never uses MockClient.
      final client = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        _RealHttpOverrides(),
      );
      final service = InstallCriterionService(
        client: IOClient(client),
        baseUrl: 'http://127.0.0.1:3001',
      );
      final name = '[E2E LOCAL] ${DateTime.now().microsecondsSinceEpoch}';
      int? createdId;

      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 100));
          if (finder.evaluate().isNotEmpty) return;
        }
        fail('Interface não chegou ao estado esperado: $finder');
      }

      Future<dynamic> databaseRow(int id) async {
        final result = await tester.runAsync(
          () => Process.run('node', [
            '--import',
            'tsx',
            'scripts/InspectCriterionLocal.mjs',
            '$id',
          ], workingDirectory: '../backend'),
        );
        expect(result!.exitCode, 0, reason: '${result.stderr}');
        return jsonDecode(result.stdout.toString().trim().split('\n').last);
      }

      try {
        await tester.pumpWidget(
          host(CriteriaLibraryPage(service: service, userId: 1)),
        );
        await waitFor(find.text('Novo critério'));
        await tester.tap(find.text('Novo critério'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, name);
        final minimum = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Mínima',
        );
        await tester.enterText(minimum, '300');
        final radii = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Raio de análise',
        );
        await tester.enterText(radii.first, '100');
        await tester.enterText(radii.last, '500');
        tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
          const RangeValues(500, 1500),
        );
        await tester.pump();
        await tester.tap(find.text('Salvar critério'));
        await waitFor(find.byTooltip('Ações de $name'));
        final page = await tester.runAsync(
          () => service.list(userId: 1, limit: 100),
        );
        final record = page!.items.singleWhere((item) => item.name == name);
        createdId = record.id;
        final stored = await databaseRow(createdId);
        expect(stored['relevo']['altitude_minima_m'], 300);
        expect(stored['edificacoes']['raio_analise_m'], 100);
        expect(stored['antenas']['raio_analise_m'], 500);
        expect(stored['nome'], name);
        expect(double.parse('${stored['distancia_minima_ativos_m']}'), 500);
        expect(stored['requer_alimentacao_eletrica'], true);
        expect(double.parse('${stored['distancia_maxima_ativos_m']}'), 1500);
        expect(stored['vegetacoes'], isA<Map>());
        for (final field in ['relevo', 'edificacoes', 'antenas']) {
          expect(stored[field], isA<Map>());
        }

        // Recreate the page: the displayed record must come from the API.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          host(CriteriaLibraryPage(service: service, userId: 1)),
        );
        await waitFor(find.byTooltip('Ações de $name'));
        await tester.tap(find.text(name));
        await waitFor(find.text('Editar critério'));
        expect(
          tester.widget<RangeSlider>(find.byType(RangeSlider)).values,
          const RangeValues(500, 1500),
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          '$name editado',
        );
        await tester.tap(find.text('Salvar critério'));
        await waitFor(find.byTooltip('Ações de $name editado'));
        final updated = await databaseRow(createdId);
        expect(updated['nome'], '$name editado');
        expect(updated['vegetacoes'], stored['vegetacoes']);
        expect(updated['atualizado_em'], isNotNull);

        await tester.tap(find.byTooltip('Ações de $name editado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excluir'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
        for (
          var i = 0;
          i < 100 && find.text('$name editado').evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('$name editado'), findsNothing);
        expect(await databaseRow(createdId), isNull);
        createdId = null;
      } finally {
        // Remove only this test's record, including after a failed assertion.
        await tester.runAsync(() async {
          final page = await service.list(userId: 1, limit: 100);
          for (final item in page.items.where(
            (item) => item.name == name || item.name == '$name editado',
          )) {
            await service.delete(item.id);
          }
        });
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
      }
    },
    skip: !const bool.fromEnvironment('TEST_CRITERIA_LOCAL'),
  );
}
