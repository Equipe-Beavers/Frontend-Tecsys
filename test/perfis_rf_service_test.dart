import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';
import 'package:frontend_tecsys/services/perfis_rf_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Executa listagem, criacao, edicao e exclusao nos endpoints RF',
    () async {
      final requisicoes = <http.Request>[];
      final dados = {...PerfilRf.padrao.toJson(), 'id_perfil_rf': 7};
      final servico = PerfisRfService(
        cliente: MockClient((requisicao) async {
          requisicoes.add(requisicao);
          if (requisicao.method == 'GET')
            return http.Response(
              jsonEncode({
                'perfis': [dados],
              }),
              200,
            );
          if (requisicao.method == 'DELETE') return http.Response('{}', 200);
          expect(
            jsonDecode(requisicao.body)['sensibilidade_recepcao_dbm'],
            -120,
          );
          return http.Response(
            jsonEncode({
              requisicao.method == 'POST' ? 'perfil' : 'perfis': dados,
            }),
            requisicao.method == 'POST' ? 201 : 200,
          );
        }),
      );
      addTearDown(servico.dispose);
      expect((await servico.listar()).single.id, 7);
      final criado = await servico.salvar(PerfilRf.padrao);
      await servico.salvar(criado);
      await servico.excluir(criado.id!);
      expect(requisicoes.map((requisicao) => requisicao.method), [
        'GET',
        'POST',
        'PATCH',
        'DELETE',
      ]);
      expect(requisicoes.last.url.path, '/perfis-rf/7');
    },
  );

  test('Apresenta erro do backend sem assumir sucesso', () async {
    final servico = PerfisRfService(
      cliente: MockClient(
        (_) async => http.Response(jsonEncode({'erro': 'Perfil em uso'}), 400),
      ),
    );
    addTearDown(servico.dispose);
    await expectLater(servico.excluir(1), throwsA(isA<StateError>()));
  });
}
