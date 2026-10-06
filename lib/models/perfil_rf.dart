class PerfilRf {
  final int? id;
  final int idUsuario;
  final String nome;
  final String modeloGateway;
  final double frequenciaMhz;
  final double potenciaTransmissaoDbm;
  final double sensibilidadeRecepcaoDbm;
  final double alturaGatewayM;
  final double alturaDispositivoM;
  final double? alcanceEstimadoM;
  final int? capacidadeMaxEquipamentos;
  final int? quantidadeCanais;
  final int? limiteMensagens;
  final String? periodoLimiteMensagens;
  final double? custoEstimadoGateway;
  final Map<String, dynamic> caracteristicasAntena;
  final Map<String, dynamic> parametrosAdicionais;
  final bool consideraRelevo;
  final bool consideraVegetacao;
  final bool consideraEdificacoes;
  final bool consideraObstaculos;

  const PerfilRf({
    this.id,
    this.idUsuario = 1,
    required this.nome,
    required this.modeloGateway,
    required this.frequenciaMhz,
    required this.potenciaTransmissaoDbm,
    required this.sensibilidadeRecepcaoDbm,
    required this.alturaGatewayM,
    required this.alturaDispositivoM,
    this.alcanceEstimadoM,
    this.capacidadeMaxEquipamentos,
    this.quantidadeCanais,
    this.limiteMensagens,
    this.periodoLimiteMensagens,
    this.custoEstimadoGateway,
    this.caracteristicasAntena = const {},
    this.parametrosAdicionais = const {},
    this.consideraRelevo = false,
    this.consideraVegetacao = false,
    this.consideraEdificacoes = false,
    this.consideraObstaculos = false,
  });

  factory PerfilRf.fromJson(Map<String, dynamic> dados) => PerfilRf(
    id: (dados['id_perfil_rf'] as num?)?.toInt(),
    idUsuario: (dados['id_usuario'] as num).toInt(),
    nome: dados['nome'] as String,
    modeloGateway: dados['modelo_gateway'] as String? ?? '',
    frequenciaMhz: (dados['frequencia_mhz'] as num).toDouble(),
    potenciaTransmissaoDbm: (dados['potencia_transmissao_dbm'] as num)
        .toDouble(),
    sensibilidadeRecepcaoDbm: (dados['sensibilidade_recepcao_dbm'] as num)
        .toDouble(),
    alturaGatewayM: (dados['altura_gateway_m'] as num?)?.toDouble() ?? 0,
    alturaDispositivoM:
        (dados['altura_dispositivo_m'] as num?)?.toDouble() ?? 0,
    alcanceEstimadoM: (dados['alcance_estimado_m'] as num?)?.toDouble(),
    capacidadeMaxEquipamentos: (dados['capacidade_max_equipamentos'] as num?)
        ?.toInt(),
    quantidadeCanais: (dados['quantidade_canais'] as num?)?.toInt(),
    limiteMensagens: (dados['limite_mensagens_transmissoes'] as num?)?.toInt(),
    periodoLimiteMensagens: dados['periodo_limite_mensagens'] as String?,
    custoEstimadoGateway: (dados['custo_estimado_gateway'] as num?)?.toDouble(),
    caracteristicasAntena: Map<String, dynamic>.from(
      dados['caracteristicas_antena'] as Map? ?? {},
    ),
    parametrosAdicionais: Map<String, dynamic>.from(
      dados['parametros_adicionais'] as Map? ?? {},
    ),
    consideraRelevo: dados['considera_relevo'] == true,
    consideraVegetacao: dados['considera_vegetacao'] == true,
    consideraEdificacoes: dados['considera_edificacoes'] == true,
    consideraObstaculos: dados['considera_obstaculos'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id_usuario': idUsuario,
    'nome': nome,
    'modelo_gateway': modeloGateway,
    'frequencia_mhz': frequenciaMhz,
    'potencia_transmissao_dbm': potenciaTransmissaoDbm,
    'sensibilidade_recepcao_dbm': sensibilidadeRecepcaoDbm,
    'altura_gateway_m': alturaGatewayM,
    'altura_dispositivo_m': alturaDispositivoM,
    'alcance_estimado_m': alcanceEstimadoM,
    'capacidade_max_equipamentos': capacidadeMaxEquipamentos,
    'quantidade_canais': quantidadeCanais,
    'limite_mensagens_transmissoes': limiteMensagens,
    'periodo_limite_mensagens': periodoLimiteMensagens,
    'custo_estimado_gateway': custoEstimadoGateway,
    'caracteristicas_antena': caracteristicasAntena,
    'parametros_adicionais': parametrosAdicionais,
    'considera_relevo': consideraRelevo,
    'considera_vegetacao': consideraVegetacao,
    'considera_edificacoes': consideraEdificacoes,
    'considera_obstaculos': consideraObstaculos,
  };

  static const PerfilRf padrao = PerfilRf(
    nome: 'Perfil padrão',
    modeloGateway: 'LoRaWAN',
    frequenciaMhz: 915,
    potenciaTransmissaoDbm: 21,
    sensibilidadeRecepcaoDbm: -120,
    alturaGatewayM: 6,
    alturaDispositivoM: 5,
  );

  static const List<PerfilRf> disponiveis = [padrao];
}
