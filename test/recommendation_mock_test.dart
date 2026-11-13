import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/mocks/recomendacao_mock.dart';
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('database mock mirrors recommendation tables and relationships', () {
    final database = buildRecommendationDatabaseMock(studyId: 42);

    expect(database.cenario.keys.toSet(), {
      'id_cenario',
      'id_estudo',
      'id_cenario_base',
      'nome',
      'descricao',
      'objetivo',
      'status',
      'quantidade_gateways',
      'pontos_interesse',
      'pontos_cobertos',
      'pontos_nao_cobertos',
      'percentual_cobertura',
      'capacidade_utilizada_media_pct',
      'mancha_consolidada',
      'executado_em',
      'criado_em',
      'atualizado_em',
    });
    expect(database.estudoPontos.first.keys.toSet(), {
      'id_estudo_ponto',
      'id_estudo',
      'origem',
      'id_ativo_bdgd',
      'tipo_ativo',
      'rotulo',
      'papel',
      'prioridade',
      'latitude',
      'longitude',
      'atributos',
      'geom',
      'criado_em',
    });
    expect(database.cenarioGateways.first.keys.toSet(), {
      'id_cenario_gateway',
      'id_cenario',
      'id_estudo_ponto',
      'ordem',
      'quantidade_pontos_atendidos',
      'capacidade_utilizada_pct',
      'parametros_calculo',
      'mancha_cobertura',
    });
    expect(database.cenarioAtendimentos.first.keys.toSet(), {
      'id_atendimento',
      'id_cenario_gateway',
      'id_estudo_ponto',
      'distancia_m',
      'nivel_sinal_estimado_dbm',
      'criado_em',
    });

    final pointIds = database.estudoPontos
        .map((row) => row['id_estudo_ponto'])
        .toSet();
    final scenarioGatewayIds = database.cenarioGateways
        .map((row) => row['id_cenario_gateway'])
        .toSet();

    for (final gateway in database.cenarioGateways) {
      expect(gateway['id_cenario'], database.cenario['id_cenario']);
      expect(pointIds, contains(gateway['id_estudo_ponto']));
      expect(
        gateway['quantidade_pontos_atendidos'],
        database.cenarioAtendimentos
            .where(
              (row) =>
                  row['id_cenario_gateway'] == gateway['id_cenario_gateway'],
            )
            .length,
      );
    }
    for (final attendance in database.cenarioAtendimentos) {
      expect(scenarioGatewayIds, contains(attendance['id_cenario_gateway']));
      expect(pointIds, contains(attendance['id_estudo_ponto']));
    }

    final result = buildRecommendationMock(studyId: 42);
    expect(result.quantidadeGateways, database.cenarioGateways.length);
    expect(result.pontosInteresse, 9);
    expect(result.pontosCobertos, database.cenarioAtendimentos.length);
    expect(result.pontosNaoCobertos, 3);
    expect(result.custoTotalEstimado, 405000);
  });

  test(
    'uses configured coverage radius and falls back to attendance distance',
    () {
      final configured = buildRecommendationMock().gateways.first;
      expect(configured.raioCoberturaM, 4200);

      final fallback = GatewayProposto(
        idEstudoPonto: 1,
        idAtivoBdgd: null,
        rotulo: null,
        latitude: 0,
        longitude: 0,
        quantidadeAtendidos: 1,
        atributos: const {},
        atendidos: [configured.atendidos.first],
      );
      expect(fallback.raioCoberturaM, configured.atendidos.first.distanciaM);
    },
  );

  test('mock includes covered and uncovered map assets', () {
    final result = buildRecommendationMock();
    expect(result.ativosMapa.where((asset) => asset.coberto), hasLength(6));
    expect(result.ativosMapa.where((asset) => !asset.coberto), hasLength(3));

    const distance = Distance();
    for (final asset in result.ativosMapa) {
      final distances = result.gateways.map(
        (gateway) => distance.as(
          LengthUnit.Meter,
          LatLng(asset.latitude, asset.longitude),
          LatLng(gateway.latitude, gateway.longitude),
        ),
      );
      if (asset.coberto) {
        final gateway = result.gateways.singleWhere(
          (item) => item.idEstudoPonto == asset.idGatewayReferencia,
        );
        expect(
          distances.elementAt(result.gateways.indexOf(gateway)),
          lessThan(gateway.raioCoberturaM),
        );
      } else {
        for (var index = 0; index < result.gateways.length; index++) {
          expect(
            distances.elementAt(index),
            greaterThan(result.gateways[index].raioCoberturaM),
          );
        }
      }
    }
  });
}
