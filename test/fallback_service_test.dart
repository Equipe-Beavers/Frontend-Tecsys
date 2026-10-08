import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AtivosService', () {
    test('propaga falha de conexão sem inventar distribuidoras', () async {
      final service = AtivosService(client: MockClient((request) async {
        throw http.ClientException('Backend indisponível', request.url);
      }));
      addTearDown(service.dispose);

      await expectLater(
        service.getDistribuidoras(),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('propaga falha de conexão sem inventar ativos', () async {
      final service = AtivosService(client: MockClient((request) async {
        throw http.ClientException('Backend indisponível', request.url);
      }));
      addTearDown(service.dispose);

      await expectLater(
        service.getAtivos(
          minLatitude: -20, maxLatitude: 0,
          minLongitude: -55, maxLongitude: -40,
        ),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('envia busca à API e filtra os ativos retornados', () async {
      final service = AtivosService(client: MockClient((request) async {
        expect(request.url.path, '/api/ativos');
        expect(request.url.queryParameters['busca'], 'Uberaba');
        expect(request.url.queryParameters['distribuidoras'], 'CEMIG Distribuição');
        return http.Response(jsonEncode({
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
        }), 200);
      }));
      addTearDown(service.dispose);

      final result = await service.getAtivos(
        minLatitude: -20, maxLatitude: 0,
        minLongitude: -55, maxLongitude: -40,
        distribuidora: 'CEMIG Distribuição', busca: 'Uberaba',
      );

      expect(result.ativos.map((ativo) => ativo.id), ['1']);
    });
  });
}
