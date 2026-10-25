import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/services/edificacoes_area_service.dart';

Map<String, dynamic> _edificacao(String id) => {
  'id': id,
  'altura_m': 12,
  'origem_altura': 'INFORMADA',
  'codigo_material': 'CONCRETO',
  'nome_material': 'Concreto',
  'origem_material': 'PADRAO',
  'perda_material_db': 12,
  'latitude': -23.2,
  'longitude': -45.9,
  'geometria': {
    'type': 'MultiPolygon',
    'coordinates': [
      [
        [
          [-45.9, -23.2],
          [-45.899, -23.2],
          [-45.899, -23.199],
          [-45.9, -23.199],
          [-45.9, -23.2],
        ],
      ],
    ],
  },
};

http.Response _json(Object corpo) => http.Response(
  jsonEncode(corpo),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _areaPequena = [
  LatLng(-23.200, -45.900),
  LatLng(-23.200, -45.895),
  LatLng(-23.195, -45.895),
  LatLng(-23.195, -45.900),
];

void main() {
  group('fatiar', () {
    test('área pequena vira uma única fatia', () {
      final fatias = EdificacoesAreaService.fatiar(
        LimitesArea.dosPontos(_areaPequena),
      );

      expect(fatias, hasLength(1));
      expect(fatias.single.minLatitude, -23.2);
      expect(fatias.single.maxLongitude, -45.895);
    });

    test('área grande é dividida sem passar do lado máximo e sem buracos', () {
      const area = LimitesArea(
        minLatitude: -23.20,
        maxLatitude: -23.165,
        minLongitude: -45.90,
        maxLongitude: -45.865,
      );

      final fatias = EdificacoesAreaService.fatiar(area);

      expect(fatias, hasLength(16));
      for (final f in fatias) {
        expect(
          f.maxLatitude - f.minLatitude,
          lessThanOrEqualTo(EdificacoesAreaService.ladoFatiaGraus + 1e-9),
        );
        expect(
          f.maxLongitude - f.minLongitude,
          lessThanOrEqualTo(EdificacoesAreaService.ladoFatiaGraus + 1e-9),
        );
      }
      expect(fatias.map((f) => f.minLatitude).reduce((a, b) => a < b ? a : b), area.minLatitude);
      expect(fatias.map((f) => f.maxLatitude).reduce((a, b) => a > b ? a : b), closeTo(area.maxLatitude, 1e-9));
    });
  });

  group('montarPayload', () {
    test('envia area, id, altura, material e geometria; sem perda em dB', () async {
      final cliente = MockClient((request) async {
        expect(request.url.path, '/list-buildings');
        expect(request.url.queryParameters['limit'], '5000');
        return _json({'data': [_edificacao('a')], 'total': 1});
      });
      final servico = EdificacoesAreaService(
        client: cliente,
        baseUrl: 'http://api.test',
      );

      final payload = await servico.montarPayload(_areaPequena);

      expect(payload, isNotNull);
      expect(payload!['area'], {
        'minLatitude': -23.2,
        'maxLatitude': -23.195,
        'minLongitude': -45.9,
        'maxLongitude': -45.895,
      });
      final itens = payload['itens'] as List;
      expect(itens, hasLength(1));
      final item = itens.single as Map;
      expect(item['id'], 'a');
      expect(item['altura_m'], 12);
      expect(item['codigo_material'], 'CONCRETO');
      expect(item.containsKey('perda_material_db'), isFalse);
      final primeiroPonto =
          (((item['geometria'] as Map)['coordinates'] as List).first as List)
              .first
              .first as List;
      expect(primeiroPonto, [-45.9, -23.2]);
    });

    test('envia só os prédios dentro do desenho e o contorno dele', () async {
      Map<String, dynamic> em(String id, double lat, double lon) => {
        ..._edificacao(id),
        'latitude': lat,
        'longitude': lon,
        'geometria': {
          'type': 'MultiPolygon',
          'coordinates': [
            [
              [
                [lon, lat],
                [lon + 0.0001, lat],
                [lon + 0.0001, lat + 0.0001],
                [lon, lat],
              ],
            ],
          ],
        },
      };
      final cliente = MockClient(
        (request) async => _json({
          'data': [
            em('dentro', -23.1985, -45.8985),
            em('fora', -23.1960, -45.8960),
          ],
          'total': 2,
        }),
      );
      final servico = EdificacoesAreaService(
        client: cliente,
        baseUrl: 'http://api.test',
      );

      final payload = await servico.montarPayload(const [
        LatLng(-23.200, -45.900),
        LatLng(-23.200, -45.895),
        LatLng(-23.195, -45.900),
      ]);

      final ids = (payload!['itens'] as List).map((e) => (e as Map)['id']);
      expect(ids, ['dentro']);
      expect(payload['poligono'], [
        [-45.9, -23.2],
        [-45.895, -23.2],
        [-45.9, -23.195],
      ]);
    });

    test('junta as fatias e remove edificação repetida na divisa', () async {
      var chamadas = 0;
      final cliente = MockClient((request) async {
        chamadas++;
        return _json({
          'data': [_edificacao('divisa'), _edificacao('so-desta-$chamadas')],
          'total': 2,
        });
      });
      final servico = EdificacoesAreaService(
        client: cliente,
        baseUrl: 'http://api.test',
      );
      final payload = await servico.montarPayload(const [
        LatLng(-23.20, -45.90),
        LatLng(-23.20, -45.88),
        LatLng(-23.19, -45.88),
        LatLng(-23.19, -45.90),
      ]);

      expect(chamadas, 2);
      final ids = (payload!['itens'] as List).map((e) => (e as Map)['id']);
      expect(ids, unorderedEquals(['divisa', 'so-desta-1', 'so-desta-2']));
    });

    test('não envia nada quando a resposta veio cortada pelo limite', () async {
      final cliente = MockClient(
        (request) async => _json({'data': [_edificacao('a')], 'total': 9000}),
      );
      final servico = EdificacoesAreaService(
        client: cliente,
        baseUrl: 'http://api.test',
      );

      expect(await servico.montarPayload(_areaPequena), isNull);
    });

    test('não envia nada quando a área exige fatias demais', () async {
      var chamadas = 0;
      final cliente = MockClient((request) async {
        chamadas++;
        return _json({'data': [], 'total': 0});
      });
      final servico = EdificacoesAreaService(
        client: cliente,
        baseUrl: 'http://api.test',
      );

      final payload = await servico.montarPayload(const [
        LatLng(-23.5, -46.0),
        LatLng(-23.5, -45.5),
        LatLng(-23.0, -45.5),
      ]);

      expect(payload, isNull);
      expect(chamadas, 0);
    });
  });

  group('paraEstudo', () {
    test('lê o polígono do estudo e busca as edificações dele', () async {
      final cliente = MockClient((request) async {
        if (request.url.path == '/estudos/7') {
          return _json({
            'estudo': {
              'id_estudo': 7,
              'geom': {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [-45.900, -23.200],
                    [-45.895, -23.200],
                    [-45.895, -23.195],
                    [-45.900, -23.195],
                    [-45.900, -23.200],
                  ],
                ],
              },
            },
          });
        }
        return _json({'data': [_edificacao('a')], 'total': 1});
      });
      final servico = EdificacoesAreaService(
        client: cliente,
        baseUrl: 'http://api.test',
      );

      final payload = await servico.paraEstudo(7);

      expect((payload!['itens'] as List), hasLength(1));
      expect((payload['area'] as Map)['minLatitude'], -23.2);
    });

    test('estudo sem polígono ou erro de rede devolve null, sem lançar', () async {
      final semPoligono = EdificacoesAreaService(
        client: MockClient(
          (request) async => _json({'estudo': {'id_estudo': 7, 'geom': null}}),
        ),
        baseUrl: 'http://api.test',
      );
      final comErro = EdificacoesAreaService(
        client: MockClient((request) async => http.Response('erro', 500)),
        baseUrl: 'http://api.test',
      );

      expect(await semPoligono.paraEstudo(7), isNull);
      expect(await comErro.paraEstudo(7), isNull);
    });
  });
}
