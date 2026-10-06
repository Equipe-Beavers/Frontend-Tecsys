import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

class EstudoResumo {
  final int id;
  final String nome;
  final String? descricao;
  final String? uf;
  final String? municipio;
  final String? bairro;
  final String? distribuidora;
  final String tipoDelimitacao;
  final String status;
  final DateTime? criadoEm;
  final List<LatLng> pontosArea;

  const EstudoResumo({
    required this.id,
    required this.nome,
    this.descricao,
    this.uf,
    this.municipio,
    this.bairro,
    this.distribuidora,
    required this.tipoDelimitacao,
    required this.status,
    this.criadoEm,
    this.pontosArea = const [],
  });

  factory EstudoResumo.fromJson(Map<String, dynamic> json) {
    String? texto(String chave) {
      final valor = json[chave]?.toString().trim();
      return valor == null || valor.isEmpty ? null : valor;
    }

    return EstudoResumo(
      id: (json['id_estudo'] as num).toInt(),
      nome: texto('nome') ?? 'Estudo sem nome',
      descricao: texto('descricao'),
      uf: texto('uf'),
      municipio: texto('municipio'),
      bairro: texto('bairro'),
      distribuidora: texto('distribuidora'),
      tipoDelimitacao: texto('tipo_delimitacao') ?? 'desenho',
      status: texto('status') ?? 'AGUARDANDO_SELECAO',
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? ''),
      pontosArea: _lerPontos(json['geom']),
    );
  }

  static List<LatLng> _lerPontos(Object? geom) {
    try {
      if (geom is Map) return _pontosGeoJson(geom);
      if (geom is String && geom.isNotEmpty) return _pontosEwkb(geom);
    } catch (_) {}
    return const [];
  }

  static List<LatLng> _pontosGeoJson(Map geom) {
    final aneis = geom['coordinates'] as List;
    if (aneis.isEmpty) return const [];
    return _removerFechamento(
      (aneis.first as List)
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList(),
    );
  }

  // Lê o primeiro anel de um Polygon em EWKB hexadecimal (formato do PostGIS).
  static List<LatLng> _pontosEwkb(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    final dados = ByteData.sublistView(bytes);
    final endian = bytes[0] == 1 ? Endian.little : Endian.big;
    final tipo = dados.getUint32(1, endian);
    var posicao = 5;
    if (tipo & 0x20000000 != 0) posicao += 4;
    if ((tipo & 0xFF) != 3) return const [];
    final aneis = dados.getUint32(posicao, endian);
    posicao += 4;
    if (aneis == 0) return const [];
    final total = dados.getUint32(posicao, endian);
    posicao += 4;
    final pontos = <LatLng>[];
    for (var i = 0; i < total; i++) {
      final x = dados.getFloat64(posicao, endian);
      final y = dados.getFloat64(posicao + 8, endian);
      posicao += 16;
      pontos.add(LatLng(y, x));
    }
    return _removerFechamento(pontos);
  }

  static List<LatLng> _removerFechamento(List<LatLng> pontos) {
    if (pontos.length > 1 && pontos.first == pontos.last) {
      return pontos.sublist(0, pontos.length - 1);
    }
    return pontos;
  }
}
