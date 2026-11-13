import '../models/recomendacao_resultado.dart';

class RecommendationDatabaseMock {
  const RecommendationDatabaseMock({
    required this.cenario,
    required this.estudoPontos,
    required this.cenarioGateways,
    required this.cenarioAtendimentos,
  });

  final Map<String, dynamic> cenario;
  final List<Map<String, dynamic>> estudoPontos;
  final List<Map<String, dynamic>> cenarioGateways;
  final List<Map<String, dynamic>> cenarioAtendimentos;
}

RecommendationDatabaseMock buildRecommendationDatabaseMock({int studyId = 1}) {
  final scenarioId = 1000 + studyId;
  final now = DateTime(2026, 10, 21, 12).toIso8601String();

  final gatewayPoints = [
    _studyPoint(
      id: 14,
      studyId: studyId,
      role: 'candidato',
      bdgdId: 'PST-88213',
      type: 'POSTE',
      label: 'GW-14 · Poste MT 88213',
      latitude: -23.1914,
      longitude: -45.8840,
      attributes: const {
        'alimentador': 'SUL-14',
        'descricao_ativo': 'Poste de MT · concreto 11 m',
        'local': 'Av. Leopoldino de Oliveira, 2.140',
        'status': 'CANDIDATO OK',
      },
      createdAt: now,
    ),
    _studyPoint(
      id: 15,
      studyId: studyId,
      role: 'candidato',
      bdgdId: 'PST-00412',
      type: 'SUBESTACAO',
      label: 'GW-15 · SE Boa Vista 00412',
      latitude: -23.2168,
      longitude: -45.9005,
      attributes: const {
        'alimentador': 'SUL-15',
        'descricao_ativo': 'Subestação de distribuição',
        'local': 'Av. Cassiano Ricardo, 1.201',
        'status': 'CANDIDATO OK',
      },
      createdAt: now,
    ),
    _studyPoint(
      id: 16,
      studyId: studyId,
      role: 'candidato',
      bdgdId: 'PST-39118',
      type: 'POSTE',
      label: 'GW-16 · Poste MT 39118',
      latitude: -23.2050,
      longitude: -45.8460,
      attributes: const {
        'alimentador': 'SUL-16',
        'descricao_ativo': 'Poste de MT · concreto 11 m',
        'local': 'R. Paraibuna, 811',
        'status': 'CANDIDATO OK',
      },
      createdAt: now,
    ),
  ];

  final interestPoints = [
    _assetPoint(1401, studyId, 'RELIGADOR', -23.2014, -45.8980, now),
    _assetPoint(1402, studyId, 'CHAVE_FUSIVEL', -23.1794, -45.8750, now),
    _assetPoint(1403, studyId, 'REGULADOR_TENSAO', -23.1600, -45.9100, now),
    _assetPoint(1501, studyId, 'RELIGADOR', -23.2278, -45.8885, now),
    _assetPoint(1502, studyId, 'TRANSFORMADOR', -23.2078, -45.9115, now),
    _assetPoint(1503, studyId, 'CHAVE_FUSIVEL', -23.2500, -45.9200, now),
    _assetPoint(1601, studyId, 'REGULADOR_TENSAO', -23.1960, -45.8330, now),
    _assetPoint(1602, studyId, 'TRANSFORMADOR', -23.2170, -45.8560, now),
    _assetPoint(1603, studyId, 'CHAVE_FUSIVEL', -23.2250, -45.8100, now),
  ];

  final scenarioGateways = [
    _scenarioGateway(214, scenarioId, 14, 1, 4200),
    _scenarioGateway(215, scenarioId, 15, 2, 3800),
    _scenarioGateway(216, scenarioId, 16, 3, 3600),
  ];

  final attendances = [
    _attendance(1, 214, 1401, 1812, -97.4, now),
    _attendance(2, 214, 1402, 1621, -96.1, now),
    _attendance(3, 215, 1501, 1732, -96.8, now),
    _attendance(4, 215, 1502, 1505, -95.6, now),
    _attendance(5, 216, 1601, 1663, -96.3, now),
    _attendance(6, 216, 1602, 1681, -96.5, now),
  ];

  return RecommendationDatabaseMock(
    cenario: {
      'id_cenario': scenarioId,
      'id_estudo': studyId,
      'id_cenario_base': null,
      'nome': 'Recomendação inicial - estudo $studyId',
      'descricao': 'Cenário mockado no formato relacional do PostgreSQL',
      'objetivo': 'COBERTURA',
      'status': 'DEFINITIVO',
      'quantidade_gateways': scenarioGateways.length,
      'pontos_interesse': interestPoints.length,
      'pontos_cobertos': attendances.length,
      'pontos_nao_cobertos': interestPoints.length - attendances.length,
      'percentual_cobertura': 67,
      'capacidade_utilizada_media_pct': 2,
      'mancha_consolidada': null,
      'executado_em': now,
      'criado_em': now,
      'atualizado_em': null,
    },
    estudoPontos: [...gatewayPoints, ...interestPoints],
    cenarioGateways: scenarioGateways,
    cenarioAtendimentos: attendances,
  );
}

