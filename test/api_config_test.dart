import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/config/api_config.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/services/antenas_service.dart';
import 'package:frontend_tecsys/services/vegetacao_service.dart';
import 'package:frontend_tecsys/services/emissoes_rf_service.dart';
import 'package:frontend_tecsys/services/camadas_externas_service.dart';
import 'package:frontend_tecsys/services/edificacoes_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    dotenv.clean();
    debugDefaultTargetPlatformOverride = null;
  });

  test('configuração runtime e override removem espaços e barras finais', () {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://api.example.test/base///');
    expect(ApiConfig.baseUrl, 'https://api.example.test/base');
    expect(
      ApiConfig.resolve(' https://override.example.test/// '),
      'https://override.example.test',
    );
  });

  test('desktop mantém fallback local; plataforma não sobrepõe .env', () {
    dotenv.testLoad(fileInput: '');
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(ApiConfig.baseUrl, 'http://localhost:3000');
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://192.0.2.10:3000');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(ApiConfig.baseUrl, 'http://192.0.2.10:3000');
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(ApiConfig.baseUrl, 'http://192.0.2.10:3000');
  });

  test(
    'todos os serviços públicos do mapa usam a mesma configuração runtime',
    () async {
      dotenv.testLoad(
        fileInput: 'API_BASE_URL=https://configured.example.test/base///',
      );
      final paths = <String>[];
      final client = MockClient((request) async {
        expect(request.url.origin, 'https://configured.example.test');
        expect(request.url.path, startsWith('/base/'));
        expect(request.url.path, isNot(contains('//')));
        expect(request.headers.containsKey('authorization'), isFalse);
        paths.add(request.url.path);
        final body = request.url.path.endsWith('/distribuidoras')
            ? '[]'
            : request.url.path.endsWith('/vegetacao/config')
            ? '{}'
            : '{"data":[],"total":0}';
        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final assets = AtivosService(client: client);
      final antennas = AntenasService(client: client);
      final vegetation = VegetacaoService(client: client);
      final emissions = EmissoesRfService(client: client);
      final layers = CamadasExternasService(client: client);
      final buildings = EdificacoesService(client: client);
      addTearDown(assets.dispose);
      addTearDown(antennas.dispose);
      addTearDown(vegetation.dispose);
      addTearDown(emissions.dispose);
      addTearDown(layers.dispose);
      addTearDown(buildings.dispose);
      await assets.getDistribuidoras();
      await antennas.listar(
        minLatitude: -23.2,
        maxLatitude: -23.19,
        minLongitude: -45.9,
        maxLongitude: -45.89,
      );
      await vegetation.obterConfiguracao();
      await emissions.listar(
        minLatitude: -23.2,
        maxLatitude: -23.19,
        minLongitude: -45.9,
        maxLongitude: -45.89,
      );
      await layers.getVegetacaoConfig();
      await layers.getAntenas(
        minLatitude: -23.2,
        maxLatitude: -23.19,
        minLongitude: -45.9,
        maxLongitude: -45.89,
      );
      await buildings.getEdificacoes(
        minLatitude: -23.2,
        maxLatitude: -23.19,
        minLongitude: -45.9,
        maxLongitude: -45.89,
      );
      expect(paths, [
        '/base/distribuidoras',
        '/base/antenas',
        '/base/vegetacao/config',
        '/base/emissoes-rf',
        '/base/vegetacao/config',
        '/base/antenas',
        '/base/list-buildings',
      ]);
    },
  );
}
