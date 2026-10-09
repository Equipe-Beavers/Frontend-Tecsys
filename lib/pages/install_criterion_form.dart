import 'package:flutter/material.dart';

import '../models/install_criterion.dart';
import '../models/install_criterion_draft.dart';
import '../widgets/criterion_type_dialog.dart';
import '../services/install_criterion_service.dart';
import '../theme/app_colors.dart';
import '../widgets/criterion_components.dart';

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
  final _locationControllers = <CriterionCollection, TextEditingController>{};
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = InstallCriterionDraft(original: widget.criterion);
    _name = TextEditingController(text: _draft.name);
    _gatewayLimit = TextEditingController(text: _draft.gatewayLimitText);
    for (final field in CriterionCollection.values.where(
      (field) => field.isLocation,
    )) {
      _locationControllers[field] = TextEditingController(
        text: _draft.selection(field).join('\n'),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _gatewayLimit,
      ..._locationControllers.values,
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
    final values = _draft.toPayload(userId: widget.userId);
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

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.surfaceCardLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.secondaryTeal),
    ),
  );

  Widget _preservedNotice(CriterionCollection field) {
    if (!_draft.preservesStructuredSelection(field)) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Text(
        'A seleção existente será mantida. Faça uma nova seleção somente se desejar substituí-la.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }

  Future<void> _addType(bool blocked) async {
    final type = await showDialog<String>(
      context: context,
      builder: (_) => CriterionTypeDialog(blocked: blocked),
    );
    if (type == null || !mounted) return;
    setState(() {
      _draft.selectType(type, blocked: blocked, selected: true);
      _dirty = true;
    });
  }

  Widget _assetSelection(bool blocked) {
    final field = blocked
        ? CriterionCollection.blockedTypes
        : CriterionCollection.allowedTypes;
    final selected = _draft.selection(field);
    final choices = {...criterionAssetTypes.keys, ...selected};
    return CriterionSection(
      title: blocked ? 'Ativos bloqueados' : 'Ativos permitidos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _preservedNotice(field),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final type in choices)
                FilterChip(
                  label: Text(
                    criterionAssetTypes[type] ?? type.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: selected.contains(type),
                  selectedColor: blocked
                      ? Colors.orange.withValues(alpha: .22)
                      : AppColors.secondaryTeal,
                  labelStyle: TextStyle(
                    color: selected.contains(type) && !blocked
                        ? AppColors.textDark
                        : AppColors.textWhite,
                  ),
                  checkmarkColor: blocked ? Colors.orange : AppColors.textDark,
                  backgroundColor: AppColors.surfaceCardLight,
                  side: BorderSide(
                    color: blocked && selected.contains(type)
                        ? Colors.orange.withValues(alpha: .5)
                        : AppColors.border,
                  ),
                  onSelected: _saving
                      ? null
                      : (enabled) => setState(() {
                          _draft.selectType(
                            type,
                            blocked: blocked,
                            selected: enabled,
                          );
                          _dirty = true;
                        }),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 15),
                label: const Text('Adicionar'),
                onPressed: _saving ? null : () => _addType(blocked),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identity() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CriterionSection(
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
      _assetSelection(false),
      _assetSelection(true),
    ],
  );

  String _formatKilometers(double meters) =>
      (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');

  String get _distanceLabel => _draft.maxDistanceMeters == null
      ? 'Não definida'
      : '${_formatKilometers(_draft.maxDistanceMeters!)} km';

  Widget _requirements() => Column(
    children: [
      CriterionSection(
        title: 'Requisitos do local',
        child: Column(
          children: [
            CriterionPanel(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Necessita alimentação elétrica',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 32,
                    child: Switch(
                      value: _draft.requiresPower ?? false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      thumbColor: const WidgetStatePropertyAll(
                        AppColors.surfaceBackground,
                      ),
                      trackColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppColors.primaryLime
                            : const Color(0xFF34534C),
                      ),
                      trackOutlineColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _draft.requiresPower = value;
                              _dirty = true;
                            }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CriterionPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Distância máxima aos ativos',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _distanceLabel,
                        style: const TextStyle(
                          color: AppColors.primaryLime,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: 'Distância máxima aos ativos',
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              activeTrackColor: AppColors.primaryLime,
                              inactiveTrackColor: const Color(0xFF34534C),
                              thumbColor: AppColors.primaryLime,
                              overlayColor: AppColors.primaryLime.withValues(
                                alpha: .12,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                              trackShape: const RoundedRectSliderTrackShape(),
                            ),
                            child: Slider(
                              // Keep legacy values unchanged until the slider is moved.
                              value: (_draft.maxDistanceMeters ?? 0)
                                  .clamp(0, 5000)
                                  .toDouble(),
                              min: 0,
                              max: 5000,
                              semanticFormatterCallback: (value) =>
                                  '${_formatKilometers(value)} quilômetros',
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(() {
                                      _draft.maxDistanceMeters =
                                          (value / 100).round() * 100.0;
                                      _dirty = true;
                                    }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '0–5 km',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      CriterionSection(
        title: 'Limites do cenário',
        child: CriterionPanel(
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
        ),
      ),
    ],
  );

  Widget _places() => CriterionSection(
    title: 'Locais de instalação',
    child: CriterionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informe os identificadores dos locais, um por linha. Deixe em branco quando não houver uma seleção.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          for (final field in _locationControllers.keys) ...[
            const SizedBox(height: 20),
            _preservedNotice(field),
            TextFormField(
              controller: _locationControllers[field],
              enabled: !_saving,
              minLines: 2,
              maxLines: 4,
              decoration: _decoration(field.label, hint: 'Ex.: POSTE:123'),
              onChanged: (value) => setState(() {
                _dirty = true;
                _draft.setLocations(field, value);
              }),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _actions() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 8,
    children: [
      TextButton(
        onPressed: _saving ? null : _close,
        child: const Text(
          'Cancelar',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
      const SizedBox(width: 12),
      CriterionPrimaryButton(
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
                      if (constraints.maxWidth >= 1000)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _identity()),
                            const SizedBox(width: 24),
                            Expanded(child: _requirements()),
                            const SizedBox(width: 24),
                            Expanded(child: _places()),
                          ],
                        )
                      else ...[
                        _identity(),
                        _requirements(),
                        _places(),
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