ResultadoRecomendacao buildRecommendationMock({int studyId = 1}) {
  final database = buildRecommendationDatabaseMock(studyId: studyId);
  final pointsById = {
    for (final point in database.estudoPontos)
      point['id_estudo_ponto'] as int: point,
  };
  final attendancesByGateway = <int, List<Map<String, dynamic>>>{};
  for (final attendance in database.cenarioAtendimentos) {
    attendancesByGateway
        .putIfAbsent(attendance['id_cenario_gateway'] as int, () => [])
        .add(attendance);
  }

  final gateways = database.cenarioGateways.map((gatewayRow) {
    final gatewayPoint = pointsById[gatewayRow['id_estudo_ponto']]!;
    final gatewayAttendances =
        attendancesByGateway[gatewayRow['id_cenario_gateway']] ?? const [];
    final parameters = _asMap(gatewayRow['parametros_calculo']);

    return GatewayProposto(
      idEstudoPonto: gatewayPoint['id_estudo_ponto'] as int,
      idAtivoBdgd: gatewayPoint['id_ativo_bdgd']?.toString(),
      rotulo: gatewayPoint['rotulo']?.toString(),
      latitude: _asDouble(gatewayPoint['latitude']),
      longitude: _asDouble(gatewayPoint['longitude']),
      quantidadeAtendidos:
          (gatewayRow['quantidade_pontos_atendidos'] as num?)?.toInt() ??
          gatewayAttendances.length,
      atributos: {..._asMap(gatewayPoint['atributos']), ...parameters},
      atendidos: gatewayAttendances.map((attendance) {
        final point = pointsById[attendance['id_estudo_ponto']]!;
        return AtendimentoGateway(
          idEstudoPonto: point['id_estudo_ponto'] as int,
          tipoAtivo: tipoAtivoFromApiValue(point['tipo_ativo']?.toString()),
          distanciaM: (attendance['distancia_m'] as num).round(),
          nivelSinalEstimadoDbm: _asDouble(
            attendance['nivel_sinal_estimado_dbm'],
          ),
          atributos: {
            ..._asMap(point['atributos']),
            'latitude': point['latitude'],
            'longitude': point['longitude'],
          },
        );
      }).toList(),
    );
  }).toList();

  final gatewayPointByScenarioGateway = {
    for (final row in database.cenarioGateways)
      row['id_cenario_gateway'] as int: row['id_estudo_ponto'] as int,
  };
  final gatewayReferenceByAsset = {
    for (final attendance in database.cenarioAtendimentos)
      attendance['id_estudo_ponto'] as int:
          gatewayPointByScenarioGateway[attendance['id_cenario_gateway']]!,
  };
  final interestPoints = database.estudoPontos
      .where((point) => point['papel'] == 'interesse')
      .toList();
  final assets = interestPoints.map((point) {
    final pointId = point['id_estudo_ponto'] as int;
    return AtivoResultadoMapa(
      idEstudoPonto: pointId,
      idAtivoBdgd: point['id_ativo_bdgd']?.toString(),
      tipoAtivo: tipoAtivoFromApiValue(point['tipo_ativo']?.toString()),
      latitude: _asDouble(point['latitude']),
      longitude: _asDouble(point['longitude']),
      coberto: gatewayReferenceByAsset.containsKey(pointId),
      idGatewayReferencia:
          gatewayReferenceByAsset[pointId] ?? _nearestGateway(point, gateways),
    );
  }).toList();

  final coveredIds = gatewayReferenceByAsset.keys.toSet();
  final totalsByType = <String, int>{};
  final uncoveredByType = <String, int>{};
  for (final point in interestPoints) {
    final type = point['tipo_ativo']?.toString() ?? 'DISPOSITIVO';
    totalsByType.update(type, (value) => value + 1, ifAbsent: () => 1);
    if (!coveredIds.contains(point['id_estudo_ponto'])) {
      uncoveredByType.update(type, (value) => value + 1, ifAbsent: () => 1);
    }
  }

  final totalCost = database.cenarioGateways.fold<double>(
    0,
    (total, row) =>
        total + _asDouble(_asMap(row['parametros_calculo'])['custo_estimado']),
  );
  final scenario = database.cenario;

  return ResultadoRecomendacao(
    idCenario: scenario['id_cenario'] as int,
    quantidadeGateways: (scenario['quantidade_gateways'] as num).toInt(),
    percentualCobertura: (scenario['percentual_cobertura'] as num).toInt(),
    custoTotalEstimado: totalCost,
    pontosInteresse: (scenario['pontos_interesse'] as num).toInt(),
    pontosCobertos: (scenario['pontos_cobertos'] as num).toInt(),
    pontosNaoCobertos: (scenario['pontos_nao_cobertos'] as num).toInt(),
    porCategoria: totalsByType.entries
        .map(
          (entry) => CategoriaCobertura(
            tipo: tipoAtivoFromApiValue(entry.key),
            total: entry.value,
            naoCobertos: uncoveredByType[entry.key] ?? 0,
          ),
        )
        .toList(),
    gateways: gateways,
    ativosMapa: assets,
  );
}

