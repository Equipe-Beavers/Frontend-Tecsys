import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/controllers/auth_controller.dart';
import 'package:frontend_tecsys/services/auth_service.dart';
import 'package:frontend_tecsys/services/authenticated_client.dart';
import 'package:frontend_tecsys/services/session_store.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/services/install_criterion_service.dart';
import 'package:frontend_tecsys/services/rf_profile_service.dart';
import 'package:frontend_tecsys/services/recomendacao_service.dart';
import 'package:frontend_tecsys/services/mancha_cenario_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const api = 'http://localhost:3000';
const user = {
  'id_usuario': 37,
  'username': 'Usuario A',
  'email': 'a@example.com',
};

class UnavailableSessionStore implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async =>
      throw StateError('Vault unavailable');
  @override
  Future<void> clear() async {}
}

http.Response jsonResponse(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<AuthController> signedIn({SessionStore? store}) async {
  final service = AuthService(
    client: MockClient((request) async {
      if (request.url.path == '/auth/logout') return http.Response('', 204);
      return jsonResponse({'access_token': 'token-A', 'usuario': user}, 200);
    }),
  );
  final auth = AuthController(service: service, store: store);
  addTearDown(auth.dispose);
  addTearDown(service.dispose);
  await auth.login(email: 'a@example.com', password: 'Senha de teste');
  return auth;
}

void main() {
  test(
    'falha ao armazenar token impede login e tenta revogar a sessão criada',
    () async {
      final paths = <String>[];
      final service = AuthService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          return request.url.path == '/auth/logout'
              ? http.Response('', 204)
              : jsonResponse({'access_token': 'token-A', 'usuario': user}, 200);
        }),
      );
      final auth = AuthController(
        service: service,
        store: UnavailableSessionStore(),
      );
      addTearDown(auth.dispose);
      addTearDown(service.dispose);
      await expectLater(
        auth.login(email: 'a@example.com', password: 'Senha de teste'),
        throwsA(isA<AuthApiException>()),
      );
      expect(auth.user, isNull);
      expect(auth.accessToken, isNull);
      expect(paths, ['/auth/login', '/auth/logout']);
    },
  );
  test('restauração valida token persistido em /auth/me sem confiar em usuário local', () async {
    final store = MemorySessionStore()..token = 'saved-token';
    final service = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/auth/me');
        expect(request.headers['authorization'], 'Bearer saved-token');
        return jsonResponse({'usuario': user}, 200);
      }),
    );
    final auth = AuthController(service: service, store: store);
    addTearDown(auth.dispose);
    addTearDown(service.dispose);
    await auth.restore();
    expect(auth.user?.id, 37);
    expect(auth.accessToken, 'saved-token');
    expect(auth.restoring, isFalse);
  });

  for (final status in [401, 503]) {
    test('restaurar sessão com HTTP $status não concede acesso', () async {
      final store = MemorySessionStore()..token = 'saved-token';
      final service = AuthService(
        client: MockClient((_) async => http.Response('', status)),
      );
      final auth = AuthController(service: service, store: store);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);
      await auth.restore();
      expect(auth.user, isNull);
      expect(auth.accessToken, isNull);
      expect(store.token, status == 401 ? isNull : 'saved-token');
      expect(auth.restoreError, status == 503 ? isNotNull : isNull);
    });
  }

  test('logout remove token persistido após revogação no backend', () async {
    final store = MemorySessionStore();
    final auth = await signedIn(store: store);
    expect(store.token, 'token-A');
    await auth.logout();
    expect(store.token, isNull);
    expect(auth.user, isNull);
  });

  test('JWT expirado encerra a sessão mesmo sem outra requisição', () async {
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60}),
      ),
    );
    final service = AuthService(
      client: MockClient(
        (_) async => jsonResponse({
          'usuario': user,
          'access_token': 'header.$payload.signature',
        }, 200),
      ),
    );
    final store = MemorySessionStore();
    final auth = AuthController(service: service, store: store);
    addTearDown(auth.dispose);
    addTearDown(service.dispose);
    await auth.login(email: 'a@example.com', password: 'Senha de teste');
    await Future<void>.delayed(Duration.zero);
    expect(auth.user, isNull);
    expect(store.token, isNull);
  });

  test(
    'todos os serviços privados enviam Authorization à API configurada',
    () async {
      final auth = await signedIn();
      final paths = <String>[];
      AuthenticatedClient client() => AuthenticatedClient(
        auth,
        baseUrl: api,
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['authorization'], 'Bearer token-A');
          return switch (request.url.path) {
            '/estudos' => jsonResponse({'estudos': []}, 200),
            '/list-install-criteria' ||
            '/list-rf-profiles' => jsonResponse({'data': []}, 200),
            _ => http.Response('', 403),
          };
        }),
      );
      final studies = EstudosService(client: client(), baseUrl: api);
      final criteria = InstallCriterionService(client: client(), baseUrl: api);
      final rf = RFProfileService(client: client(), baseUrl: api);
      final recommendations = RecomendacaoService(
        client: client(),
        baseUrl: api,
      );
      final coverage = ManchaCenarioService(client: client(), baseUrl: api);
      addTearDown(studies.dispose);
      addTearDown(criteria.dispose);
      addTearDown(rf.dispose);
      addTearDown(recommendations.dispose);
      addTearDown(coverage.dispose);
      await studies.list(userId: auth.user!.id);
      await criteria.list(userId: auth.user!.id);
      await rf.list(userId: auth.user!.id);
      await expectLater(
        recommendations.gerarRecomendacao(idEstudo: 8, idPerfilRf: 3),
        throwsStateError,
      );
      await expectLater(coverage.getManchaCenario(9), throwsStateError);
      expect(paths, [
        '/estudos',
        '/list-install-criteria',
        '/list-rf-profiles',
        '/study/8/recommendation',
        '/get-scenario-coverage/9',
      ]);
      expect(auth.user, isNotNull); // 403 does not invalidate the session.
    },
  );

  test('não envia token a domínios externos ou caminhos fora da API', () async {
    final auth = await signedIn();
    final client = AuthenticatedClient(
      auth,
      baseUrl: '$api/private',
      client: MockClient((request) async {
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response('', 200);
      }),
    );
    addTearDown(client.close);
    await client.get(Uri.parse('https://api.mapbox.com/tiles'));
    await client.get(Uri.parse('$api/public'));
    await client.get(Uri.parse('http://localhost:3001/private/estudos'));
  });

  test('401 de rota protegida invalida token e limpa armazenamento', () async {
    final store = MemorySessionStore();
    final auth = await signedIn(store: store);
    final client = AuthenticatedClient(
      auth,
      baseUrl: api,
      client: MockClient((_) async => http.Response('', 401)),
    );
    addTearDown(client.close);
    expect((await client.get(Uri.parse('$api/estudos'))).statusCode, 401);
    expect(auth.user, isNull);
    expect(auth.accessToken, isNull);
    expect(store.token, isNull);
  });

  test(
    'resposta antiga não aparece após logout ou invalida outro login',
    () async {
      final auth = await signedIn();
      final pending = Completer<http.Response>();
      final client = AuthenticatedClient(
        auth,
        baseUrl: api,
        client: MockClient((_) => pending.future),
      );
      addTearDown(client.close);
      final response = client.get(Uri.parse('$api/estudos'));
      await Future<void>.delayed(Duration.zero);
      await auth.logout();
      pending.complete(
        jsonResponse({
          'estudos': [
            {'nome': 'privado de A'},
          ],
        }, 200),
      );
      final result = await response;
      expect(result.statusCode, 401);
      expect(result.body, isEmpty);
    },
  );
}
