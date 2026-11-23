import 'layer_filter.dart';
import 'ativo_bdgd.dart';

enum CriterionCollection {
  allowedTypes('tipos_elementos_permitidos', 'Ativos permitidos'),
  blockedTypes('tipos_elementos_proibidos', 'Ativos bloqueados');

  const CriterionCollection(this.jsonKey, this.label);
  final String jsonKey;
  final String label;
}

class InstallCriterion {
  InstallCriterion({
    required this.id,
    required this.userId,
    required this.name,
    this.minDistanceMeters,
    this.maxDistanceMeters,
    this.gatewayLimit,
    this.relief,
    this.createdAt,
    this.updatedAt,
    Map<CriterionCollection, Object?> collections = const {},
  }) : collections = Map.unmodifiable(collections);

  final int id;
  final int userId;
  final String name;
  final double? minDistanceMeters;
  final double? maxDistanceMeters;
  final int? gatewayLimit;
  final Object? relief;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // JSONB has no prescribed structure in the approved DER.
  final Map<CriterionCollection, Object?> collections;

  factory InstallCriterion.fromJson(Map<String, dynamic> json) {
    final name = json['nome'];
    if (name is! String) {
      throw const FormatException('Resposta de critério inválida.');
    }
    return InstallCriterion(
      id: _integer(json['id_criterio_instalacao'], required: true)!,
      userId: _integer(json['id_usuario'], required: true)!,
      name: name,
      minDistanceMeters: _number(json['distancia_minima_ativos_m']),
      maxDistanceMeters: _number(json['distancia_maxima_ativos_m']),
      gatewayLimit: _integer(json['limite_gateways']),
      relief: json['relevo'],
      createdAt: _date(json['criado_em']),
      updatedAt: _date(json['atualizado_em']),
      collections: {
        for (final field in CriterionCollection.values)
          field: json[field.jsonKey],
      },
    );
  }

  List<String> labels(CriterionCollection field) {
    final value = collections[field];
    return value is List
        ? value
              .whereType<String>()
              .map(normalizeCriterionAssetType)
              .toSet()
              .toList()
        : [];
  }

  bool hasStructuredSelection(CriterionCollection field) {
    final value = collections[field];
    return value != null &&
        !(value is List && value.every((item) => item is String));
  }

  String? get distanceMetersLabel {
    final value = maxDistanceMeters;
    if (value == null) return null;
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString().replaceAll('.', ',');
  }

  static double? _number(Object? value) {
    if (value == null) return null;
    final number = value is num
        ? value.toDouble()
        : value is String
        ? double.tryParse(value)
        : null;
    if (number == null || !number.isFinite) {
      throw const FormatException('Valor numérico de critério inválido.');
    }
    return number;
  }

  static int? _integer(Object? value, {bool required = false}) {
    final number = _number(value);
    if (number == null && !required) return null;
    if (number == null ||
        number < 1 ||
        number > 9007199254740991 ||
        number != number.truncateToDouble()) {
      throw const FormatException(
        'Identificador ou limite de critério inválido.',
      );
    }
    return number.toInt();
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    final date = value is String ? DateTime.tryParse(value) : null;
    if (date == null) throw const FormatException('Data de critério inválida.');
    return date;
  }
}

final criterionAssetTypes = <String, String>{
  for (final group in CatalogoCamadas.obterGrupos())
    for (final item in group.itens) item.tipo.criterionKey: item.titulo,
};

extension CriterionAssetKey on TipoAtivo {
  String get criterionKey => name
      .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match[0]}')
      .toUpperCase();
}

/// Canonical keys keep historical BDGD singulars and display labels equivalent.
String normalizeCriterionAssetType(String value) {
  var key = value.trim().toUpperCase();
  const accents = {
    'Á': 'A',
    'À': 'A',
    'Â': 'A',
    'Ã': 'A',
    'É': 'E',
    'Ê': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ú': 'U',
    'Ç': 'C',
  };
  for (final entry in accents.entries) {
    key = key.replaceAll(entry.key, entry.value);
  }
  key = key.replaceAll(RegExp(r'[\s-]+'), '_');
  const aliases = {'POSTES': 'POSTE', 'SUBESTACOES': 'SUBESTACAO'};
  return aliases[key] ?? key;
}