Map<String, dynamic> _studyPoint({
  required int id,
  required int studyId,
  required String role,
  required String bdgdId,
  required String type,
  required String label,
  required double latitude,
  required double longitude,
  required Map<String, dynamic> attributes,
  required String createdAt,
}) => {
  'id_estudo_ponto': id,
  'id_estudo': studyId,
  'origem': 'bdgd',
  'id_ativo_bdgd': bdgdId,
  'tipo_ativo': type,
  'rotulo': label,
  'papel': role,
  'prioridade': 'normal',
  'latitude': latitude,
  'longitude': longitude,
  'atributos': attributes,
  'geom': null,
  'criado_em': createdAt,
};

Map<String, dynamic> _assetPoint(
  int id,
  int studyId,
  String type,
  double latitude,
  double longitude,
  String createdAt,
) => _studyPoint(
  id: id,
  studyId: studyId,
  role: 'interesse',
  bdgdId: 'ATV-$id',
  type: type,
  label: '$type $id',
  latitude: latitude,
  longitude: longitude,
  attributes: const {},
  createdAt: createdAt,
);

Map<String, dynamic> _scenarioGateway(
  int id,
  int scenarioId,
  int pointId,
  int order,
  double radius,
) => {
  'id_cenario_gateway': id,
  'id_cenario': scenarioId,
  'id_estudo_ponto': pointId,
  'ordem': order,
  'quantidade_pontos_atendidos': 2,
  'capacidade_utilizada_pct': 2,
  'parametros_calculo': {'raio_cobertura_m': radius, 'custo_estimado': 135000},
  'mancha_cobertura': null,
};

Map<String, dynamic> _attendance(
  int id,
  int scenarioGatewayId,
  int pointId,
  double distance,
  double signal,
  String createdAt,
) => {
  'id_atendimento': id,
  'id_cenario_gateway': scenarioGatewayId,
  'id_estudo_ponto': pointId,
  'distancia_m': distance,
  'nivel_sinal_estimado_dbm': signal,
  'criado_em': createdAt,
};

int? _nearestGateway(
  Map<String, dynamic> point,
  List<GatewayProposto> gateways,
) {
  if (gateways.isEmpty) return null;
  final latitude = _asDouble(point['latitude']);
  final longitude = _asDouble(point['longitude']);
  var nearest = gateways.first;
  var shortest = double.infinity;
  for (final gateway in gateways) {
    final latitudeDelta = latitude - gateway.latitude;
    final longitudeDelta = longitude - gateway.longitude;
    final squaredDistance =
        latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
    if (squaredDistance < shortest) {
      shortest = squaredDistance;
      nearest = gateway;
    }
  }
  return nearest.idEstudoPonto;
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
