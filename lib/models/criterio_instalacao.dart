class CriterioInstalacao {
  final int? idCriterioInstalacao;
  final String nome;
  final double alturaMinimaM;
  final bool requerAlimentacaoEletrica;
  final int limiteGateways;

  const CriterioInstalacao({
    this.idCriterioInstalacao,
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

  factory CriterioInstalacao.fromJson(Map<String, dynamic> json) {
    return CriterioInstalacao(
      idCriterioInstalacao: (json['id_criterio_instalacao'] as num?)?.toInt(),
      nome: json['nome']?.toString() ?? 'Critério sem nome',
      alturaMinimaM: (json['altura_minima_m'] as num?)?.toDouble() ?? 0,
      requerAlimentacaoEletrica:
          json['requer_alimentacao_eletrica'] as bool? ?? false,
      limiteGateways: (json['limite_gateways'] as num?)?.toInt() ?? 0,
    );
  }
}
