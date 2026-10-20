import 'install_criterion.dart';

/// Editable values and payload rules, independent from Flutter widgets.
class InstallCriterionDraft {
  InstallCriterionDraft({this.original})
    : name = original?.name ?? '',
      gatewayLimitText = original?.gatewayLimit?.toString() ?? '',
      requiresPower = original == null ? true : original.requiresPower,
      minDistanceMeters = original == null ? 10 : original.minDistanceMeters,
      maxDistanceMeters = original == null ? 500 : original.maxDistanceMeters,
      _selections = {
        for (final field in CriterionCollection.values)
          field: {...?original?.labels(field)},
      } {
    relief = _readObject(original?.relief);
    vegetation = _readObject(original?.vegetation);
    buildings = _readObject(original?.buildings);
    antennas = _readObject(original?.antennas);
    final defaultAllowed = original == null
        ? criterionVegetationTypes.keys.take(3).toList()
        : <String>[];
    final defaultBlocked = original == null
        ? criterionVegetationTypes.keys.skip(3).toList()
        : <String>[];
    allowedVegetationTypes = _readStringList(
      vegetation['permitidas'],
      defaultAllowed,
    );
    blockedVegetationTypes = _readStringList(
      vegetation['proibidas'],
      defaultBlocked,
    );
  }

  final InstallCriterion? original;
  String name;
  String gatewayLimitText;
  bool? requiresPower;
  double? minDistanceMeters;
  double? maxDistanceMeters;
  late final Map<String, dynamic> relief;
  late final Map<String, dynamic> vegetation;
  late final Map<String, dynamic> buildings;
  late final Map<String, dynamic> antennas;
  late List<String> allowedVegetationTypes;
  late List<String> blockedVegetationTypes;
  final Map<CriterionCollection, Set<String>> _selections;
  final Set<CriterionCollection> _changedCollections = {};

  static Map<String, dynamic> _readObject(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<String> _readStringList(Object? value, List<String> fallback) =>
      value is List ? value.whereType<String>().toList() : fallback;

  Set<String> selection(CriterionCollection field) =>
      Set.unmodifiable(_selections[field]!);
  bool preservesStructuredSelection(CriterionCollection field) =>
      !_changedCollections.contains(field) &&
      (original?.hasStructuredSelection(field) ?? false);

  void setTypes(CriterionCollection field, Iterable<String> types) {
    _selections[field] = types.toSet();
    _changedCollections.add(field);
  }

  void setVegetationTypes({
    required bool allowed,
    required List<String> types,
  }) {
    if (allowed) {
      allowedVegetationTypes = types;
    } else {
      blockedVegetationTypes = types;
    }
  }

  Map<String, dynamic> toPayload({
    required int userId,
    Map<String, dynamic> reliefValues = const {},
    Map<String, dynamic> buildingValues = const {},
    Map<String, dynamic> antennaValues = const {},
  }) => {
    if (original == null) 'id_usuario': userId,
    'nome': name.trim(),
    'requer_alimentacao_eletrica': requiresPower,
    'distancia_minima_ativos_m': minDistanceMeters,
    'distancia_maxima_ativos_m': maxDistanceMeters,
    'limite_gateways': gatewayLimitText.trim().isEmpty
        ? null
        : int.parse(gatewayLimitText.trim()),
    'relevo': _mergeObject(relief, reliefValues),
    'vegetacoes': {
      ...vegetation,
      'permitidas': allowedVegetationTypes,
      'proibidas': blockedVegetationTypes,
    },
    'edificacoes': _mergeObject(buildings, buildingValues),
    'antenas': _mergeObject(antennas, antennaValues),
    for (final field in CriterionCollection.values)
      if (original == null || _changedCollections.contains(field))
        field.jsonKey: _selections[field]!.toList(),
  };

  /// Validate semantic rules after merging the form with preserved JSON values.
  String? validatePayload(Map<String, dynamic> payload) {
    for (final distance in [minDistanceMeters, maxDistanceMeters]) {
      if (distance != null &&
          (!distance.isFinite || distance < 10 || distance > 500)) {
        return 'Ajuste a distância aos ativos para um intervalo entre 10 e 500 m.';
      }
    }
    if (minDistanceMeters != null &&
        maxDistanceMeters != null &&
        minDistanceMeters! > maxDistanceMeters!) {
      return 'A distância mínima não pode ultrapassar a distância máxima.';
    }
    Set<String> keys(Object? values) => values is List
        ? values.whereType<String>().map(normalizeCriterionAssetType).toSet()
        : <String>{};
    final allowed = payload.containsKey('tipos_elementos_permitidos')
        ? payload['tipos_elementos_permitidos']
        : original?.collections[CriterionCollection.allowedTypes];
    final blocked = payload.containsKey('tipos_elementos_proibidos')
        ? payload['tipos_elementos_proibidos']
        : original?.collections[CriterionCollection.blockedTypes];
    for (final field in CriterionCollection.values) {
      if (!payload.containsKey(field.jsonKey)) continue;
      final value = payload[field.jsonKey];
      if (value != null &&
          (value is! List ||
              value.any(
                (item) =>
                    item is! String ||
                    !criterionAssetTypes.containsKey(
                      normalizeCriterionAssetType(item),
                    ),
              ))) {
        return 'Selecione somente tipos de ativos elétricos disponíveis nas camadas.';
      }
    }
    if (keys(allowed).intersection(keys(blocked)).isNotEmpty) {
      return 'Ativos: uma opção não pode ser permitida e proibida ao mesmo tempo.';
    }
    final vegetation = payload['vegetacoes'];
    if (vegetation is Map &&
        keys(vegetation['permitidas'])
            .intersection(keys(vegetation['proibidas']))
            .isNotEmpty) {
      return 'Vegetação: uma opção não pode ser permitida e proibida ao mesmo tempo.';
    }
    final relief = payload['relevo'];
    if (relief is Map) {
      final minimum = relief['altitude_minima_m'];
      final maximum = relief['altitude_maxima_m'];
      if (minimum is num && maximum is num && minimum > maximum) {
        return 'A altitude mínima não pode ultrapassar a altitude máxima.';
      }
      final slope = relief['declividade_maxima_graus'];
      if (slope is num && (slope < 0 || slope > 90)) {
        return 'A declividade deve estar entre 0 e 90 graus.';
      }
    }
    return null;
  }

  static Map<String, dynamic>? _mergeObject(
    Map<String, dynamic> existing,
    Map<String, dynamic> values,
  ) {
    final merged = {...existing, ...values};
    return merged.values.every((value) => value == null) ? null : merged;
  }

  static String? validateName(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Informe o nome do critério.';
    }
    if (text.length > 150) return 'Use até 150 caracteres.';
    return null;
  }

  static String? validateGatewayLimit(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = int.tryParse(text.trim());
    return value == null || value < 1 || value > 2147483647
        ? 'Informe um inteiro positivo válido.'
        : null;
  }

  static String? validateOptionalNumber(
    String? text, {
    bool allowNegative = false,
  }) {
    if (text == null || text.trim().isEmpty) return null;
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value == null ||
            !value.isFinite ||
            value.abs() > 9007199254740991 ||
            (!allowNegative && value < 0)
        ? 'Informe um número válido.'
        : null;
  }

  static String? validateOptionalInteger(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = int.tryParse(text.trim());
    return value == null || value < 1 || value > 2147483647
        ? 'Informe um inteiro positivo válido.'
        : null;
  }
}
