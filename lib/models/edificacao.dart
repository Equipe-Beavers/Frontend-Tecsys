import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Edificação retornada por `GET /list-buildings` (Overture Maps).
class Edificacao {
  const Edificacao({
    required this.id,
    required this.alturaM,
    required this.origemAltura,
    required this.pavimentos,
    required this.codigoMaterial,
    required this.nomeMaterial,
    required this.origemMaterial,
    required this.perdaMaterialDb,
    required this.areaM2,
    required this.latitude,
    required this.longitude,
    required this.poligonos,
  });

  final String id;
  final double alturaM;
  final String origemAltura;
  final int? pavimentos;
  final String codigoMaterial;
  final String nomeMaterial;
  final String origemMaterial;
  final double perdaMaterialDb;
  final double? areaM2;
  final double latitude;
  final double longitude;

  /// Cada polígono é uma lista de anéis: o primeiro é o contorno externo e os
  /// demais são buracos.
  final List<List<List<LatLng>>> poligonos;

  String get alturaFormatada =>
      '${alturaM.toStringAsFixed(alturaM % 1 == 0 ? 0 : 1)} m';

  Color get cor {
    switch (codigoMaterial) {
      case 'CONCRETO':
        return const Color(0xFF90A4AE);
      case 'ALVENARIA':
        return const Color(0xFFE57373);
      case 'METAL':
        return const Color(0xFF64B5F6);
      case 'VIDRO':
        return const Color(0xFF4DD0E1);
      case 'MADEIRA':
        return const Color(0xFFA1887F);
      default:
        return const Color(0xFFBDBDBD);
    }
  }

  Map<String, dynamic> toPayloadJson() => {
    'id': id,
    'altura_m': alturaM,
    'codigo_material': codigoMaterial,
    'geometria': {
      'type': 'MultiPolygon',
      'coordinates': [
        for (final poligono in poligonos)
          [
            for (final anel in poligono)
              [
                for (final ponto in anel) [ponto.longitude, ponto.latitude],
              ],
          ],
      ],
    },
  };

  factory Edificacao.fromJson(Map<String, dynamic> json) {
    return Edificacao(
      id: json['id']?.toString() ?? '',
      alturaM: (json['altura_m'] as num?)?.toDouble() ?? 0,
      origemAltura: json['origem_altura']?.toString() ?? '',
      pavimentos: (json['pavimentos'] as num?)?.toInt(),
      codigoMaterial: json['codigo_material']?.toString() ?? '',
      nomeMaterial: json['nome_material']?.toString() ?? 'Não informado',
      origemMaterial: json['origem_material']?.toString() ?? '',
      perdaMaterialDb: (json['perda_material_db'] as num?)?.toDouble() ?? 0,
      areaM2: (json['area_m2'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      poligonos: _lerMultiPolygon(json['geometria']),
    );
  }

  static List<List<List<LatLng>>> _lerMultiPolygon(dynamic geometria) {
    if (geometria is! Map) return const [];

    final coordenadas = geometria['coordinates'];
    if (coordenadas is! List) return const [];

    // Aceita tanto Polygon quanto MultiPolygon.
    final poligonos =
        geometria['type'] == 'Polygon' ? [coordenadas] : coordenadas;

    return [
      for (final poligono in poligonos)
        if (poligono is List)
          [
            for (final anel in poligono)
              if (anel is List)
                [
                  for (final ponto in anel)
                    if (ponto is List && ponto.length >= 2)
                      LatLng(
                        (ponto[1] as num).toDouble(),
                        (ponto[0] as num).toDouble(),
                      ),
                ],
          ],
    ];
  }
}
