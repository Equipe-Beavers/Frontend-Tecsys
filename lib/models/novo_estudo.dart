import 'package:latlong2/latlong.dart';

class TipoAtivoSelecionado {
  final String tipoAtivo;
  final String papel;
  final int quantidade;

  const TipoAtivoSelecionado({
    required this.tipoAtivo,
    required this.papel,
    required this.quantidade,
  });

  static const List<TipoAtivoSelecionado> padrao = [
    TipoAtivoSelecionado(
      tipoAtivo: 'religador',
      papel: 'interesse',
      quantidade: 1,
    ),
    TipoAtivoSelecionado(tipoAtivo: 'poste', papel: 'candidato', quantidade: 1),
  ];

  Map<String, dynamic> toJson() => {
    'tipo_ativo': tipoAtivo,
    'papel': papel,
    'quantidade': quantidade,
  };
}

class NovoEstudo {
  final int? idPerfilRf;
  final int idUsuario;
  final String tipoDelimitacao;
  final String? uf;
  final String? municipio;
  final String? bairro;
  final List<LatLng> pontosArea;
  final String nome;
  final String? descricao;
  final String? distribuidora;
  final String versaoBdgd;
  final String nomeBaseExterna;
  final List<TipoAtivoSelecionado> tiposAtivoSelecionados;
  final String status;

  const NovoEstudo({
    this.idPerfilRf,
    this.idUsuario = 1,
    this.tipoDelimitacao = 'desenho',
    this.uf,
    this.municipio,
    this.bairro,
    required this.pontosArea,
    required this.nome,
    this.descricao,
    this.distribuidora,
    this.versaoBdgd = '2026-01',
    this.nomeBaseExterna = 'bdgd_edp_2026.csv',
    this.tiposAtivoSelecionados = TipoAtivoSelecionado.padrao,
    this.status = 'AGUARDANDO_SELECAO',
  });

  Map<String, dynamic> get _geometria {
    final coordenadas = pontosArea
        .map((ponto) => [ponto.longitude, ponto.latitude])
        .toList();
    if (coordenadas.isNotEmpty && pontosArea.first != pontosArea.last) {
      coordenadas.add(coordenadas.first);
    }
    return {
      'type': 'Polygon',
      'coordinates': [coordenadas],
    };
  }

  Map<String, dynamic> toJson() => {
    if (idPerfilRf != null) 'id_perfil_rf': idPerfilRf,
    'id_usuario': idUsuario,
    'tipo_delimitacao': tipoDelimitacao,
    'uf': uf,
    'municipio': municipio,
    'bairro': bairro,
    'geom': _geometria,
    'nome': nome,
    'descricao': descricao,
    'distribuidora': distribuidora,
    'versao_bdgd': versaoBdgd,
    'nome_base_externa': nomeBaseExterna,
    'tipos_ativo_selecionados': tiposAtivoSelecionados
        .map((tipo) => tipo.toJson())
        .toList(),
    'status': status,
  };
}
