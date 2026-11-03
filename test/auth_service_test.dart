import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/controllers/auth_controller.dart';
import 'package:frontend_tecsys/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const userJson = {
  'id_usuario': 7,
  'username': 'Rafael Coelho',
  'email': 'rafael@example.com',
};
http.Response jsonResponse(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'resposta atrasada do perfil não restaura usuário após logout',
    () async {
      final pending = Completer<http.Response>();
      final service = AuthService(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return jsonResponse({
              'usuario': userJson,
              'access_token': 'token',
            }, 200);
          }
          if (request.url.path == '/auth/me') return pending.future;
          return http.Response('', 204);
        }),
      );
      final controller = AuthController(service: service);
      addTearDown(controller.dispose);
      addTearDown(service.dispose);
      await controller.login(
        email: 'rafael@example.com',
        password: 'Senha correta!',
      );
      final refresh = controller.refreshUser();
      await controller.logout();
      pending.complete(jsonResponse({'usuario': userJson}, 200));
      await refresh;
      expect(controller.user, isNull);
      expect(controller.accessToken, isNull);
    },
  );
  test(
    'cadastro envia somente username, email normalizados e senha intacta',
    () async {
      final service = AuthService(
        baseUrl: 'http://localhost:3000/',
        client: MockClient((request) async {
          expect(request.url.path, '/auth/register');
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'username': 'Rafael Coelho',
            'email': 'rafael@example.com',
            'senha': ' Senha segura! ',
          });
          expect(request.headers['content-type'], 'application/json');
          return jsonResponse({'data': userJson}, 201);
        }),
      );
      addTearDown(service.dispose);
      final user = await service.register(
        username: ' Rafael Coelho ',
        email: ' RAFAEL@example.com ',
        password: ' Senha segura! ',
      );
      expect(user.id, 7);
      expect(user.initials, 'RC');
    },
  );

  for (final (status, code, message) in [
    (409, 'EMAIL_ALREADY_EXISTS', 'E-mail já cadastrado.'),
    (409, 'USERNAME_ALREADY_EXISTS', 'Nome de usuário já cadastrado.'),
    (429, 'TOO_MANY_REQUESTS', 'Muitas tentativas.'),
    (500, 'INTERNAL_ERROR', 'Não foi possível concluir'),
    (503, 'AUTH_NOT_CONFIGURED', 'Não foi possível concluir'),
  ]) {
    test('traduz erro $status/$code sem expor detalhes internos', () async {
      final service = AuthService(
        client: MockClient(
          (_) async => jsonResponse({
            'code': code,
            'message': 'Detalhes SQL confidenciais',
          }, status),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.register(
          username: 'Rafael',
          email: 'a@example.com',
          password: '12345678',
        ),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.status, 'status', status)
              .having((e) => e.message, 'message', contains(message)),
        ),
      );
    });
  }

  test('erro de rede permite tentar novamente', () async {
    final service = AuthService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.register(
        username: 'Rafael',
        email: 'a@example.com',
        password: '12345678',
      ),
      throwsA(
        isA<AuthApiException>().having(
          (e) => e.message,
          'message',
          contains('conectar ao servidor'),
        ),
      ),
    );
  });

  test('rejeita resposta inválida em vez de mostrar falso sucesso', () async {
    final service = AuthService(
      client: MockClient(
        (_) async => http.Response('<html>bad gateway</html>', 201),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.register(
        username: 'Rafael',
        email: 'a@example.com',
        password: '12345678',
      ),
      throwsA(isA<AuthApiException>()),
    );
  });

  test(
    'login, consulta do perfil e logout usam o token retornado pela API',
    () async {
      final paths = <String>[];
      final service = AuthService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/auth/login') {
            expect(jsonDecode(request.body), {
              'email': 'rafael@example.com',
              'senha': 'Senha correta!',
            });
            return jsonResponse({
              'usuario': userJson,
              'access_token': 'token-da-api',
            }, 200);
          }
          expect(request.headers['authorization'], 'Bearer token-da-api');
          expect(request.headers.containsKey('content-type'), isFalse);
          expect(request.body, isEmpty);
          return request.url.path == '/auth/me'
              ? jsonResponse({'usuario': userJson}, 200)
              : http.Response('', 204);
        }),
      );
      final controller = AuthController(service: service);
      addTearDown(controller.dispose);
      addTearDown(service.dispose);
      await controller.login(
        email: ' RAFAEL@example.com ',
        password: 'Senha correta!',
      );
      expect(controller.user?.email, 'rafael@example.com');
      await controller.refreshUser();
      await controller.logout();
      expect(controller.user, isNull);
      expect(controller.accessToken, isNull);
      expect(paths, ['/auth/login', '/auth/me', '/auth/logout']);
    },
  );

  test(
    'falha no logout mantém sessão para permitir repetir a revogação',
    () async {
      final service = AuthService(
        client: MockClient(
          (request) async => request.url.path == '/auth/login'
              ? jsonResponse({
                  'usuario': userJson,
                  'access_token': 'token',
                }, 200)
              : http.Response('', 503),
        ),
      );
      final controller = AuthController(service: service);
      addTearDown(controller.dispose);
      addTearDown(service.dispose);
      await controller.login(
        email: 'rafael@example.com',
        password: 'Senha correta!',
      );
      await expectLater(controller.logout(), throwsA(isA<AuthApiException>()));
      expect(controller.accessToken, 'token');
    },
  );

  test(
    'perfil com sessão expirada remove identidade e token da memória',
    () async {
      final service = AuthService(
        client: MockClient(
          (request) async => request.url.path == '/auth/login'
              ? jsonResponse({
                  'usuario': userJson,
                  'access_token': 'token',
                }, 200)
              : http.Response('', 401),
        ),
      );
      final controller = AuthController(service: service);
      addTearDown(controller.dispose);
      addTearDown(service.dispose);
      await controller.login(
        email: 'rafael@example.com',
        password: 'Senha correta!',
      );
      await expectLater(
        controller.refreshUser(),
        throwsA(isA<AuthApiException>()),
      );
      expect(controller.user, isNull);
      expect(controller.accessToken, isNull);
    },
  );
}
