import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend_tecsys/controllers/auth_controller.dart';
import 'package:frontend_tecsys/models/auth_operation.dart';
import 'package:frontend_tecsys/services/auth_service.dart';
import 'package:frontend_tecsys/services/session_store.dart';
import 'package:frontend_tecsys/widgets/auth/auth_loading_screen.dart';

const user = {
  'id_usuario': 7,
  'username': 'Rafael',
  'email': 'rafael@example.com',
};
http.Response success(String path) => switch (path) {
  '/auth/register' => http.Response(jsonEncode({'data': user}), 201),
  '/auth/login' => http.Response(
    jsonEncode({'usuario': user, 'access_token': 'test-token'}),
    200,
  ),
  '/auth/me' => http.Response(jsonEncode({'usuario': user}), 200),
  '/auth/forgot-password' => http.Response('{"message":"ok"}', 202),
  _ => http.Response('', 204),
};
const paths = {
  AuthOperation.register: '/auth/register',
  AuthOperation.login: '/auth/login',
  AuthOperation.restoreSession: '/auth/me',
  AuthOperation.logout: '/auth/logout',
  AuthOperation.requestPasswordReset: '/auth/forgot-password',
  AuthOperation.resetPassword: '/auth/reset-password',
};
Future<void> invoke(AuthController auth, AuthOperation operation) async {
  switch (operation) {
    case AuthOperation.register:
      await auth.register(
        username: 'Rafael',
        email: 'rafael@example.com',
        password: 'Senha segura!',
      );
    case AuthOperation.login:
      await auth.login(email: 'rafael@example.com', password: 'Senha segura!');
    case AuthOperation.restoreSession:
      await auth.restore();
    case AuthOperation.logout:
      await auth.logout();
    case AuthOperation.requestPasswordReset:
      await auth.requestPasswordReset('rafael@example.com');
    case AuthOperation.resetPassword:
      await auth.resetPassword(token: 'a' * 64, password: 'Nova senha segura!');
  }
}

void main() {
  for (final operation in AuthOperation.values) {
    for (final failed in [false, true]) {
      test(
        '${operation.name}: acompanha requisição e encerra após ${failed ? 'erro' : 'sucesso'}',
        () async {
          final pending = Completer<http.Response>();
          final path = paths[operation]!;
          final service = AuthService(
            client: MockClient(
              (r) => r.url.path == path
                  ? pending.future
                  : Future.value(success(r.url.path)),
            ),
          );
          final store = MemorySessionStore();
          if (operation == AuthOperation.restoreSession) {
            store.token = 'test-token';
          }
          final auth = AuthController(service: service, store: store);
          addTearDown(auth.dispose);
          addTearDown(service.dispose);
          if (operation == AuthOperation.logout) {
            await auth.login(
              email: 'rafael@example.com',
              password: 'Senha segura!',
            );
          }
          final future = invoke(auth, operation);
          final expectation =
              failed && operation != AuthOperation.restoreSession
              ? expectLater(future, throwsA(isA<AuthApiException>()))
              : expectLater(future, completes);
          expect(auth.operation, operation);
          await Future<void>.delayed(Duration.zero);
          expect(auth.operation, operation);
          pending.complete(failed ? http.Response('{}', 503) : success(path));
          await expectation;
          expect(auth.operation, isNull);
          if (failed && operation == AuthOperation.restoreSession) {
            expect(auth.restoreError, isNotNull);
          }
        },
      );
    }
  }

  testWidgets(
    'oculta formulário, evita sobreposição de loaders e libera conteúdo após erro',
    (tester) async {
      final pending = Completer<http.Response>();
      final service = AuthService(client: MockClient((_) => pending.future));
      final auth = AuthController(service: service);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthLoadingHost(
            controller: auth,
            child: AuthLoadingHost(
              controller: auth,
              child: const Scaffold(body: Text('Formulário')),
            ),
          ),
        ),
      );
      expect(find.byType(AuthLoadingScreen), findsNothing);
      final request = auth.requestPasswordReset('rafael@example.com');
      final handled = expectLater(request, throwsA(isA<AuthApiException>()));
      await tester.pump();
      expect(find.byType(AuthLoadingScreen), findsOneWidget);
      expect(find.text('Formulário'), findsNothing);
      expect(
        find.text(AuthOperation.requestPasswordReset.message),
        findsOneWidget,
      );
      pending.complete(http.Response('{}', 503));
      await handled;
      await tester.pumpAndSettle();
      expect(find.byType(AuthLoadingScreen), findsNothing);
      expect(find.text('Formulário'), findsOneWidget);
    },
  );

  test(
    'operações concorrentes e descarte não deixam carregamento preso',
    () async {
      final first = Completer<http.Response>(),
          second = Completer<http.Response>();
      final service = AuthService(
        client: MockClient(
          (r) => r.url.path == '/auth/register' ? first.future : second.future,
        ),
      );
      final auth = AuthController(service: service);
      addTearDown(service.dispose);
      final register = auth.register(
        username: 'Rafael',
        email: 'rafael@example.com',
        password: 'Senha segura!',
      );
      final recovery = auth.requestPasswordReset('rafael@example.com');
      first.complete(success('/auth/register'));
      await register;
      expect(auth.operation, AuthOperation.requestPasswordReset);
      auth.dispose();
      second.complete(success('/auth/forgot-password'));
      await recovery;
      expect(auth.operation, isNull);
    },
  );

  for (final size in [
    const Size(392, 846),
    const Size(1440, 900),
    const Size(320, 568),
    const Size(640, 280),
  ]) {
    testWidgets('carregamento responsivo em $size e texto ampliado', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = bool.fromEnvironment('CAPTURE_AUTH_LOADING');
      if (capture) {
        await tester.runAsync(() async {
          final bytes = await File(
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
          ).readAsBytes();
          await (FontLoader(
            'PreviewSans',
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: capture ? 'PreviewSans' : null),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(size.width == 320 ? 1.8 : 1),
            ),
            child: RepaintBoundary(
              key: const Key('preview'),
              child: const AuthLoadingScreen(operation: AuthOperation.login),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      if (capture) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('preview')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/us70-loading-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
