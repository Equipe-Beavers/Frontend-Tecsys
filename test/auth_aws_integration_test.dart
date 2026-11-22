import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/controllers/auth_controller.dart';
import 'package:frontend_tecsys/services/auth_service.dart';
import 'package:frontend_tecsys/services/authenticated_client.dart';
import 'package:frontend_tecsys/services/session_store.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/services/install_criterion_service.dart';
import 'package:frontend_tecsys/services/rf_profile_service.dart';
import 'package:frontend_tecsys/services/vegetacao_service.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

// Explicit opt-in only. The temporary harness owns account creation/cleanup and
// provides disposable credentials; ordinary flutter test never connects to AWS.
const enabled = bool.fromEnvironment('RUN_AWS_AUTH_TESTS');
const fixturePath = String.fromEnvironment('AWS_AUTH_FIXTURE');

class _ObservedClient extends http.BaseClient {
  _ObservedClient(this.records);
  final List<Map<String, Object>> records;
  final http.Client _inner = IOClient();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    records.add({
      'method': request.method,
      'path': request.url.path,
      'status': response.statusCode,
    });
    return response;
  }

  @override
  void close() => _inner.close();
}

void main() {
  test(
    'US70: serviços reais do Flutter integrados ao backend e PostgreSQL AWS',
    () async {
      if (!RegExp(r'^/tmp/geomash-us70-aws\.[A-Za-z0-9]+/fixture\.json$')
          .hasMatch(fixturePath)) {
        throw StateError(
          'Use somente o fixture do harness temporário autorizado.',
        );
      }
      final fixture = jsonDecode(File(fixturePath).readAsStringSync()) as Map;
      final base = fixture['baseUrl'] as String;
      final uri = Uri.parse(base);
      if (uri.host != '127.0.0.1' || uri.scheme != 'http') {
        throw StateError('Servidor de teste inválido.');
      }
      dotenv.testLoad(fileInput: 'API_BASE_URL=$base///');
      addTearDown(dotenv.clean);
      final records = <Map<String, Object>>[];
      final checks = <String>[];
      final raw = _ObservedClient(records);
      addTearDown(raw.close);
      final aService = AuthService(client: raw);
      final bService = AuthService(client: raw);
      final aStore = MemorySessionStore();
      final a = AuthController(service: aService, store: aStore);
      final b = AuthController(service: bService);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final accounts = (fixture['accounts'] as List).cast<Map>();
      final users = [];
      for (final account in accounts) {
        users.add(
          await aService.register(
            username: account['username'],
            email: account['email'],
            password: account['password'],
          ),
        );
      }
      expect(users[0].id, isNot(users[1].id));
      checks.add('cadastro A e B');
      await expectLater(
        aService.register(
          username: '${fixture['run']}_other',
          email: accounts[0]['email'],
          password: accounts[0]['password'],
        ),
        throwsA(isA<AuthApiException>().having((e) => e.status, 'status', 409)),
      );
      checks.add('e-mail duplicado: 409');
      await expectLater(
        aService.login(
          email: accounts[0]['email'],
          password: 'senha-incorreta',
        ),
        throwsA(isA<AuthApiException>().having((e) => e.status, 'status', 401)),
      );
      checks.add('credenciais incorretas: 401');
      await a.login(
        email: accounts[0]['email'],
        password: accounts[0]['password'],
      );
      await b.login(
        email: accounts[1]['email'],
        password: accounts[1]['password'],
      );
      expect(a.user!.id, users[0].id);
      expect(b.user!.id, users[1].id);
      await a.refreshUser();
      await b.refreshUser();
      checks.add('login e perfil de ambas as contas');
      final restored = AuthController(service: aService, store: aStore);
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.user!.id, users[0].id);
      checks.add('restauração validada por /auth/me');

      http.Client authenticated(AuthController auth) =>
          AuthenticatedClient(auth, client: raw);
      final aClient = authenticated(a), bClient = authenticated(b);
      final aStudies = EstudosService(client: aClient),
          bStudies = EstudosService(client: bClient);
      final aCriteria = InstallCriterionService(client: aClient),
          bCriteria = InstallCriterionService(client: bClient);
      final aRf = RFProfileService(client: aClient),
          bRf = RFProfileService(client: bClient);
      final studyIds = <int>[];
      final profileIds = <int>[];
      final criterionIds = <int>[];
      for (var index = 0; index < 2; index++) {
        final auth = index == 0 ? a : b;
        final rf = index == 0 ? aRf : bRf;
        final criteria = index == 0 ? aCriteria : bCriteria;
        final studies = index == 0 ? aStudies : bStudies;
        final profile = await rf.save({
          'nome': '${fixture['run']}_rf_$index',
          'frequencia_mhz': 915,
          'potencia_transmissao_dbm': 20,
          'sensibilidade_recepcao_dbm': -120,
        });
        profileIds.add(profile.id);
        await criteria.save({'nome': '${fixture['run']}_criterion_$index'});
        final criterion = (await criteria.list(userId: auth.user!.id))
            .items
            .single;
        criterionIds.add(criterion.id);
        final study = await studies.criarEstudo(
          NovoEstudo(
            idUsuario: auth.user!.id,
            idRfProfile: profile.id,
            idCriterioInstalacao: criterion.id,
            nome: '${fixture['run']}_study_$index',
            pontosArea: const [],
          ),
        );
        studyIds.add(study['id_estudo'] as int);
        expect(study['id_usuario'], auth.user!.id);
      }
      checks.add('perfil RF, critério e estudo persistidos para A e B');
      final aList = await aStudies.list(userId: a.user!.id);
      final bList = await bStudies.list(userId: b.user!.id);
      expect(aList.map((x) => x['id_estudo']), [studyIds[0]]);
      expect(bList.map((x) => x['id_estudo']), [studyIds[1]]);
      expect((await aRf.list(userId: a.user!.id)).items.map((x) => x.id), [
        profileIds[0],
      ]);
      expect((await bRf.list(userId: b.user!.id)).items.map((x) => x.id), [
        profileIds[1],
      ]);
      checks.add('listagens isoladas por usuário');
      await expectLater(
        bStudies.get(studyIds[0]),
        throwsA(
          isA<StudyApiException>().having((e) => e.status, 'status', 404),
        ),
      );
      await expectLater(
        bStudies.update(studyIds[0], {'nome': 'acesso negado'}),
        throwsA(
          isA<StudyApiException>().having((e) => e.status, 'status', 404),
        ),
      );
      await expectLater(
        bStudies.delete(studyIds[0]),
        throwsA(
          isA<StudyApiException>().having((e) => e.status, 'status', 404),
        ),
      );
      await expectLater(
        bRf.get(profileIds[0]),
        throwsA(
          isA<RFProfileApiException>().having((e) => e.status, 'status', 404),
        ),
      );
      await expectLater(
        bCriteria.get(criterionIds[0]),
        throwsA(
          isA<CriterionApiException>().having((e) => e.status, 'status', 404),
        ),
      );
      for (final method in ['PATCH', 'DELETE']) {
        final url = Uri.parse('$base/study/${studyIds[0]}');
        final response = method == 'PATCH'
            ? await bClient.patch(
                url,
                headers: {'Content-Type': 'application/json'},
                body: '{"nome":"acesso negado"}',
              )
            : await bClient.delete(url);
        expect(response.statusCode, 404);
      }
      checks.add(
        'consulta, alteração e exclusão de outro usuário: 404, inclusive aliases',
      );
      expect(
        (await bClient.get(Uri.parse('$base/estudos?id_usuario=${a.user!.id}')))
            .statusCode,
        403,
      );
      expect((await raw.get(Uri.parse('$base/estudos'))).statusCode, 401);
      checks.add('falsificação de proprietário: 403; acesso anônimo: 401');
      final changed = await aStudies.update(studyIds[0], {
        'nome': '${fixture['run']}_updated',
      });
      expect(changed['nome'], '${fixture['run']}_updated');
      checks.add('alteração pelo proprietário');
      final vegetation = await VegetacaoService(client: raw)
          .obterConfiguracao();
      expect(vegetation.product, isNotEmpty);
      await AtivosService(client: raw).getTiposDispositivos();
      checks.add('serviços públicos de vegetação e tipos de dispositivos');

      final oldToken = a.accessToken!;
      await a.logout();
      expect(aStore.token, isNull);
      expect(
        (await raw.get(
          Uri.parse('$base/estudos'),
          headers: {'Authorization': 'Bearer $oldToken'},
        )).statusCode,
        401,
      );
      await b.refreshUser();
      expect(b.user!.id, users[1].id);
      checks.add('logout revoga A e mantém B ativo');
      await a.login(
        email: accounts[0]['email'],
        password: accounts[0]['password'],
      );
      expect(a.accessToken, isNot(oldToken));
      expect((await aStudies.get(studyIds[0]))['id_estudo'], studyIds[0]);
      checks.add('novo login acessa o estudo salvo anteriormente');
      for (var index = 0; index < 2; index++) {
        await (index == 0 ? aStudies : bStudies).delete(studyIds[index]);
        await (index == 0 ? aRf : bRf).delete(profileIds[index]);
        await (index == 0 ? aCriteria : bCriteria).delete(criterionIds[index]);
      }
      await a.logout();
      await b.logout();
      checks.add('exclusão dos próprios recursos de teste e logout final');
      final report = {'passed': true, 'checks': checks, 'requests': records};
      File('${File(fixturePath).parent.path}/result.json')
          .writeAsStringSync(jsonEncode(report));
      // Only outcomes and HTTP statuses; tokens/passwords never enter test logs.
      // ignore: avoid_print
      print(
        jsonEncode({
          'passed': true,
          'checks': checks,
          'httpRequests': records.length,
        }),
      );
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
