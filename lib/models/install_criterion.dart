enum CriterionCollection {
  allowedTypes('tipos_elementos_permitidos', 'Ativos permitidos'),
  blockedTypes('tipos_elementos_proibidos', 'Ativos bloqueados'),
  authorizedLocations('locais_autorizados', 'Locais autorizados'),
  requiredLocations('locais_obrigatorios', 'Locais obrigatórios'),
  forbiddenLocations('locais_proibidos', 'Locais proibidos');

  const CriterionCollection(this.jsonKey, this.label);
  final String jsonKey;
  final String label;
  bool get isLocation => index >= authorizedLocations.index;
}

class InstallCriterion {
  InstallCriterion({
    required this.id,
    required this.userId,
    required this.name,
    this.requiresPower,
    this.maxDistanceMeters,
    this.gatewayLimit,
    this.createdAt,
    this.updatedAt,
    Map<CriterionCollection, Object?> collections = const {},
  }) : collections = Map.unmodifiable(collections);

  final int id;
  final int userId;
  final String name;
  final bool? requiresPower;
  final double? maxDistanceMeters;
  final int? gatewayLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // JSONB has no prescribed structure in the approved DER.
  final Map<CriterionCollection, Object?> collections;

  factory InstallCriterion.fromJson(Map<String, dynamic> json) {
    final name = json['nome'];
    final power = json['requer_alimentacao_eletrica'];
    if (name is! String || (power != null && power is! bool)) {
      throw const FormatException('Resposta de critério inválida.');
    }
    return InstallCriterion(
      id: _integer(json['id_criterio_instalacao'], required: true)!,
      userId: _integer(json['id_usuario'], required: true)!,
      name: name,
      requiresPower: power as bool?,
      maxDistanceMeters: _number(json['distancia_maxima_ativos_m']),
      gatewayLimit: _integer(json['limite_gateways']),
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
    return value is List ? value.whereType<String>().toList() : [];
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

  int selectionCount(CriterionCollection field) {
    final value = collections[field];
    return value is List ? value.length : 0;
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

const criterionAssetTypes = <String, String>{
  'POSTE': 'Postes',
  'SUBESTACAO': 'Subestações',
  'TORRE': 'Torres',
  'EDIFICACAO_PROPRIA': 'Edificações próprias',
  'RESERVATORIO': 'Reservatórios',
};
