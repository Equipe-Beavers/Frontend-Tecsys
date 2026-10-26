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

class NovoEstudoPonto {
  final int idEstudo;
  final double latitude;
  final double longitude;
  final double? relevoM;
  final String rotulo;
  final int indice;

  const NovoEstudoPonto({
    required this.idEstudo,
    required this.latitude,
    required this.longitude,
    required this.relevoM,
    required this.rotulo,
    required this.indice,
  });

  Map<String, dynamic> toJson() => {
    'id_estudo': idEstudo,
    'origem': 'manual',
    'id_ativo_bdgd': null,
    'tipo_ativo': null,
    'rotulo': rotulo,
    'papel': 'ambos',
    'prioridade': null,
    'latitude': latitude,
    'longitude': longitude,
    'atributos': {'tipo_ponto': 'vertice_area', 'indice': indice},
    'relevo_m': relevoM,
  };
}

class NovoEstudo {
  final int idUsuario;
  final int idRfProfile;
  final int idCriterioInstalacao;
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
    this.idUsuario = 1,
    required this.idRfProfile,
    required this.idCriterioInstalacao,
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
    'id_usuario': idUsuario,
    'id_perfil_rf': idRfProfile,
    'id_criterio_instalacao': idCriterioInstalacao,
    'tipo_delimitacao': tipoDelimitacao,
    'uf': uf,
    'municipio': municipio,
    'bairro': bairro,
    'geom': pontosArea.isEmpty ? null : _geometria,
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
