import 'install_criterion.dart';

/// Editable values and payload rules, independent from Flutter widgets.
class InstallCriterionDraft {
  InstallCriterionDraft({this.original})
    : name = original?.name ?? '',
      gatewayLimitText = original?.gatewayLimit?.toString() ?? '',
      requiresPower = original == null ? true : original.requiresPower,
      maintenanceAccess = original == null ? true : original.maintenanceAccess,
      minDistanceMeters = original?.minDistanceMeters ?? 0,
      maxDistanceMeters = original == null ? 1500 : original.maxDistanceMeters,
      minHeight = original == null ? 5 : original.minHeight,
      _selections = {
        for (final field in CriterionCollection.values)
          field: {...?original?.labels(field)},
      };

  final InstallCriterion? original;
  String name;
  String gatewayLimitText;
  bool? requiresPower;
  bool? maintenanceAccess;
  double? minDistanceMeters;
  double? maxDistanceMeters;
  double? minHeight;
  final Map<CriterionCollection, Set<String>> _selections;
  final Set<CriterionCollection> _changedCollections = {};

  Set<String> selection(CriterionCollection field) =>
      Set.unmodifiable(_selections[field]!);
  bool preservesStructuredSelection(CriterionCollection field) =>
      !_changedCollections.contains(field) &&
      (original?.hasStructuredSelection(field) ?? false);

  void setTypes(CriterionCollection field, Iterable<String> types) {
    _selections[field] = types.toSet();
    _changedCollections.add(field);
  }

  Map<String, dynamic> toPayload({required int userId}) => {
    if (original == null) 'id_usuario': userId,
    'nome': name.trim(),
    'requer_alimentacao_eletrica': requiresPower,
    'acesso_manutencao': maintenanceAccess,
    'distancia_minima_ativos_m': minDistanceMeters,
    'distancia_maxima_ativos_m': maxDistanceMeters,
    'altura_minima_local_m': minHeight,
    'limite_gateways': gatewayLimitText.trim().isEmpty
        ? null
        : int.parse(gatewayLimitText.trim()),
    for (final field in CriterionCollection.values)
      if (original == null || _changedCollections.contains(field))
        field.jsonKey: _selections[field]!.toList(),
  };

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
}
