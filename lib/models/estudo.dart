import 'package:latlong2/latlong.dart';

class EstudoResumo {
  const EstudoResumo({
    required this.idEstudo,
    required this.nome,
    required this.status,
    this.descricao,
    this.distribuidora,
    this.municipio,
    this.uf,
    this.criadoEm,
    this.totalPontosInteresse = 0,
    this.totalPontosCandidato = 0,
    this.pontosArea = const [],
  });

  final int idEstudo;
  final String nome;
  final String status;
  final String? descricao;
  final String? distribuidora;
  final String? municipio;
  final String? uf;
  final String? criadoEm;
  final int totalPontosInteresse;
  final int totalPontosCandidato;
  final List<LatLng> pontosArea;

  bool get possuiPontos => totalPontosInteresse > 0 && totalPontosCandidato > 0;

  String get local {
    final partes = [municipio, uf].where((parte) => parte?.isNotEmpty == true);
    if (partes.isNotEmpty) return partes.join(' - ');
    if (distribuidora?.isNotEmpty == true) return distribuidora!;
    return 'Local não informado';
  }

  static List<LatLng> _pontosAreaFromGeom(dynamic geom) {
    if (geom is! Map) return const [];

    final coordenadas = geom['coordinates'];
    if (coordenadas is! List || coordenadas.isEmpty) return const [];

    final anel = coordenadas.first;
    if (anel is! List) return const [];

    final pontos = <LatLng>[];
    for (final par in anel) {
      if (par is! List || par.length < 2) continue;
      final longitude = (par[0] as num?)?.toDouble();
      final latitude = (par[1] as num?)?.toDouble();
      if (longitude == null || latitude == null) continue;
      pontos.add(LatLng(latitude, longitude));
    }

    if (pontos.length >= 2 && pontos.first == pontos.last) {
      pontos.removeLast();
    }

    return pontos;
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
      criadoEm: json['criado_em']?.toString(),
      pontosArea: _pontosAreaFromGeom(json['geom']),
    );
  }
}
