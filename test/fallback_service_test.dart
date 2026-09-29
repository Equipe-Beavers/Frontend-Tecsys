import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AtivosService', () {
    test('converte a resposta mesclada de distribuidoras', () async {
      final service = AtivosService(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/distribuidoras');
          return http.Response(
            jsonEncode([
              {
                'id': 390,
                'nome': 'Enel SP',
                'uf': 'SP',
                'anoBdgd': 2026,
                'totalAtivos': 1800539,
                'latitude': -23.59,
                'longitude': -46.66,
              },
              {
                'id': 103,
                'nome': 'CHESP',
                'uf': 'GO',
                'anoBdgd': 2026,
                'totalAtivos': 0,
                'latitude': null,
                'longitude': null,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final distribuidoras = await service.getDistribuidoras();

      expect(distribuidoras, hasLength(2));
      expect(distribuidoras.first.nome, 'Enel SP');
      expect(distribuidoras.first.totalAtivos, 1800539);
      expect(distribuidoras.first.possuiAtivosLocais, isTrue);
      expect(distribuidoras.last.possuiAtivosLocais, isFalse);
      expect(distribuidoras.first.latitude, isNotNull);
    });

    test('aplica busca por município no retorno do backend', () async {
      final service = AtivosService(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/ativos');
          expect(request.url.queryParameters['distribuidoras'], 'CEMIG Distribuição');

          return http.Response(
            jsonEncode({
              'total': 2,
              'data': [
                {
                  'id': 'POSTE:1',
                  'codId': 'P-1',
                  'tipo': 'POSTE',
                  'latitude': -19.45,
                  'longitude': -47.92,
                  'municipio': 'Uberaba',
                  'distribuidora': 'CEMIG Distribuição',
                },
                {
                  'id': 'POSTE:2',
                  'codId': 'P-2',
                  'tipo': 'POSTE',
                  'latitude': -19.46,
                  'longitude': -47.93,
                  'municipio': 'Uberlândia',
                  'distribuidora': 'CEMIG Distribuição',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.getAtivos(
        minLatitude: -20,
        maxLatitude: 0,
        minLongitude: -55,
        maxLongitude: -40,
        distribuidora: 'CEMIG Distribuição',
        busca: 'Uberaba',
      );

      expect(result.ativos, hasLength(1));
      expect(result.ativos.first.municipio, 'Uberaba');
      expect(result.total, 2);
    });

    test('envia município para o backend filtrar', () async {
      final service = AtivosService(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/ativos');
          expect(request.url.queryParameters['municipio'], 'Uberaba');

          return http.Response(
            jsonEncode({
              'total': 1,
              'data': [
                {
                  'id': 'POSTE:1',
                  'codId': 'P-1',
                  'tipo': 'POSTE',
                  'latitude': -19.45,
                  'longitude': -47.92,
                  'municipio': 'Uberaba',
                  'distribuidora': 'CEMIG Distribuição',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.getAtivos(
        minLatitude: -20,
        maxLatitude: 0,
        minLongitude: -55,
        maxLongitude: -40,
        distribuidora: 'CEMIG Distribuição',
        municipio: 'Uberaba',
      );

      expect(result.ativos, hasLength(1));
    });

    test('descarrega os municípios da distribuidora sem tocar em /api/ativos',
        () async {
      final service = AtivosService(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          expect(request.url.path, '/api/municipios');
          expect(request.url.queryParameters['distribuidora'], 'Enel SP');
          expect(request.url.queryParameters['pagina'], '1');
          expect(request.url.queryParameters['limite'], '100');
          expect(request.url.queryParameters.containsKey('minLatitude'), isFalse);

          return http.Response(
            jsonEncode({
              'dados': [
                {
                  'nome': 'São Paulo',
                  'uf': 'SP',
                  'totalAtivos': 1141235,
                  'lat': -23.55,
                  'lng': -46.63,
                },
                {'nome': 'Osasco', 'uf': 'SP', 'totalAtivos': 57202},
              ],
              'paginacao': {
                'pagina': 1,
                'limite': 100,
                'total': 2,
                'totalPaginas': 1,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final municipios = await service.getMunicipios(distribuidora: 'Enel SP');

      expect(municipios, hasLength(2));
      expect(municipios.first.nome, 'São Paulo');
      expect(municipios.first.latitude, -23.55);
      expect(municipios.first.longitude, -46.63);
      expect(municipios.first.totalAtivos, 1141235);
      expect(municipios.last.latitude, isNull);
    });

    test('repasses erro do backend como StateError', () async {
      final service = AtivosService(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          return http.Response('{"erro":"Informe distribuidora."}', 400);
        }),
      );

      expect(
        () => service.getMunicipios(distribuidora: 'Enel SP'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
