import 'package:flutter/material.dart';

import '../models/install_criterion.dart';
import '../models/install_criterion_draft.dart';
import '../widgets/criterion_type_dialog.dart';
import '../widgets/criterion_asset_rules.dart';
import '../services/install_criterion_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_panel.dart';
import '../widgets/switch_field.dart';
import '../widgets/form_field_wrapper.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/editable_chip_field.dart';
import '../widgets/slider_field.dart';

class InstallCriterionForm extends StatefulWidget {
  const InstallCriterionForm({
    super.key,
    this.criterion,
    required this.userId,
    required this.onSave,
    required this.onClose,
  });
  final InstallCriterion? criterion;
  final int userId;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final VoidCallback onClose;
  @override
  State<InstallCriterionForm> createState() => _InstallCriterionFormState();
}

class _InstallCriterionFormState extends State<InstallCriterionForm> {
  final _formKey = GlobalKey<FormState>();
  late final InstallCriterionDraft _draft;
  final _expandedSections = <String>{};
  final _errorKey = GlobalKey();
  final _fieldKeys = <String, GlobalKey<FormFieldState<String>>>{};
  late final TextEditingController _distanceMinimum;
  late final TextEditingController _distanceMaximum;
  late final TextEditingController _name;
  late final TextEditingController _gatewayLimit;
  late final TextEditingController _minimumAltitude;
  late final TextEditingController _maximumAltitude;
  late final TextEditingController _maximumSlope;
  late final TextEditingController _buildingAnalysisRadius;
  late final TextEditingController _buildingMaximumQuantity;
  late final TextEditingController _buildingMaximumHeight;
  late final TextEditingController _buildingMinimumDistance;
  late final TextEditingController _antennaAnalysisRadius;
  late final TextEditingController _antennaMaximumQuantity;
  late final TextEditingController _antennaMaximumDistance;
  late Map<CriterionCollection, List<String>> _assetChipItems;
  late List<String> _allowedVegetationItems;
  late List<String> _blockedVegetationItems;
  late bool _considerFrequencyConflict;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = InstallCriterionDraft(original: widget.criterion);
    _distanceMinimum = TextEditingController(
      text: _draft.minDistanceMeters == null
          ? ''
          : _formatMeters(_draft.minDistanceMeters!),
    );
    _distanceMaximum = TextEditingController(
      text: _draft.maxDistanceMeters == null
          ? ''
          : _formatMeters(_draft.maxDistanceMeters!),
    );
    _name = TextEditingController(text: _draft.name);
    _gatewayLimit = TextEditingController(text: _draft.gatewayLimitText);
    _minimumAltitude = TextEditingController(
      text: _sectionText(_draft.relief, 'altitude_minima_m'),
    );
    _maximumAltitude = TextEditingController(
      text: _sectionText(_draft.relief, 'altitude_maxima_m'),
    );
    _maximumSlope = TextEditingController(
      text: _sectionText(_draft.relief, 'declividade_maxima_graus'),
    );
    _buildingAnalysisRadius = TextEditingController(
      text: _sectionText(_draft.buildings, 'raio_analise_m'),
    );
    _buildingMaximumQuantity = TextEditingController(
      text: _sectionText(_draft.buildings, 'quantidade_maxima'),
    );
    _buildingMaximumHeight = TextEditingController(
      text: _sectionText(_draft.buildings, 'altura_maxima_m'),
    );
    _buildingMinimumDistance = TextEditingController(
      text: _sectionText(_draft.buildings, 'distancia_minima_m'),
    );
    _antennaAnalysisRadius = TextEditingController(
      text: _sectionText(_draft.antennas, 'raio_analise_m'),
    );
    _antennaMaximumQuantity = TextEditingController(
      text: _sectionText(_draft.antennas, 'quantidade_maxima'),
    );
    _antennaMaximumDistance = TextEditingController(
      text: _sectionText(_draft.antennas, 'distancia_maxima_m'),
    );
    _considerFrequencyConflict =
        _draft.antennas['considerar_conflito_frequencia'] as bool? ?? true;
    _assetChipItems = {
      for (final field in CriterionCollection.values)
        field: _draft.selection(field).toList(),
    };
    _allowedVegetationItems = _draft.allowedVegetationTypes;
    _blockedVegetationItems = _draft.blockedVegetationTypes;
    if (widget.criterion == null) {
      for (final entry in _assetChipItems.entries) {
        _draft.setTypes(entry.key, entry.value);
      }
    }
  }

  String _sectionText(Map<String, dynamic> values, String key) =>
      values[key]?.toString() ?? '';

  double? _optionalNumber(String text) => text.trim().isEmpty
      ? null
      : double.parse(text.trim().replaceAll(',', '.'));

  int? _optionalInteger(String text) =>
      text.trim().isEmpty ? null : int.parse(text.trim());

  @override
  void dispose() {
    for (final controller in [
      _distanceMinimum,
      _distanceMaximum,
      _name,
      _gatewayLimit,
      _minimumAltitude,
      _maximumAltitude,
      _maximumSlope,
      _buildingAnalysisRadius,
      _buildingMaximumQuantity,
      _buildingMaximumHeight,
      _buildingMinimumDistance,
      _antennaAnalysisRadius,
      _antennaMaximumQuantity,
      _antennaMaximumDistance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Descartar alterações?'),
          content: const Text(
            'As alterações feitas neste critério ainda não foram salvas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) widget.onClose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      _revealError(invalid.first.context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    _draft.name = _name.text;
    _draft.gatewayLimitText = _gatewayLimit.text;
    final values = _draft.toPayload(
      userId: widget.userId,
      reliefValues: {
        'altitude_minima_m': _optionalNumber(_minimumAltitude.text),
        'altitude_maxima_m': _optionalNumber(_maximumAltitude.text),
        'declividade_maxima_graus': _optionalNumber(_maximumSlope.text),
      },
      buildingValues: {
        'raio_analise_m': _optionalNumber(_buildingAnalysisRadius.text),
        'quantidade_maxima': _optionalInteger(_buildingMaximumQuantity.text),
        'altura_maxima_m': _optionalNumber(_buildingMaximumHeight.text),
        'distancia_minima_m': _optionalNumber(_buildingMinimumDistance.text),
      },
      antennaValues: {
        'raio_analise_m': _optionalNumber(_antennaAnalysisRadius.text),
        'quantidade_maxima': _optionalInteger(_antennaMaximumQuantity.text),
        'distancia_maxima_m': _optionalNumber(_antennaMaximumDistance.text),
        'considerar_conflito_frequencia': _considerFrequencyConflict,
      },
    );
    final validationError = _draft.validatePayload(values);
    if (validationError != null) {
      setState(() {
        _saving = false;
        _error = validationError;
      });
      _revealError();
      return;
    }
    try {
      await widget.onSave(values);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CriterionApiException ? error.message : 'Não foi possível salvar. Verifique a conexão e tente novamente.',
        );
        _revealError();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    bool insideAppPanel = false,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Color(0xFFABC2BC)),
    hintStyle: const TextStyle(color: AppColors.textMuted),
    floatingLabelStyle: const TextStyle(color: Color(0xFFABC2BC)),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: insideAppPanel
        ? AppColors.surfaceBackground
        : AppColors.surfaceCardLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.borderSubtle),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.borderSubtle),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.secondaryTeal),
    ),
  );

  Future<List<String>?> _addChipItems(
    List<String> availableItems,
    Set<String> existingItems, {
    required List<String> permittedItems,
    required List<String> forbiddenItems,
    required Map<String, String> itemLabels,
    required String title,
  }) => showDialog<List<String>>(
    context: context,
    builder: (_) => CriterionTypeDialog(
      availableItems: availableItems,
      existingItems: existingItems,
      itemLabels: itemLabels,
      title: title,
      existingItemLabels: {
        for (final item in permittedItems) item: 'Permitido',
        for (final item in forbiddenItems) item: 'Bloqueado',
      },
      existingItemColors: {
        for (final item in permittedItems) item: AppColors.secondaryTeal,
        for (final item in forbiddenItems) item: Colors.orange,
      },
    ),
  );

  void _updateVegetationItems({
    required bool allowed,
    required List<String> items,
  }) {
    setState(() {
      if (allowed) {
        _allowedVegetationItems = items;
        _blockedVegetationItems = _blockedVegetationItems
            .where((item) => !items.contains(item))
            .toList();
      } else {
        _blockedVegetationItems = items;
        _allowedVegetationItems = _allowedVegetationItems
            .where((item) => !items.contains(item))
            .toList();
      }
      _draft
        ..setVegetationTypes(allowed: true, types: _allowedVegetationItems)
        ..setVegetationTypes(allowed: false, types: _blockedVegetationItems);
      _dirty = true;
    });
  }

  Widget _identity() => FormFieldWrapper(
    title: 'Nome do critério',
    titleColor: const Color(0xFFABC2BC),
    child: TextFormField(
      key: _fieldKeys.putIfAbsent(
        '_name',
        () => GlobalKey<FormFieldState<String>>(),
      ),
      controller: _name,
      enabled: !_saving,
      maxLength: 150,
      decoration: _decoration(
        'Nome',
        hint: 'Ex.: Padrão urbano — Postes e SEs',
      ),
      onChanged: (_) => setState(() => _dirty = true),
      validator: InstallCriterionDraft.validateName,
    ),
  );

  Widget _assets() => FormFieldWrapper(
    title: 'Regras de Ativos Permitidos e Bloqueados',
    titleColor: const Color(0xFFABC2BC),
    child: CriterionAssetRules(
      allowed: _assetChipItems[CriterionCollection.allowedTypes]!,
      blocked: _assetChipItems[CriterionCollection.blockedTypes]!,
      hasLegacyStructure: CriterionCollection.values.any(
        _draft.preservesStructuredSelection,
      ),
      enabled: !_saving,
      onChanged: (allowed, blocked) => setState(() {
        _assetChipItems = {
          CriterionCollection.allowedTypes: allowed,
          CriterionCollection.blockedTypes: blocked,
        };
        for (final entry in _assetChipItems.entries) {
          _draft.setTypes(entry.key, entry.value);
        }
        _dirty = true;
      }),
    ),
  );

  String _formatMeters(double meters) =>
      (meters == meters.roundToDouble()
              ? meters.toStringAsFixed(0)
              : meters.toStringAsFixed(2))
          .replaceAll('.', ',');

  String get _distanceLabel {
    final minimum = _draft.minDistanceMeters;
    final maximum = _draft.maxDistanceMeters;
    if (minimum == null && maximum == null) return 'Não definida';
    if (minimum == null) return 'Até ${_formatMeters(maximum!)} m';
    if (maximum == null) return 'A partir de ${_formatMeters(minimum)} m';
    return '${_formatMeters(minimum)}–${_formatMeters(maximum)} m';
  }

  Widget _requirements() => Column(
    children: [
      FormFieldWrapper(
        title: 'Requisitos do local',
        titleColor: const Color(0xFFABC2BC),
        child: Column(
          children: [
            SwitchField(
              label: 'Necessita alimentação elétrica',
              value: _draft.requiresPower ?? false,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _draft.requiresPower = value;
                      _dirty = true;
                    }),
            ),
            const SizedBox(height: 8),
            SliderField(
              label: 'Distância aos ativos',
              valueLabel: _distanceLabel,
              minValue: 10,
              maxValue: 500,
              values: _distanceSliderValues,
              divisions: 49,
              enableMin: true,
              enableMax: true,
              enabled: !_saving,
              rangeLabel: '10–500 m',
              valueFormatter: (value) => '${_formatMeters(value)} m',
              onChanged: (values) => setState(() {
                _draft.minDistanceMeters = double.parse(
                  values.start.toStringAsFixed(2),
                );
                _draft.maxDistanceMeters = double.parse(
                  values.end.toStringAsFixed(2),
                );
                _distanceMinimum.text = _formatMeters(
                  _draft.minDistanceMeters!,
                );
                _distanceMaximum.text = _formatMeters(
                  _draft.maxDistanceMeters!,
                );
                _dirty = true;
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _distanceInput(true)),
                const SizedBox(width: 12),
                Expanded(child: _distanceInput(false)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajuste o intervalo no controle ou digite os valores em metros.',
              style: TextStyle(color: Color(0xFFABC2BC), fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _scenarioLimits() => FormFieldWrapper(
    title: 'Limites do cenário',
    titleColor: const Color(0xFFABC2BC),
    child: TextFormField(
      key: _fieldKeys.putIfAbsent(
        '_gatewayLimit',
        () => GlobalKey<FormFieldState<String>>(),
      ),
      controller: _gatewayLimit,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      decoration: _decoration(
        'Máximo de gateways',
        hint: 'Sem limite definido',
      ),
      validator: InstallCriterionDraft.validateGatewayLimit,
      onChanged: (_) => setState(() => _dirty = true),
    ),
  );

  Widget _relief() => FormFieldWrapper(
    title: 'Relevo',
    titleColor: const Color(0xFFABC2BC),
    child: AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Altitude'.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: _fieldKeys.putIfAbsent(
                    '_minimumAltitude',
                    () => GlobalKey<FormFieldState<String>>(),
                  ),
                  controller: _minimumAltitude,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(
                    'Mínima',
                    insideAppPanel: true,
                  ).copyWith(suffixText: 'm'),
                  validator: (value) =>
                      InstallCriterionDraft.validateOptionalNumber(
                        value,
                        allowNegative: true,
                      ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  key: _fieldKeys.putIfAbsent(
                    '_maximumAltitude',
                    () => GlobalKey<FormFieldState<String>>(),
                  ),
                  controller: _maximumAltitude,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(
                    'Máxima',
                    insideAppPanel: true,
                  ).copyWith(suffixText: 'm'),
                  validator: (value) =>
                      InstallCriterionDraft.validateOptionalNumber(
                        value,
                        allowNegative: true,
                      ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FormFieldWrapper(
            title: 'Declividade em graus',
            titleColor: const Color(0xFFABC2BC),
            child: TextFormField(
              key: _fieldKeys.putIfAbsent(
                '_maximumSlope',
                () => GlobalKey<FormFieldState<String>>(),
              ),
              controller: _maximumSlope,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _decoration(
                'Máxima',
                insideAppPanel: true,
              ).copyWith(suffixText: '°'),
              validator: InstallCriterionDraft.validateOptionalNumber,
              onChanged: (_) => setState(() => _dirty = true),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _vegetation() => FormFieldWrapper(
    title: 'Vegetação',
    titleColor: const Color(0xFFABC2BC),
    child: AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Permitidas',
            style: TextStyle(
              color: AppColors.secondaryTeal,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          EditableChipField(
            defaultItems: _allowedVegetationItems,
            availableItems: criterionVegetationTypes.keys.toList(),
            excludedItems: _blockedVegetationItems.toSet(),
            itemLabels: criterionVegetationTypes,
            colorVariant: ChipColorVariant.primary,
            enabled: !_saving,
            onAdd: (availableItems, existingItems) => _addChipItems(
              availableItems,
              existingItems,
              permittedItems: _allowedVegetationItems,
              forbiddenItems: _blockedVegetationItems,
              itemLabels: criterionVegetationTypes,
              title: 'Adicionar tipo de vegetação permitida',
            ),
            onItemsChanged: (items) =>
                _updateVegetationItems(allowed: true, items: items),
          ),
          const Divider(height: 24, color: AppColors.border),
          const Text(
            'Proibidas',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          EditableChipField(
            defaultItems: _blockedVegetationItems,
            availableItems: criterionVegetationTypes.keys.toList(),
            excludedItems: _allowedVegetationItems.toSet(),
            itemLabels: criterionVegetationTypes,
            colorVariant: ChipColorVariant.secondary,
            enabled: !_saving,
            onAdd: (availableItems, existingItems) => _addChipItems(
              availableItems,
              existingItems,
              permittedItems: _allowedVegetationItems,
              forbiddenItems: _blockedVegetationItems,
              itemLabels: criterionVegetationTypes,
              title: 'Adicionar tipo de vegetação proibida',
            ),
            onItemsChanged: (items) =>
                _updateVegetationItems(allowed: false, items: items),
          ),
        ],
      ),
    ),
  );

  Widget _buildings() => FormFieldWrapper(
    title: 'Edificações',
    titleColor: const Color(0xFFABC2BC),
    child: AppPanel(
      child: Column(
        children: [
          TextFormField(
            key: _fieldKeys.putIfAbsent(
              '_buildingAnalysisRadius',
              () => GlobalKey<FormFieldState<String>>(),
            ),
            controller: _buildingAnalysisRadius,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(
              'Raio de análise',
              insideAppPanel: true,
            ).copyWith(suffixText: 'm'),
            validator: InstallCriterionDraft.validateOptionalNumber,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _fieldKeys.putIfAbsent(
              '_buildingMaximumQuantity',
              () => GlobalKey<FormFieldState<String>>(),
            ),
            controller: _buildingMaximumQuantity,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: _decoration('Quantidade máxima', insideAppPanel: true),
            validator: InstallCriterionDraft.validateOptionalInteger,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _fieldKeys.putIfAbsent(
              '_buildingMaximumHeight',
              () => GlobalKey<FormFieldState<String>>(),
            ),
            controller: _buildingMaximumHeight,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(
              'Altura máxima',
              insideAppPanel: true,
            ).copyWith(suffixText: 'm'),
            validator: InstallCriterionDraft.validateOptionalNumber,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _fieldKeys.putIfAbsent(
              '_buildingMinimumDistance',
              () => GlobalKey<FormFieldState<String>>(),
            ),
            controller: _buildingMinimumDistance,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(
              'Distância mínima',
              insideAppPanel: true,
            ).copyWith(suffixText: 'm'),
            validator: InstallCriterionDraft.validateOptionalNumber,
            onChanged: (_) => setState(() => _dirty = true),
          ),
        ],
      ),
    ),
  );

  Widget _antennas() => FormFieldWrapper(
    title: 'Antenas',
    titleColor: const Color(0xFFABC2BC),
    child: AppPanel(
      child: Column(
        children: [
          TextFormField(
            key: _fieldKeys.putIfAbsent(
              '_antennaAnalysisRadius',
              () => GlobalKey<FormFieldState<String>>(),
            ),
            controller: _antennaAnalysisRadius,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(
              'Raio de análise',
              insideAppPanel: true,
            ).copyWith(suffixText: 'm'),
            validator: InstallCriterionDraft.validateOptionalNumber,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _fieldKeys.putIfAbsent(
              '_antennaMaximumQuantity',
              () => GlobalKey<FormFieldState<String>>(),
            ),
            controller: _antennaMaximumQuantity,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: _decoration('Quantidade máxima', insideAppPanel: true),
            validator: InstallCriterionDraft.validateOptionalInteger,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _fieldKeys.putIfAbsent(
              '_antennaMaximumDistance',
              () => GlobalKey<FormFieldState<String>>(),
            ),
            controller: _antennaMaximumDistance,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(
              'Distância máxima',
              insideAppPanel: true,
            ).copyWith(suffixText: 'm'),
            validator: InstallCriterionDraft.validateOptionalNumber,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 12),
          SwitchField(
            label: 'Considerar conflito de frequência',
            value: _considerFrequencyConflict,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _considerFrequencyConflict = value;
                    _dirty = true;
                  }),
          ),
        ],
      ),
    ),
  );

  void _revealError([BuildContext? invalidContext]) {
    setState(
      () => _expandedSections.addAll([
        'assets',
        'relief',
        'vegetation',
        'buildings',
        'antennas',
      ]),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = invalidContext ?? _errorKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: .15,
        );
      }
    });
  }

  String get _assetSummary {
    final allowed = _assetChipItems[CriterionCollection.allowedTypes]!.length;
    final blocked = _assetChipItems[CriterionCollection.blockedTypes]!.length;
    return '$allowed permitidos · $blocked bloqueados · ${(criterionAssetTypes.length - allowed - blocked).clamp(0, criterionAssetTypes.length)} neutros';
  }

  String _numericSummary(List<TextEditingController> fields) {
    final count = fields.where((field) => field.text.trim().isNotEmpty).length;
    return count == 0
        ? 'Nenhum limite numérico definido'
        : '$count limites numéricos definidos';
  }

  Widget _section(Widget content, String id, String summary) {
    final section = content as FormFieldWrapper;
    final open = _expandedSections.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                key: ValueKey('section-$id'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  open
                      ? _expandedSections.remove(id)
                      : _expandedSections.add(id);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              summary,
                              style: const TextStyle(
                                color: Color(0xFFABC2BC),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Offstage(
              offstage: !open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: section.child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  RangeValues get _distanceSliderValues {
    final start = (_draft.minDistanceMeters ?? 10).clamp(10, 500).toDouble();
    final end = (_draft.maxDistanceMeters ?? 500).clamp(10, 500).toDouble();
    return RangeValues(start <= end ? start : end, end);
  }

  Widget _distanceInput(bool minimum) => TextFormField(
    key: ValueKey(minimum ? 'distance-minimum' : 'distance-maximum'),
    controller: minimum ? _distanceMinimum : _distanceMaximum,
    enabled: !_saving,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: _decoration(minimum ? 'Distância mínima' : 'Distância máxima')
        .copyWith(suffixText: 'm', hintText: 'Não definida'),
    validator: (text) {
      if (text == null || text.trim().isEmpty) return null;
      final value = double.tryParse(text.trim().replaceAll(',', '.'));
      if (value == null || !value.isFinite || value < 10 || value > 500) {
        return 'Use um valor de 10 a 500 m.';
      }
      if (minimum &&
          _draft.maxDistanceMeters != null &&
          value > _draft.maxDistanceMeters!) {
        return 'A mínima deve ser menor ou igual à máxima.';
      }
      return null;
    },
    onChanged: (text) => setState(() {
      final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
      final value = parsed != null && parsed.isFinite ? parsed : null;
      if (minimum) {
        _draft.minDistanceMeters = value;
      } else {
        _draft.maxDistanceMeters = value;
      }
      _dirty = true;
    }),
  );

  Widget _actions() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 8,
    children: [
      SecondaryButton(label: 'Cancelar', onPressed: _saving ? null : _close),
      const SizedBox(width: 12),
      PrimaryButton(
        label: _saving ? 'Salvando…' : 'Salvar critério',
        onPressed: _saving ? null : _save,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _saving ? null : _close,
                    tooltip: 'Voltar',
                    icon: const Icon(Icons.arrow_back, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      widget.criterion == null
                          ? 'Novo critério'
                          : 'Editar critério',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (desktop) _actions(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(desktop ? 28 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          key: _errorKey,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Nome obrigatório. Nos campos numéricos opcionais, deixe em branco para não definir a restrição.',
                          style: TextStyle(
                            color: Color(0xFFABC2BC),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (constraints.maxWidth >= 1100) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [_identity(), _scenarioLimits()],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: _requirements()),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _assets()),
                            const SizedBox(width: 24),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, size) => size.maxWidth >= 650
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _relief(),
                                                _vegetation(),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _buildings(),
                                                _antennas(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _relief(),
                                          _vegetation(),
                                          _buildings(),
                                          _antennas(),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        _identity(),
                        _requirements(),
                        _section(_assets(), 'assets', _assetSummary),
                        _section(
                          _relief(),
                          'relief',
                          _numericSummary([
                            _minimumAltitude,
                            _maximumAltitude,
                            _maximumSlope,
                          ]),
                        ),
                        _section(
                          _vegetation(),
                          'vegetation',
                          '${_allowedVegetationItems.length} permitidas · ${_blockedVegetationItems.length} proibidas',
                        ),
                        _section(
                          _buildings(),
                          'buildings',
                          _numericSummary([
                            _buildingAnalysisRadius,
                            _buildingMaximumQuantity,
                            _buildingMaximumHeight,
                            _buildingMinimumDistance,
                          ]),
                        ),
                        _section(
                          _antennas(),
                          'antennas',
                          '${_numericSummary([_antennaAnalysisRadius, _antennaMaximumQuantity, _antennaMaximumDistance])} · conflito de frequência ${_considerFrequencyConflict ? "sim" : "não"}',
                        ),
                        _scenarioLimits(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!desktop)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _actions(),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
