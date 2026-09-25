import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';

void main() {
  group('AtivosService fallback', () {
    test('retorna distribuidoras mesmo sem backend', () async {
      final service = AtivosService(baseUrl: 'http://127.0.0.1:1');

      final distribuidoras = await service.getDistribuidoras();

      expect(distribuidoras, isNotEmpty);
      expect(distribuidoras.first.nome, isNotEmpty);
    });

    test('aplica busca por município no fallback', () async {
      final service = AtivosService(baseUrl: 'http://127.0.0.1:1');

      final result = await service.getAtivos(
        minLatitude: -20,
        maxLatitude: 0,
        minLongitude: -55,
        maxLongitude: -40,
        distribuidora: 'CEMIG Distribuição',
        busca: 'Uberaba',
      );

      expect(result.ativos, isNotEmpty);
      expect(result.ativos.every((ativo) => ativo.municipio.toLowerCase().contains('uberaba') || ativo.bairro.toLowerCase().contains('uberaba')), isTrue);
    });
  });
}
