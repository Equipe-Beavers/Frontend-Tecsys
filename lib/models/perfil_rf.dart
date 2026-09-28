class PerfilRf {
  final int? idPerfilRf;
  final String nome;
  final String modeloGateway;
  final double frequenciaMhz;
  final double potenciaTransmissaoDbm;
  final double sensibilidadeRecepcaoDbm;
  final double alturaGatewayM;
  final double alturaDispositivoM;

  const PerfilRf({
    this.idPerfilRf,
    required this.nome,
    required this.modeloGateway,
    required this.frequenciaMhz,
    required this.potenciaTransmissaoDbm,
    required this.sensibilidadeRecepcaoDbm,
    required this.alturaGatewayM,
    required this.alturaDispositivoM,
  });

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

  factory PerfilRf.fromJson(Map<String, dynamic> json) {
    return PerfilRf(
      idPerfilRf: (json['id_perfil_rf'] as num?)?.toInt(),
      nome: json['nome']?.toString() ?? 'Perfil sem nome',
      modeloGateway: json['modelo_gateway']?.toString() ?? 'Não informado',
      frequenciaMhz: (json['frequencia_mhz'] as num?)?.toDouble() ?? 0,
      potenciaTransmissaoDbm:
          (json['potencia_transmissao_dbm'] as num?)?.toDouble() ?? 0,
      sensibilidadeRecepcaoDbm:
          (json['sensibilidade_recepcao_dbm'] as num?)?.toDouble() ?? 0,
      alturaGatewayM: (json['altura_gateway_m'] as num?)?.toDouble() ?? 0,
      alturaDispositivoM: (json['altura_dispositivo_m'] as num?)?.toDouble() ?? 0,
    );
  }
}
