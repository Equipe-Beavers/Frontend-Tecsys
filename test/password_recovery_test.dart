import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend_tecsys/controllers/auth_controller.dart';
import 'package:frontend_tecsys/pages/password_recovery_page.dart';
import 'package:frontend_tecsys/services/auth_service.dart';
import 'package:frontend_tecsys/main.dart';
import 'package:frontend_tecsys/widgets/auth/auth_loading_screen.dart';
import 'package:frontend_tecsys/models/auth_operation.dart';

Finder field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

Future<void> mount(
  WidgetTester tester,
  MockClient client, {
  String? token,
  Size size = const Size(392, 846),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = AuthService(client: client, baseUrl: 'http://localhost:3000');
  final controller = AuthController(service: service);
  addTearDown(controller.dispose);
  addTearDown(service.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: PasswordRecoveryPage(controller: controller, token: token),
    ),
  );
}

void main() {
  testWidgets(
    'token ausente ou malformado não envia redefinição e permite outro link',
    (tester) async {
      var calls = 0;
      await mount(
        tester,
        MockClient((_) async {
          calls++;
          return http.Response('', 204);
        }),
        token: 'invalido',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Este link é inválido'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Salvar nova senha'),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 0);
      await tester.tap(find.text('Solicitar outro link'));
      await tester.pumpAndSettle();
      expect(field('recovery-email'), findsOneWidget);
    },
  );

  for (final status in [204, 400, 500]) {
    testWidgets(
      'redefinição usa carregamento US70 e libera a tela após HTTP $status',
      (tester) async {
        final response = Completer<http.Response>();
        await mount(
          tester,
          MockClient((request) {
            expect(request.url.path, '/auth/reset-password');
            expect(jsonDecode(request.body)['token'], 'a' * 64);
            return response.future;
          }),
          token: 'a' * 64,
        );
        await tester.enterText(field('reset-password'), 'Senha nova segura!');
        await tester.enterText(
          field('reset-confirmation'),
          'Senha nova segura!',
        );
        await tester.tap(find.text('Salvar nova senha'));
        await tester.pump();
        expect(find.byType(AuthLoadingScreen), findsOneWidget);
        expect(
          tester
              .widget<AuthLoadingScreen>(find.byType(AuthLoadingScreen))
              .operation,
          AuthOperation.resetPassword,
        );
        response.complete(
          http.Response(
            status == 204 ? '' : '{"code":"INVALID_RESET_TOKEN"}',
            status,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AuthLoadingScreen), findsNothing);
        expect(
          find.textContaining(
            status == 204
                ? 'Senha alterada com sucesso'
                : status == 400
                ? 'Este link é inválido'
                : 'Não foi possível concluir',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('link inicial abre diretamente a redefinição sem exigir login', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue =
        '/redefinir-senha?token=${'a' * 64}';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final service = AuthService(
      client: MockClient((_) async => http.Response('', 204)),
    );
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);
    addTearDown(service.dispose);
    await tester.pumpWidget(MyApp(authController: controller));
    await tester.pumpAndSettle();
    expect(find.text('Redefinir senha'), findsOneWidget);
    expect(field('reset-password'), findsOneWidget);
    expect(controller.user, isNull);
  });

  testWidgets(
    'solicitação valida e normaliza e-mail e mostra resposta neutra',
    (tester) async {
      var calls = 0;
      await mount(
        tester,
        MockClient((request) async {
          calls++;
          expect(request.url.path, '/auth/forgot-password');
          expect(jsonDecode(request.body), {'email': 'rafael@example.com'});
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('{"message":"ok"}', 202);
        }),
      );
      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(field('recovery-email'), ' RAFAEL@example.com ');
      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('Se houver uma conta'), findsOneWidget);
    },
  );

  testWidgets(
    'exige confirmação e envia somente token e senha; sucesso oferece login',
    (tester) async {
      var calls = 0;
      final token = 'a' * 64;
      await mount(
        tester,
        MockClient((request) async {
          calls++;
          expect(request.url.path, '/auth/reset-password');
          expect(jsonDecode(request.body), {
            'token': token,
            'senha': 'Senha nova segura!',
          });
          return http.Response('', 204);
        }),
        token: token,
      );
      await tester.enterText(field('reset-password'), 'Senha nova segura!');
      await tester.enterText(field('reset-confirmation'), 'Diferente');
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('As senhas não coincidem.'), findsOneWidget);
      await tester.enterText(field('reset-confirmation'), 'Senha nova segura!');
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('Senha alterada com sucesso'), findsOneWidget);
      await tester.tap(find.text('Voltar para entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Esqueci a senha'), findsOneWidget);
    },
  );

  testWidgets(
    'link expirado permite solicitar outro sem perder acesso ao formulário',
    (tester) async {
      await mount(
        tester,
        MockClient(
          (_) async => http.Response('{"code":"INVALID_RESET_TOKEN"}', 400),
        ),
        token: 'a' * 64,
      );
      await tester.enterText(field('reset-password'), 'Senha nova segura!');
      await tester.enterText(field('reset-confirmation'), 'Senha nova segura!');
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Este link é inválido'), findsOneWidget);
      await tester.tap(find.text('Solicitar outro link'));
      await tester.pumpAndSettle();
      expect(field('recovery-email'), findsOneWidget);
      expect(field('reset-password'), findsNothing);
    },
  );

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('formulário responsivo em $size', (tester) async {
      await mount(
        tester,
        MockClient((_) async => http.Response('', 204)),
        token: 'a' * 64,
        size: size,
      );
      await tester.ensureVisible(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
