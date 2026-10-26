import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AtivosService', () {
    test('busca distribuidoras na rota de regiões do backend', () async {
      final service = AtivosService(
        client: MockClient((request) async {
          expect(request.url.path, '/distribuidoras');
          return http.Response(
            jsonEncode([
              {'id': 1, 'nome': 'CEMIG', 'uf': 'MG', 'anoBdgd': 2023},
            ]),
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final result = await service.getDistribuidoras();

      expect(result.single.nome, 'CEMIG');
    });

    test('busca tipos de dispositivos na rota de ativos', () async {
      final service = AtivosService(
        client: MockClient((request) async {
          expect(request.url.path, '/ativos/tipos-dispositivos');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 3, 'nome': 'Chave', 'categoria': 'Proteção'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final result = await service.getTiposDispositivos();

      expect(result.single.id, 3);
      expect(result.single.nome, 'Chave');
    });

    test(
      'busca todos os municípios filtrando pela distribuidora e UF',
      () async {
        var requestCount = 0;
        final service = AtivosService(
          client: MockClient((request) async {
            expect(request.url.path, '/municipios');
            expect(request.url.queryParameters['distribuidora'], 'CEMIG');
            expect(request.url.queryParameters['uf'], 'MG');
            expect(request.url.queryParameters['limite'], '100');
            requestCount++;

            final pagina = request.url.queryParameters['pagina'];
            if (pagina == '1') {
              return http.Response(
                jsonEncode({
                  'dados': [
                    {'nome': 'Uberaba', 'uf': 'MG'},
                  ],
                  'paginacao': {'totalPaginas': 2},
                }),
                200,
              );
            }

            expect(pagina, '2');
            return http.Response(
              jsonEncode({
                'dados': [
                  {'nome': 'Uberlândia', 'uf': 'MG'},
                ],
                'paginacao': {'totalPaginas': 2},
              }),
              200,
            );
          }),
        );
        addTearDown(service.dispose);

        final result = await service.getMunicipios(
          distribuidora: 'CEMIG',
          uf: 'MG',
        );

        expect(requestCount, 2);
        expect(result.map((municipio) => municipio.nome), [
          'Uberaba',
          'Uberlândia',
        ]);
      },
    );

    test('busca um ativo pelo ID na rota de detalhe', () async {
      final service = AtivosService(
        client: MockClient((request) async {
          expect(request.url.path, '/ativos/asset-1');
          return http.Response(
            jsonEncode({
              'active': {
                'id': 'asset-1',
                'tipo': 'POSTE',
                'latitude': -19.7,
                'longitude': -47.9,
              },
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final result = await service.getAtivoPorId('asset-1');

      expect(result.id, 'asset-1');
    });

    test('propaga falha de conexão sem inventar distribuidoras', () async {
      final service = AtivosService(
        client: MockClient((request) async {
          throw http.ClientException('Backend indisponível', request.url);
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.getDistribuidoras(),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('propaga falha de conexão sem inventar ativos', () async {
      final service = AtivosService(
        client: MockClient((request) async {
          throw http.ClientException('Backend indisponível', request.url);
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.getAtivos(
          minLatitude: -20,
          maxLatitude: 0,
          minLongitude: -55,
          maxLongitude: -40,
        ),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('inclui mensagem da API quando a consulta de ativos falha', () async {
      final service = AtivosService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Bounding Box inválido'}),
            400,
          );
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.getAtivos(
          minLatitude: -20,
          maxLatitude: 0,
          minLongitude: -55,
          maxLongitude: -40,
        ),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.toString().contains('Bounding Box inválido'),
          ),
        ),
      );
    });

    test('envia busca à API e filtra os ativos retornados', () async {
      final service = AtivosService(
        client: MockClient((request) async {
          expect(request.url.path, '/ativos');
          expect(
            request.url.queryParameters['distribuidoras'],
            'CEMIG Distribuição',
          );
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': '1',
                  'tipo': 'POSTE',
                  'municipio': 'Uberaba',
                  'distribuidora': 'CEMIG Distribuição',
                  'latitude': -19.7473,
                  'longitude': -47.9392,
                },
                {
                  'id': '2',
                  'tipo': 'POSTE',
                  'municipio': 'Uberlândia',
                  'distribuidora': 'CEMIG Distribuição',
                  'latitude': -18.9113,
                  'longitude': -48.2622,
                },
              ],
              'total': 2,
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final result = await service.getAtivos(
        minLatitude: -20,
        maxLatitude: 0,
        minLongitude: -55,
        maxLongitude: -40,
        distribuidora: 'CEMIG Distribuição',
        busca: 'Uberaba',
      );

      expect(result.ativos.map((ativo) => ativo.id), ['1']);
    });
  });
}
