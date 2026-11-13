import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/controllers/auth_controller.dart';
import 'package:frontend_tecsys/pages/auth_page.dart';
import 'package:frontend_tecsys/pages/profile_page.dart';
import 'package:frontend_tecsys/services/auth_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/auth/auth_form_components.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = {
  'id_usuario': 7,
  'username': 'Rafael Coelho',
  'email': 'rafael@example.com',
};
http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Finder field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);
Finder get createButton => find.widgetWithText(FilledButton, 'Criar conta');

Future<void> fillRegistration(
  WidgetTester tester, {
  String confirmation = 'Senha segura!',
}) async {
  for (final (key, value) in [
    ('register-username', 'Rafael Coelho'),
    ('register-email', 'RAFAEL@example.com'),
    ('register-password', 'Senha segura!'),
    ('register-confirmation', confirmation),
  ]) {
    await tester.ensureVisible(field(key));
    await tester.enterText(field(key), value);
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(createButton);
  await tester.pump();
}

Future<AuthController> mount(
  WidgetTester tester,
  MockClient client, {
  Size size = const Size(392, 846),
  bool profile = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = AuthService(client: client);
  final controller = AuthController(service: service);
  addTearDown(controller.dispose);
  addTearDown(service.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: AppColors.primaryLime),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: profile
          ? Scaffold(body: ProfilePage(controller: controller))
          : AuthPage(controller: controller, register: true),
    ),
  );
  return controller;
}

void main() {
  testWidgets('campos obrigatórios e confirmação impedem envio inválido', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      MockClient((_) async {
        calls++;
        return _json({'data': _user}, 201);
      }),
    );
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();
    expect(find.text('Informe seu nome de usuário.'), findsOneWidget);
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(calls, 0);
    await fillRegistration(tester, confirmation: 'Outra senha');
    await tester.tap(createButton);
    await tester.pump();
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cadastro válido mostra sucesso e abre login com email sem senha',
    (tester) async {
      await mount(
        tester,
        MockClient((request) async {
          expect(jsonDecode(request.body), {
            'username': 'Rafael Coelho',
            'email': 'rafael@example.com',
            'senha': 'Senha segura!',
          });
          return _json({'data': _user}, 201);
        }),
      );
      await fillRegistration(tester);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Conta criada com sucesso! Entre com seu e-mail e senha.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(field('login-email')).controller?.text,
        'rafael@example.com',
      );
      expect(
        tester.widget<TextFormField>(field('login-password')).controller?.text,
        isEmpty,
      );
      expect(find.byKey(const Key('register-password')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bloqueia duplo envio e exibe duplicidade no campo correto', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<http.Response>();
    await mount(
      tester,
      MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    await fillRegistration(tester);
    await tester.tap(createButton);
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(calls, 1);
    pending.complete(_json({'code': 'EMAIL_ALREADY_EXISTS'}, 409));
    await tester.pumpAndSettle();
    expect(find.text('E-mail já cadastrado.'), findsOneWidget);
    expect(createButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final status in [429, 503]) {
    testWidgets('erro $status mantém formulário e permite repetir', (
      tester,
    ) async {
      await mount(tester, MockClient((_) async => http.Response('', status)));
      await fillRegistration(tester);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(find.byType(AuthNotice), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(field('register-username'))
            .controller
            ?.text,
        'Rafael Coelho',
      );
      expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
    });
  }

  testWidgets('entrar alterna formulário sem enviar cadastro', (tester) async {
    var calls = 0;
    await mount(
      tester,
      MockClient((_) async {
        calls++;
        return http.Response('', 500);
      }),
    );
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Entrar'));
    await tester.tap(find.widgetWithText(TextButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(field('login-email'), findsOneWidget);
    expect(calls, 0);
    await tester.ensureVisible(find.text('Cadastre-se'));
    await tester.tap(find.text('Cadastre-se'));
    await tester.pumpAndSettle();
    expect(field('register-username'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(392, 846),
    const Size(900, 650),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'cadastro responsivo ${size.width}x${size.height} sem overflow',
      (tester) async {
        await mount(
          tester,
          MockClient((_) async => http.Response('', 500)),
          size: size,
        );
        await fillRegistration(tester);
        expect(tester.takeException(), isNull);
        expect(createButton.hitTestable(), findsOneWidget);
      },
    );
  }

  testWidgets('cadastro continua acessível com teclado e texto ampliado', (
    tester,
  ) async {
    await mount(
      tester,
      MockClient((_) async => http.Response('', 500)),
      textScale: 1.8,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await fillRegistration(tester);
    expect(tester.takeException(), isNull);
    expect(createButton.hitTestable(), findsOneWidget);
  });

  testWidgets(
    'perfil abre cadastro, autentica com dados reais e encerra sessão',
    (tester) async {
      final paths = <String>[];
      final controller = await mount(
        tester,
        MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/auth/register') {
            return _json({'data': _user}, 201);
          }
          if (request.url.path == '/auth/login') {
            return _json({'usuario': _user, 'access_token': 'token'}, 200);
          }
          expect(request.headers['authorization'], 'Bearer token');
          return http.Response('', 204);
        }),
        profile: true,
      );
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      await fillRegistration(tester);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('login-password'));
      await tester.enterText(field('login-password'), 'Senha segura!');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();
      expect(controller.user?.id, 7);
      expect(find.text('RC'), findsOneWidget);
      expect(find.text('Rafael Coelho'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Sair'));
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(controller.user, isNull);
      expect(paths, ['/auth/register', '/auth/login', '/auth/logout']);
      expect(find.text('Sua conta Geomash'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
