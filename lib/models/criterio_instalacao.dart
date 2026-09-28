class CriterioInstalacao {
  final String nome;
  final double alturaMinimaM;
  final bool requerAlimentacaoEletrica;
  final int limiteGateways;

  const CriterioInstalacao({
    required this.nome,
    required this.alturaMinimaM,
    required this.requerAlimentacaoEletrica,
    required this.limiteGateways,
  });

  static const CriterioInstalacao padrao = CriterioInstalacao(
    nome: 'Padrão urbano — Postes e SEs',
    alturaMinimaM: 6,
    requerAlimentacaoEletrica: true,
    limiteGateways: 40,
  );

  static const List<CriterioInstalacao> disponiveis = [padrao];
}
