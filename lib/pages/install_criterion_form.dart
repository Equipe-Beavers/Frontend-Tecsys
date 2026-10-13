import 'package:flutter/material.dart';

import '../models/install_criterion.dart';
import '../models/install_criterion_draft.dart';
import '../widgets/criterion_type_dialog.dart';
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
      CriterionCollection.allowedTypes: {
        'POSTES',
        'SUBESTACOES',
        'TORRES',
        'EDIFICACOES_PROPRIAS',
        'RESERVATORIOS',
        ..._draft.selection(CriterionCollection.allowedTypes),
      }.toList(),
      CriterionCollection.blockedTypes: {
        'POSTES_TERCEIROS',
        'ESTRUTURAS_PROVISORIAS',
        ..._draft.selection(CriterionCollection.blockedTypes),
      }.toList(),
    };
    _allowedVegetationItems = _draft.allowedVegetationTypes;
    _blockedVegetationItems = _draft.blockedVegetationTypes;
    for (final entry in _assetChipItems.entries) {
      _draft.setTypes(entry.key, entry.value);
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
    if (_saving || !_formKey.currentState!.validate()) return;
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
    try {
      await widget.onSave(values);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CriterionApiException ? error.message : 'Não foi possível salvar. Verifique a conexão e tente novamente.',
        );
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
    labelStyle: const TextStyle(color: AppColors.textMuted),
    hintStyle: const TextStyle(color: AppColors.textMuted),
    floatingLabelStyle: const TextStyle(color: AppColors.textMuted),
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

  void _updateAssetTypes(CriterionCollection field, List<String> items) {
    setState(() {
      _assetChipItems[field] = items;
      _draft.setTypes(field, items);
      _dirty = true;
    });
  }

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

  Widget _identity() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FormFieldWrapper(
        title: 'Nome do critério',
        child: TextFormField(
          controller: _name,
          enabled: !_saving,
          maxLength: 150,
          decoration: _decoration(
            'Nome',
            hint: 'Ex.: Padrão urbano — Postes e SEs',
          ),
          onChanged: (_) => _dirty = true,
          validator: InstallCriterionDraft.validateName,
        ),
      ),
      FormFieldWrapper(
        title: 'Ativos permitidos',
        titleColor: AppColors.secondaryTeal,
        child: EditableChipField(
          defaultItems: _assetChipItems[CriterionCollection.allowedTypes]!,
          availableItems: criterionAssetTypes.keys.toList(),
          excludedItems: _assetChipItems[CriterionCollection.blockedTypes]!
              .toSet(),
          itemLabels: criterionAssetTypes,
          colorVariant: ChipColorVariant.primary,
          enabled: !_saving,
          onAdd: (availableItems, existingItems) => _addChipItems(
            availableItems,
            existingItems,
            permittedItems: _assetChipItems[CriterionCollection.allowedTypes]!,
            forbiddenItems: _assetChipItems[CriterionCollection.blockedTypes]!,
            itemLabels: criterionAssetTypes,
            title: 'Adicionar tipo de ativo permitido',
          ),
          onItemsChanged: (items) =>
              _updateAssetTypes(CriterionCollection.allowedTypes, items),
        ),
      ),
      FormFieldWrapper(
        title: 'Ativos bloqueados',
        titleColor: Colors.orange,
        child: EditableChipField(
          defaultItems: _assetChipItems[CriterionCollection.blockedTypes]!,
          availableItems: criterionAssetTypes.keys.toList(),
          excludedItems: _assetChipItems[CriterionCollection.allowedTypes]!
              .toSet(),
          itemLabels: criterionAssetTypes,
          colorVariant: ChipColorVariant.secondary,
          enabled: !_saving,
          onAdd: (availableItems, existingItems) => _addChipItems(
            availableItems,
            existingItems,
            permittedItems: _assetChipItems[CriterionCollection.allowedTypes]!,
            forbiddenItems: _assetChipItems[CriterionCollection.blockedTypes]!,
            itemLabels: criterionAssetTypes,
            title: 'Adicionar tipo de ativo bloqueado',
          ),
          onItemsChanged: (items) =>
              _updateAssetTypes(CriterionCollection.blockedTypes, items),
        ),
      ),
    ],
  );

  String _formatKilometers(double meters) =>
      (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');

  String get _distanceLabel => _draft.maxDistanceMeters == null
      ? 'Não definida'
      : '${_formatKilometers(_draft.maxDistanceMeters!)} km';

  Widget _requirements() => Column(
    children: [
      FormFieldWrapper(
        title: 'Requisitos do local',
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
              label: 'Distância máxima aos ativos',
              valueLabel: _distanceLabel,
              minValue: 0,
              maxValue: 5000,
              values: RangeValues(
                0,
                (_draft.maxDistanceMeters ?? 0).clamp(0, 5000).toDouble(),
              ),
              divisions: 50,
              enableMin: false,
              enableMax: true,
              enabled: !_saving,
              rangeLabel: '0–5 km',
              valueFormatter: _formatKilometers,
              onChanged: (values) => setState(() {
                _draft.maxDistanceMeters = (values.end / 100).round() * 100.0;
                _dirty = true;
              }),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _scenarioLimits() => FormFieldWrapper(
    title: 'Limites do cenário',
    child: TextFormField(
      controller: _gatewayLimit,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      decoration: _decoration(
        'Máximo de gateways',
        hint: 'Sem limite definido',
      ),
      validator: InstallCriterionDraft.validateGatewayLimit,
      onChanged: (_) => _dirty = true,
    ),
  );

  Widget _firstColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [_identity(), _requirements()],
  );

  Widget _secondColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FormFieldWrapper(
        title: 'Relevo',
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
                      onChanged: (_) => _dirty = true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
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
                      onChanged: (_) => _dirty = true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FormFieldWrapper(
                title: 'Declividade em graus',
                child: TextFormField(
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
                  onChanged: (_) => _dirty = true,
                ),
              ),
            ],
          ),
        ),
      ),
      FormFieldWrapper(
        title: 'Vegetação',
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
      ),
    ],
  );

  Widget _thirdColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FormFieldWrapper(
        title: 'Edificações',
        child: AppPanel(
          child: Column(
            children: [
              TextFormField(
                controller: _buildingAnalysisRadius,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  'Raio de análise',
                  insideAppPanel: true,
                ).copyWith(suffixText: 'm'),
                validator: InstallCriterionDraft.validateOptionalNumber,
                onChanged: (_) => _dirty = true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _buildingMaximumQuantity,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: _decoration(
                  'Quantidade máxima',
                  insideAppPanel: true,
                ),
                validator: InstallCriterionDraft.validateOptionalInteger,
                onChanged: (_) => _dirty = true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _buildingMaximumHeight,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  'Altura máxima',
                  insideAppPanel: true,
                ).copyWith(suffixText: 'm'),
                validator: InstallCriterionDraft.validateOptionalNumber,
                onChanged: (_) => _dirty = true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _buildingMinimumDistance,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  'Distância mínima',
                  insideAppPanel: true,
                ).copyWith(suffixText: 'm'),
                validator: InstallCriterionDraft.validateOptionalNumber,
                onChanged: (_) => _dirty = true,
              ),
            ],
          ),
        ),
      ),
      FormFieldWrapper(
        title: 'Antenas',
        child: AppPanel(
          child: Column(
            children: [
              TextFormField(
                controller: _antennaAnalysisRadius,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  'Raio de análise',
                  insideAppPanel: true,
                ).copyWith(suffixText: 'm'),
                validator: InstallCriterionDraft.validateOptionalNumber,
                onChanged: (_) => _dirty = true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _antennaMaximumQuantity,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: _decoration(
                  'Quantidade máxima',
                  insideAppPanel: true,
                ),
                validator: InstallCriterionDraft.validateOptionalInteger,
                onChanged: (_) => _dirty = true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _antennaMaximumDistance,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  'Distância máxima',
                  insideAppPanel: true,
                ).copyWith(suffixText: 'm'),
                validator: InstallCriterionDraft.validateOptionalNumber,
                onChanged: (_) => _dirty = true,
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
      ),
      _scenarioLimits(),
    ],
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
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      if (constraints.maxWidth >= 900)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _firstColumn()),
                            const SizedBox(width: 16),
                            Expanded(child: _secondColumn()),
                            const SizedBox(width: 16),
                            Expanded(child: _thirdColumn()),
                          ],
                        )
                      else ...[
                        _firstColumn(),
                        _secondColumn(),
                        _thirdColumn(),
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
