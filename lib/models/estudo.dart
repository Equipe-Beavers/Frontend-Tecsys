class EstudoResumo {
  const EstudoResumo({
    required this.idEstudo,
    required this.nome,
    required this.status,
    this.descricao,
    this.distribuidora,
    this.municipio,
    this.uf,
    this.bairro,
    this.criadoEm,
    this.totalPontosInteresse = 0,
    this.totalPontosCandidato = 0,
  });

  final int idEstudo;
  final String nome;
  final String status;
  final String? descricao;
  final String? distribuidora;
  final String? municipio;
  final String? uf;
  final String? bairro;
  final String? criadoEm;
  final int totalPontosInteresse;
  final int totalPontosCandidato;

  bool get possuiPontos => totalPontosInteresse > 0 && totalPontosCandidato > 0;

  String get local {
    final partes = [municipio, uf].where((parte) => parte?.isNotEmpty == true);
    if (partes.isNotEmpty) return partes.join(' - ');
    if (distribuidora?.isNotEmpty == true) return distribuidora!;
    return 'Local não informado';
  }

  factory EstudoResumo.fromJson(Map<String, dynamic> json) {
    return EstudoResumo(
      idEstudo: (json['id_estudo'] as num?)?.toInt() ?? 0,
      nome: json['nome']?.toString() ?? 'Estudo sem nome',
      status: json['status']?.toString() ?? 'AGUARDANDO_SELECAO',
      descricao: json['descricao']?.toString(),
      distribuidora: json['distribuidora']?.toString(),
      municipio: json['municipio']?.toString(),
      uf: json['uf']?.toString(),
      bairro: json['bairro']?.toString(),
      criadoEm: json['criado_em']?.toString(),
    );
  }
}
