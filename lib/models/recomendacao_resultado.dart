import 'package:frontend_tecsys/models/ativo_bdgd.dart';

TipoAtivo tipoAtivoFromApiValue(String? value) {
  if (value == null) return TipoAtivo.dispositivo;
  return TipoAtivo.values.firstWhere(
    (t) => t.apiValue == value.toUpperCase(),
    orElse: () => TipoAtivo.dispositivo,
  );
}

Map<String, dynamic> _asAttrMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class CategoriaCobertura {
  final TipoAtivo tipo;
  final int total;
  final int naoCobertos;

  const CategoriaCobertura({
    required this.tipo,
    required this.total,
    required this.naoCobertos,
  });

  int get cobertos => total - naoCobertos;

  factory CategoriaCobertura.fromJson(Map<String, dynamic> json) {
    return CategoriaCobertura(
      tipo: tipoAtivoFromApiValue(json['tipo_ativo']?.toString()),
      total: (json['total'] as num).toInt(),
      naoCobertos: (json['nao_cobertos'] as num).toInt(),
    );
  }
}

class AtendimentoGateway {
  final int idEstudoPonto;
  final TipoAtivo tipoAtivo;
  final int distanciaM;
  final double nivelSinalEstimadoDbm;
  final Map<String, dynamic> atributos;

  const AtendimentoGateway({
    required this.idEstudoPonto,
    required this.tipoAtivo,
    required this.distanciaM,
    required this.nivelSinalEstimadoDbm,
    required this.atributos,
  });

  factory AtendimentoGateway.fromJson(Map<String, dynamic> json) {
    return AtendimentoGateway(
      idEstudoPonto: (json['id_estudo_ponto'] as num).toInt(),
      tipoAtivo: tipoAtivoFromApiValue(json['tipo_ativo']?.toString()),
      distanciaM: (json['distancia_m'] as num).toInt(),
      nivelSinalEstimadoDbm: (json['nivel_sinal_estimado_dbm'] as num).toDouble(),
      atributos: _asAttrMap(json['atributos']),
    );
  }
}

class GatewayProposto {
  final int idEstudoPonto;
  final String? idAtivoBdgd;
  final String? rotulo;
  final double latitude;
  final double longitude;
  final int quantidadeAtendidos;
  final Map<String, dynamic> atributos;
  final List<AtendimentoGateway> atendidos;

  const GatewayProposto({
    required this.idEstudoPonto,
    required this.idAtivoBdgd,
    required this.rotulo,
    required this.latitude,
    required this.longitude,
    required this.quantidadeAtendidos,
    required this.atributos,
    required this.atendidos,
  });

  String? get alimentador => atributos['alimentador']?.toString();
  String? get descricaoAtivo => atributos['descricao_ativo']?.toString();

  factory GatewayProposto.fromJson(Map<String, dynamic> json) {
    return GatewayProposto(
      idEstudoPonto: (json['id_estudo_ponto'] as num).toInt(),
      idAtivoBdgd: json['id_ativo_bdgd']?.toString(),
      rotulo: json['rotulo']?.toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      quantidadeAtendidos: (json['quantidade_atendidos'] as num).toInt(),
      atributos: _asAttrMap(json['atributos']),
      atendidos: (json['atendidos'] as List? ?? [])
          .map((e) => AtendimentoGateway.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class ResultadoRecomendacao {
  final int idCenario;
  final int quantidadeGateways;
  final int percentualCobertura;
  final double custoTotalEstimado;
  final int pontosInteresse;
  final int pontosCobertos;
  final int pontosNaoCobertos;
  final List<CategoriaCobertura> porCategoria;
  final List<GatewayProposto> gateways;

  const ResultadoRecomendacao({
    required this.idCenario,
    required this.quantidadeGateways,
    required this.percentualCobertura,
    required this.custoTotalEstimado,
    required this.pontosInteresse,
    required this.pontosCobertos,
    required this.pontosNaoCobertos,
    required this.porCategoria,
    required this.gateways,
  });

  factory ResultadoRecomendacao.fromJson(Map<String, dynamic> json) {
    return ResultadoRecomendacao(
      idCenario: (json['id_cenario'] as num).toInt(),
      quantidadeGateways: (json['quantidade_gateways'] as num).toInt(),
      percentualCobertura: (json['percentual_cobertura'] as num).toInt(),
      custoTotalEstimado: (json['custo_total_estimado'] as num).toDouble(),
      pontosInteresse: (json['pontos_interesse'] as num).toInt(),
      pontosCobertos: (json['pontos_cobertos'] as num).toInt(),
      pontosNaoCobertos: (json['pontos_nao_cobertos'] as num).toInt(),
      porCategoria: (json['por_categoria'] as List? ?? [])
          .map((e) => CategoriaCobertura.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      gateways: (json['gateways'] as List? ?? [])
          .map((e) => GatewayProposto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    ); 
  }
}