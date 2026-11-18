import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/controllers/auth_controller.dart';
import 'package:frontend_tecsys/main.dart';
import 'package:frontend_tecsys/pages/auth_page.dart';
import 'package:frontend_tecsys/pages/studies_page.dart';
import 'package:frontend_tecsys/pages/library_page.dart';
import 'package:frontend_tecsys/services/auth_service.dart';
import 'package:frontend_tecsys/widgets/navbar.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<AuthController> mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = AuthService(
    client: MockClient((request) async {
      if (request.url.path == '/auth/logout') return http.Response('', 204);
      final email = (jsonDecode(request.body) as Map)['email'];
      final id = email == 'a@example.com' ? 37 : 38;
      return http.Response(
        jsonEncode({
          'access_token': 'token-$id',
          'usuario': {
            'id_usuario': id,
            'username': 'Usuario $id',
            'email': email,
          },
        }),
        200,
      );
    }),
  );
  final auth = AuthController(service: service);
  addTearDown(auth.dispose);
  addTearDown(service.dispose);
  await tester.pumpWidget(MyApp(authController: auth));
  await tester.pump();
  return auth;
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(Navbar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> login(WidgetTester tester, String email) async {
  final emailField = find.descendant(
    of: find.byKey(const Key('login-email')),
    matching: find.byType(TextFormField),
  );
  final passwordField = find.descendant(
    of: find.byKey(const Key('login-password')),
    matching: find.byType(TextFormField),
  );
  await tester.ensureVisible(emailField);
  await tester.enterText(emailField, email);
  await tester.ensureVisible(passwordField);
  await tester.enterText(passwordField, 'Senha de teste!');
  final button = find.widgetWithText(FilledButton, 'Entrar');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Estudos exige login e recebe ID do JWT em vez do usuário fixo', (
    tester,
  ) async {
    await mount(tester);
    await tapTab(tester, 'Estudos');
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(StudiesPage), findsNothing);
    await login(tester, 'a@example.com');
    expect(find.byType(AuthPage), findsNothing);
    expect(tester.widget<StudiesPage>(find.byType(StudiesPage)).userId, 37);
  });

  testWidgets(
    'Biblioteca exige login e não monta consultas privadas para visitante',
    (tester) async {
      await mount(tester);
      await tapTab(tester, 'Biblioteca');
      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.byType(CriteriaLibraryPage), findsNothing);
      await login(tester, 'b@example.com');
      expect(
        tester
            .widget<CriteriaLibraryPage>(find.byType(CriteriaLibraryPage))
            .userId,
        38,
      );
    },
  );

  testWidgets(
    'expiração remove telas privadas e logout não permite voltar aos dados de A',
    (tester) async {
      final auth = await mount(tester);
      await tapTab(tester, 'Estudos');
      await login(tester, 'a@example.com');
      final context = tester.element(find.byType(StudiesPage));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Tela privada de A')),
        ),
      );
      await tester.pumpAndSettle();
      await auth.invalidate(auth.accessToken!);
      await tester.pumpAndSettle();
      expect(find.text('Tela privada de A'), findsNothing);
      expect(find.byType(StudiesPage), findsNothing);
      expect(find.byType(AuthPage), findsOneWidget);
      await login(tester, 'b@example.com');
      await tapTab(tester, 'Estudos');
      expect(tester.widget<StudiesPage>(find.byType(StudiesPage)).userId, 38);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(StudiesPage), findsNothing);
      expect(find.byType(AuthPage), findsOneWidget);
    },
  );
}
