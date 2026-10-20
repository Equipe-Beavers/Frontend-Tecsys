class RFProfile {
  const RFProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.frequencyMhz,
    required this.transmitPowerDbm,
    required this.receiveSensitivityDbm,
    this.gatewayHeightM,
    this.deviceHeightM,
    this.maximumEquipment,
    this.additionalAttenuationDb,
    required this.considersRelief,
    required this.considersVegetation,
    required this.considersBuildings,
    required this.considersAntennas,
  });

  final int id;
  final int userId;
  final String name;
  final double frequencyMhz;
  final double transmitPowerDbm;
  final double receiveSensitivityDbm;
  final double? gatewayHeightM;
  final double? deviceHeightM;
  final int? maximumEquipment;
  final double? additionalAttenuationDb;
  final bool considersRelief;
  final bool considersVegetation;
  final bool considersBuildings;
  final bool considersAntennas;

  factory RFProfile.fromJson(Map<String, dynamic> json) => RFProfile(
    id: _integer(json['id_perfil_rf'], required: true)!,
    userId: _integer(json['id_usuario'], required: true)!,
    name: _string(json['nome'], required: true)!,
    frequencyMhz: _number(json['frequencia_mhz'], required: true)!,
    transmitPowerDbm: _number(
      json['potencia_transmissao_dbm'],
      required: true,
    )!,
    receiveSensitivityDbm: _number(
      json['sensibilidade_recepcao_dbm'],
      required: true,
    )!,
    gatewayHeightM: _number(json['altura_gateway_m']),
    deviceHeightM: _number(json['altura_dispositivo_m']),
    maximumEquipment: _integer(json['capacidade_max_equipamentos']),
    additionalAttenuationDb: _number(json['atenuacao_adicional_db']),
    considersRelief: _boolean(json['considera_relevo'], fallback: true),
    considersVegetation: _boolean(json['considera_vegetacao'], fallback: true),
    considersBuildings: _boolean(json['considera_edificacoes'], fallback: true),
    considersAntennas: _boolean(json['considera_antenas'], fallback: true),
  );

  static String? _string(Object? value, {bool required = false}) {
    if (value is String) return value;
    if (required) throw const FormatException('Nome de perfil RF inválido.');
    return null;
  }

  static double? _number(Object? value, {bool required = false}) {
    if (value == null && !required) return null;
    final parsed = value is num
        ? value.toDouble()
        : value is String
        ? double.tryParse(value)
        : null;
    if (parsed == null || !parsed.isFinite) {
      throw const FormatException('Valor numérico de perfil RF inválido.');
    }
    return parsed;
  }

  static int? _integer(Object? value, {bool required = false}) {
    final parsed = _number(value, required: required);
    if (parsed == null) return null;
    if (parsed != parsed.truncateToDouble() || (required && parsed < 1)) {
      throw const FormatException(
        'Identificador ou limite de perfil RF inválido.',
      );
    }
    return parsed.toInt();
  }

  static bool _boolean(Object? value, {required bool fallback}) =>
      value is bool ? value : fallback;
}
