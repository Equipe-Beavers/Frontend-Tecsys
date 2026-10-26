import 'package:flutter/foundation.dart';
import 'package:frontend_tecsys/models/vegetacao_config.dart';
import 'package:frontend_tecsys/services/antenas_service.dart';
import 'package:frontend_tecsys/services/vegetacao_service.dart';
import 'package:http/http.dart' as http;

export 'antenas_service.dart' show AntenasResult;

class CamadasExternasService {
  CamadasExternasService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: kIsWeb
                  ? 'http://localhost:3000'
                  : 'http://10.0.2.2:3000',
            ) {
    _antenasService = AntenasService(client: _client, baseUrl: _baseUrl);
    _vegetacaoService = VegetacaoService(client: _client, baseUrl: _baseUrl);
  }

  final http.Client _client;
  final String _baseUrl;
  late final AntenasService _antenasService;
  late final VegetacaoService _vegetacaoService;

  Future<VegetacaoConfig> getVegetacaoConfig() =>
      _vegetacaoService.obterConfiguracao();

  Future<AntenasResult> getAntenas({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    int limit = 1000,
  }) {
    return _antenasService.listar(
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
      limit: limit,
    );
  }

  void dispose() => _client.close();
}
