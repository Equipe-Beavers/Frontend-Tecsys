import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/utils/geojson_utils.dart';

double? _paraDouble(Object? valor) => valor is num ? valor.toDouble() : null;

class Edificacao {
  /// Id da edificação na Overture Maps (GERS).
  final String id;
  final double alturaM;
  final String origemAltura;
  final int? pavimentos;
  final double? larguraM;
  final double? profundidadeM;
  final double? areaM2;
  final String codigoMaterial;
  final String nomeMaterial;
  final String origemMaterial;
  final double perdaMaterialDb;
  final String? fonteOriginal;
  final List<List<LatLng>> poligonos;

  const Edificacao({
    required this.id,
    required this.alturaM,
    required this.origemAltura,
    required this.pavimentos,
    required this.larguraM,
    required this.profundidadeM,
    required this.areaM2,
    required this.codigoMaterial,
    required this.nomeMaterial,
    required this.origemMaterial,
    required this.perdaMaterialDb,
    required this.fonteOriginal,
    required this.poligonos,
  });

  /// Cor da edificação no mapa, de acordo com o material.
  Color get cor {
    switch (codigoMaterial) {
      case 'CIMENTO':
        return const Color(0xFFB0BEC5);
      case 'ALVENARIA':
        return const Color(0xFFFFB74D);
      case 'METAL':
        return const Color(0xFF64B5F6);
      case 'VIDRO':
        return const Color(0xFF4DD0E1);
      case 'MADEIRA':
        return const Color(0xFFA1887F);
      default:
        return const Color(0xFFB0BEC5);
    }
  }

  bool contem(LatLng ponto) =>
      poligonos.any((poligono) => pontoDentroDoPoligono(ponto, poligono));

  factory Edificacao.fromJson(Map<String, dynamic> json) {
    return Edificacao(
      id: json['id']?.toString() ?? '',
      alturaM: _paraDouble(json['altura_m']) ?? 0,
      origemAltura: json['origem_altura']?.toString() ?? '',
      pavimentos: (json['pavimentos'] as num?)?.toInt(),
      larguraM: _paraDouble(json['largura_m']),
      profundidadeM: _paraDouble(json['profundidade_m']),
      areaM2: _paraDouble(json['area_m2']),
      codigoMaterial: json['codigo_material']?.toString() ?? '',
      nomeMaterial: json['nome_material']?.toString() ?? '',
      origemMaterial: json['origem_material']?.toString() ?? '',
      perdaMaterialDb: _paraDouble(json['perda_material_db']) ?? 0,
      fonteOriginal: json['fonte_original']?.toString(),
      poligonos: aneisExternosGeoJson(json['geometria']),
    );
  }
}

/// Mancha de cobertura de um gateway calculada pelo backend.
class ManchaCobertura {
  final List<LatLng> pontos;
  final int alcanceMinimoM;
  final int alcanceMedioM;
  final int alcanceMaximoM;
  final String modelo;
  final bool edificacoesConsideradas;
  final int quantidadeEdificacoes;

  /// Motivo de as edificações não entrarem no cálculo (fonte indisponível, por exemplo).
  final String? erroEdificacoes;

  const ManchaCobertura({
    required this.pontos,
    required this.alcanceMinimoM,
    required this.alcanceMedioM,
    required this.alcanceMaximoM,
    required this.modelo,
    required this.edificacoesConsideradas,
    this.quantidadeEdificacoes = 0,
    this.erroEdificacoes,
  });

  factory ManchaCobertura.fromJson(Map<String, dynamic> json) {
    final aneis = aneisExternosGeoJson(json['geometry']);
    return ManchaCobertura(
      pontos: aneis.isEmpty ? <LatLng>[] : aneis.first,
      alcanceMinimoM: (json['min_range_m'] as num?)?.toInt() ?? 0,
      alcanceMedioM: (json['mean_range_m'] as num?)?.toInt() ?? 0,
      alcanceMaximoM: (json['max_range_m'] as num?)?.toInt() ?? 0,
      modelo: json['model']?.toString() ?? '',
      edificacoesConsideradas: json['buildings_considered'] == true,
      quantidadeEdificacoes: (json['buildings_count'] as num?)?.toInt() ?? 0,
      erroEdificacoes: json['buildings_error']?.toString(),
    );
  }
}

/// Mancha salva de um gateway de um cenário.
class ManchaGatewayCenario {
  final int idEstudoPonto;
  final String? rotulo;
  final LatLng posicao;
  final int? alcanceMedioM;
  final List<LatLng> mancha;

  const ManchaGatewayCenario({
    required this.idEstudoPonto,
    required this.rotulo,
    required this.posicao,
    required this.alcanceMedioM,
    required this.mancha,
  });

  factory ManchaGatewayCenario.fromJson(Map<String, dynamic> json) {
    final aneis = aneisExternosGeoJson(json['mancha_cobertura']);
    return ManchaGatewayCenario(
      idEstudoPonto: (json['id_estudo_ponto'] as num).toInt(),
      rotulo: json['rotulo']?.toString(),
      posicao: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      alcanceMedioM: (json['alcance_medio_m'] as num?)?.toInt(),
      mancha: aneis.isEmpty ? <LatLng>[] : aneis.first,
    );
  }
}

/// Manchas salvas de um cenário (GET /get-scenario-coverage/:id).
class ManchaCenario {
  final List<List<LatLng>> manchaConsolidada;
  final List<ManchaGatewayCenario> gateways;

  const ManchaCenario({
    required this.manchaConsolidada,
    required this.gateways,
  });

  bool get vazia => gateways.every((g) => g.mancha.length < 3);

  factory ManchaCenario.fromJson(Map<String, dynamic> json) {
    return ManchaCenario(
      manchaConsolidada: aneisExternosGeoJson(json['mancha_consolidada']),
      gateways: (json['gateways'] as List? ?? [])
          .map((e) => ManchaGatewayCenario.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
