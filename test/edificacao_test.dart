import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/edificacao.dart';
import 'package:frontend_tecsys/utils/geojson_utils.dart';

void main() {
  final quadrado = <String, dynamic>{
    'type': 'MultiPolygon',
    'coordinates': [
      [
        [
          [-45.9, -23.2],
          [-45.8, -23.2],
          [-45.8, -23.1],
          [-45.9, -23.1],
          [-45.9, -23.2],
        ],
      ],
    ],
  };

  group('GeoJSON', () {
    test('converte MultiPolygon em anéis de LatLng', () {
      final aneis = aneisExternosGeoJson(quadrado);

      expect(aneis, hasLength(1));
      expect(aneis.first.first, const LatLng(-23.2, -45.9));
    });

    test('identifica ponto dentro e fora do polígono', () {
      final anel = aneisExternosGeoJson(quadrado).first;

      expect(pontoDentroDoPoligono(const LatLng(-23.15, -45.85), anel), isTrue);
      expect(pontoDentroDoPoligono(const LatLng(-23.3, -45.85), anel), isFalse);
    });
  });

  test('lê edificação com altura, largura, comprimento e material', () {
    final edificacao = Edificacao.fromJson({
      'id': '08b2a100-0000-0000-0000-000000000007',
      'altura_m': 12,
      'origem_altura': 'PAVIMENTOS',
      'pavimentos': 4,
      'largura_m': 10.5,
      'profundidade_m': 20,
      'area_m2': 210,
      'codigo_material': 'CIMENTO',
      'nome_material': 'Cimento / concreto',
      'origem_material': 'PADRAO',
      'perda_material_db': 12.1,
      'geometria': quadrado,
    });

    expect(edificacao.alturaM, 12);
    expect(edificacao.larguraM, 10.5);
    expect(edificacao.profundidadeM, 20);
    expect(edificacao.codigoMaterial, 'CIMENTO');
    expect(edificacao.id, '08b2a100-0000-0000-0000-000000000007');
    expect(edificacao.contem(const LatLng(-23.15, -45.85)), isTrue);
  });

  test('lê as manchas salvas de um cenário', () {
    final cenario = ManchaCenario.fromJson({
      'id_cenario': 1,
      'mancha_consolidada': quadrado,
      'gateways': [
        {
          'id_cenario_gateway': 3,
          'id_estudo_ponto': 1,
          'rotulo': null,
          'latitude': -23.15,
          'longitude': -45.85,
          'alcance_medio_m': 2310,
          'mancha_cobertura': {
            'type': 'Polygon',
            'coordinates': (quadrado['coordinates'] as List).first,
          },
        },
      ],
    });

    expect(cenario.vazia, isFalse);
    expect(cenario.manchaConsolidada, hasLength(1));
    expect(cenario.gateways.first.mancha, hasLength(5));
    expect(cenario.gateways.first.alcanceMedioM, 2310);
  });
}
