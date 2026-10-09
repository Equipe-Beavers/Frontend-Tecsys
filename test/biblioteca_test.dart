import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';
import 'package:frontend_tecsys/pages/biblioteca_page.dart';
import 'package:frontend_tecsys/pages/perfil_rf_page.dart';
import 'package:frontend_tecsys/services/perfis_rf_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final largura in [320.0, 768.0, 1280.0]) {
    testWidgets(
      'Formulario responsivo em $largura pixels valida obrigatorios',
      (tester) async {
        tester.view.physicalSize = Size(largura, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var requisicoes = 0;
        final servico = PerfisRfService(
          cliente: MockClient((_) async {
            requisicoes++;
            return http.Response('{}', 500);
          }),
        );
        addTearDown(servico.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: PerfilRfPage(servico: servico),
          ),
        );
        expect(
          tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .map((campo) => (campo.key as ValueKey<String>).value),
          [
            'nome',
            'frequencia',
            'potencia',
            'alturaAntena',
            'alcance',
            'alturaGateway',
            'alturaDispositivo',
            'capacidade',
          ],
        );
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(
          tester
              .widgetList<SwitchListTile>(find.byType(SwitchListTile))
              .map((opcao) => (opcao.title as Text).data),
          [
            'Consideração de relevo',
            'Consideração de vegetação',
            'Consideração de edificações',
            'Consideração de antenas',
          ],
        );
        expect(find.text('PRÉVIA DO PERFIL'), findsOneWidget);
        final posicaoRadio = tester.getTopLeft(
          find.byKey(const ValueKey('nome')),
        );
        final posicaoCobertura = tester.getTopLeft(
          find.byKey(const ValueKey('capacidade')),
        );
        if (largura >= 800) {
          expect(posicaoCobertura.dx, greaterThan(posicaoRadio.dx));
          expect(posicaoCobertura.dy, posicaoRadio.dy);
        } else {
          expect(posicaoCobertura.dy, greaterThan(posicaoRadio.dy));
        }
        await tester.tap(find.text('Salvar perfil'));
        await tester.pumpAndSettle();
        expect(find.text('Campo obrigatório'), findsOneWidget);
        expect(requisicoes, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Lista, abre edicao, cancela e confirma exclusao', (
    tester,
  ) async {
    final dados = {...PerfilRf.padrao.toJson(), 'id_perfil_rf': 7};
    var exclusoes = 0;
    final servico = PerfisRfService(
      cliente: MockClient((requisicao) async {
        if (requisicao.method == 'DELETE') {
          exclusoes++;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'perfis': [dados],
          }),
          200,
        );
      }),
    );
    addTearDown(servico.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: BibliotecaPage(servico: servico)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Critérios'), findsOneWidget);
    expect(find.text('Perfis de RF'), findsOneWidget);
    await tester.tap(find.text('Perfil padrão'));
    await tester.pumpAndSettle();
    expect(find.text('Editar perfil de RF'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Excluir perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(exclusoes, 0);
    await tester.tap(find.byTooltip('Excluir perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(exclusoes, 1);
    expect(find.text('Nenhum perfil RF cadastrado.'), findsOneWidget);
  });

  testWidgets(
    'Edicao envia valores alterados preservando parametros adicionais',
    (tester) async {
      Map<String, dynamic>? enviado;
      final perfil = PerfilRf.fromJson({
        ...PerfilRf.padrao.toJson(),
        'id_perfil_rf': 7,
        'parametros_adicionais': {
          'ganho_adicional_db': -2,
          'outro_parametro': 5,
        },
      });
      final servico = PerfisRfService(
        cliente: MockClient((requisicao) async {
          enviado = jsonDecode(requisicao.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'perfis': {...enviado!, 'id_perfil_rf': 7},
            }),
            200,
          );
        }),
      );
      addTearDown(servico.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilRfPage(perfil: perfil, servico: servico),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Perfil atualizado',
      );
      await tester.tap(find.text('Salvar perfil'));
      await tester.pumpAndSettle();
      expect(enviado?['nome'], 'Perfil atualizado');
      expect((enviado?['parametros_adicionais'] as Map)['outro_parametro'], 5);
      expect(
        (enviado?['parametros_adicionais'] as Map)['ganho_adicional_db'],
        -2,
      );
    },
  );
}
