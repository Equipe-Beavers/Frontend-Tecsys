class NovoEstudoPonto {
  final int idEstudo;
  final String origem;
  final String? idAtivoBdgd;
  final String? tipoAtivo;
  final String? rotulo;
  final String papel;
  final String? prioridade;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? atributos;

  const NovoEstudoPonto({
    required this.idEstudo,
    required this.latitude,
    required this.longitude,
    this.origem = 'bdgd',
    this.idAtivoBdgd,
    this.tipoAtivo,
    this.rotulo,
    this.papel = 'interesse',
    this.prioridade,
    this.atributos,
  });

  Map<String, dynamic> toJson() => {
    'id_estudo': idEstudo,
    'origem': origem,
    'id_ativo_bdgd': idAtivoBdgd,
    'tipo_ativo': tipoAtivo,
    'rotulo': rotulo,
    'papel': papel,
    'prioridade': prioridade,
    'latitude': latitude,
    'longitude': longitude,
    'atributos': atributos,
  };
}
