class PerfilRf {
  final String nome;
  final String modeloGateway;
  final double frequenciaMhz;
  final double potenciaTransmissaoDbm;
  final double sensibilidadeRecepcaoDbm;
  final double alturaGatewayM;
  final double alturaDispositivoM;

  const PerfilRf({
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
}
