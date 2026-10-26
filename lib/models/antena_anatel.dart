class AntenaAnatel {
  const AntenaAnatel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.totalRegistros,
    required this.tecnologias,
    this.nomeEntidade,
    this.municipio,
    this.uf,
    this.tipoEstacao,
    this.alturaAntenaMediaM,
  });

  final String id;
  final double latitude;
  final double longitude;
  final int totalRegistros;
  final List<String> tecnologias;
  final String? nomeEntidade;
  final String? municipio;
  final String? uf;
  final String? tipoEstacao;
  final double? alturaAntenaMediaM;

  factory AntenaAnatel.fromJson(Map<String, dynamic> json) {
    final rawTecnologias = json['tecnologias'];
    final tecnologias = rawTecnologias is List
        ? rawTecnologias.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList()
        : <String>[];

    return AntenaAnatel(
      id: json['id']?.toString() ?? '',
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      totalRegistros: (json['totalRegistros'] as num?)?.toInt() ?? 0,
      tecnologias: tecnologias,
      nomeEntidade: _asNullableString(json['nomeEntidade']),
      municipio: _asNullableString(json['municipio']),
      uf: _asNullableString(json['uf']),
      tipoEstacao: _asNullableString(json['tipoEstacao']),
      alturaAntenaMediaM: _asNullableDouble(json['alturaAntenaMediaM']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _asNullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
