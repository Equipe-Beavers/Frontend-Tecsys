class EstudoResumo {
  const EstudoResumo({
    required this.id,
    required this.nome,
    required this.status,
    required this.tipoDelimitacao,
    required this.municipio,
    required this.uf,
    required this.bairro,
    required this.distribuidora,
    required this.descricao,
    required this.criadoEm,
  });

  final int id;
  final String nome;
  final String status;
  final String tipoDelimitacao;
  final String? municipio;
  final String? uf;
  final String? bairro;
  final String? distribuidora;
  final String? descricao;
  final DateTime? criadoEm;

  factory EstudoResumo.fromJson(Map<String, dynamic> json) {
    return EstudoResumo(
      id: (json['id_estudo'] as num?)?.toInt() ?? 0,
      nome: json['nome']?.toString() ?? 'Estudo sem nome',
      status: json['status']?.toString() ?? 'NÃO INFORMADO',
      tipoDelimitacao: json['tipo_delimitacao']?.toString() ?? 'desenho',
      municipio: _textoOuNulo(json['municipio']),
      uf: _textoOuNulo(json['uf']),
      bairro: _textoOuNulo(json['bairro']),
      distribuidora: _textoOuNulo(json['distribuidora']),
      descricao: _textoOuNulo(json['descricao']),
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? ''),
    );
  }

  static String? _textoOuNulo(dynamic valor) {
    final texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }
}
