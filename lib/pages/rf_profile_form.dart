import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../services/rf_profile_service.dart';
import '../models/rf_profile.dart';
import '../theme/app_colors.dart';
import '../widgets/app_panel.dart';
import '../widgets/form_field_wrapper.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/switch_field.dart';

class RFProfileForm extends StatefulWidget {
  const RFProfileForm({
    super.key,
    required this.userId,
    required this.onClose,
    required this.onSave,
    this.profile,
  });

  final int userId;
  final VoidCallback onClose;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final RFProfile? profile;

  @override
  State<RFProfileForm> createState() => _RFProfileFormState();
}

class _RFProfileFormState extends State<RFProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _frequency;
  late final TextEditingController _transmitPower;
  late final TextEditingController _receiveSensitivity;
  late final TextEditingController _additionalAttenuation;
  late final TextEditingController _gatewayHeight;
  late final TextEditingController _deviceHeight;
  late final TextEditingController _maximumEquipment;
  bool _considersRelief = true;
  bool _considersVegetation = true;
  bool _considersBuildings = true;
  bool _considersAntennas = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _frequency = TextEditingController(
      text: profile == null ? '' : _initialNumber(profile.frequencyMhz),
    );
    _transmitPower = TextEditingController(
      text: profile == null ? '' : _initialNumber(profile.transmitPowerDbm),
    );
    _receiveSensitivity = TextEditingController(
      text: profile == null
          ? ''
          : _initialNumber(profile.receiveSensitivityDbm.abs()),
    );
    _additionalAttenuation = TextEditingController(
      text: profile?.additionalAttenuationDb == null
          ? ''
          : _initialNumber(profile!.additionalAttenuationDb!),
    );
    _gatewayHeight = TextEditingController(
      text: profile?.gatewayHeightM == null
          ? ''
          : _initialNumber(profile!.gatewayHeightM!),
    );
    _deviceHeight = TextEditingController(
      text: profile?.deviceHeightM == null
          ? ''
          : _initialNumber(profile!.deviceHeightM!),
    );
    _maximumEquipment = TextEditingController(
      text: profile?.maximumEquipment?.toString() ?? '',
    );
    _considersRelief = profile?.considersRelief ?? true;
    _considersVegetation = profile?.considersVegetation ?? true;
    _considersBuildings = profile?.considersBuildings ?? true;
    _considersAntennas = profile?.considersAntennas ?? true;
  }

  String _initialNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString().replaceAll('.', ',');

  @override
  void dispose() {
    for (final controller in [
      _name,
      _frequency,
      _transmitPower,
      _receiveSensitivity,
      _additionalAttenuation,
      _gatewayHeight,
      _deviceHeight,
      _maximumEquipment,
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
            'As alterações deste perfil RF ainda não foram salvas.',
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
    final values = <String, dynamic>{
      if (widget.profile == null) 'id_usuario': widget.userId,
      'nome': _name.text.trim(),
      'frequencia_mhz': _numberValue(_frequency.text),
      'potencia_transmissao_dbm': _numberValue(_transmitPower.text),
      'sensibilidade_recepcao_dbm': -_numberValue(_receiveSensitivity.text)
          .abs(),
      'altura_gateway_m': _optionalNumber(_gatewayHeight.text),
      'altura_dispositivo_m': _optionalNumber(_deviceHeight.text),
      'capacidade_max_equipamentos': _optionalInteger(_maximumEquipment.text),
      'atenuacao_adicional_db': _optionalNumber(_additionalAttenuation.text),
      'considera_relevo': _considersRelief,
      'considera_vegetacao': _considersVegetation,
      'considera_edificacoes': _considersBuildings,
      'considera_antenas': _considersAntennas,
    };
    try {
      await widget.onSave(values);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is RFProfileApiException ? error.message : 'Não foi possível salvar. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _numberValue(String text) =>
      double.parse(text.trim().replaceAll(',', '.'));

  double? _optionalNumber(String text) =>
      text.trim().isEmpty ? null : _numberValue(text);

  int? _optionalInteger(String text) =>
      text.trim().isEmpty ? null : int.parse(text.trim());

  void _changed(String _) {
    setState(() => _dirty = true);
  }

  double? get _estimatedRangeKm {
    final frequency = double.tryParse(_frequency.text.replaceAll(',', '.'));
    final transmitPower = double.tryParse(
      _transmitPower.text.replaceAll(',', '.'),
    );
    final sensitivity = double.tryParse(
      _receiveSensitivity.text.replaceAll(',', '.'),
    );
    final attenuation =
        double.tryParse(_additionalAttenuation.text.replaceAll(',', '.')) ?? 0;
    if (frequency == null ||
        transmitPower == null ||
        sensitivity == null ||
        frequency <= 0) {
      return null;
    }
    const planningMarginDb = 20.0;
    final pathLossConstant = 20 * math.log(frequency) / math.ln10 + 32.44;
    final exponent =
        (transmitPower +
            sensitivity.abs() -
            attenuation -
            planningMarginDb -
            pathLossConstant) /
        20;
    final rangeKm = math.pow(10, exponent).toDouble();
    return rangeKm.isFinite ? rangeKm : null;
  }

  String _format(double value, {int fractionDigits = 1}) =>
      value.toStringAsFixed(fractionDigits).replaceAll('.', ',');

  InputDecoration _decoration(
    String label, {
    String? hint,
    String? unit,
    String? prefix,
    bool insideAppPanel = false,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    suffixText: unit,
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

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe o nome do perfil.';
    }
    if (value.trim().length > 150) {
      return 'Use até 150 caracteres.';
    }
    return null;
  }

  String? _validateNumber(
    String? text, {
    required String label,
    bool required = false,
  }) {
    if (text == null || text.trim().isEmpty) {
      return required ? 'Informe $label.' : null;
    }
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite) return 'Informe um número válido.';
    return null;
  }

  String? _validateCapacity(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return int.tryParse(text.trim()) == null
        ? 'Informe um inteiro válido.'
        : null;
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    String? hint,
    String? unit,
    String? prefix,
    List<TextInputFormatter>? inputFormatters,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool insideAppPanel = false,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLength: maxLength,
    decoration: _decoration(
      label,
      hint: hint,
      unit: unit,
      prefix: prefix,
      insideAppPanel: insideAppPanel,
    ),
    validator: validator,
    onChanged: _changed,
  );

  Widget _numericField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    required String unit,
    bool integer = false,
    bool unsigned = false,
    String? prefix,
    bool insideAppPanel = false,
  }) => _textField(
    label: label,
    controller: controller,
    validator: validator,
    unit: unit,
    prefix: prefix,
    inputFormatters: unsigned
        ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))]
        : null,
    insideAppPanel: insideAppPanel,
    keyboardType: integer
        ? TextInputType.number
        : TextInputType.numberWithOptions(decimal: true, signed: !unsigned),
  );

  Widget _pair(Widget first, Widget second, bool wide) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        )
      : Column(children: [first, const SizedBox(height: 12), second]);

  Widget _leftColumn(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FormFieldWrapper(
        title: 'Nome do perfil',
        child: _textField(
          label: 'Nome',
          controller: _name,
          validator: _validateName,
          maxLength: 150,
        ),
      ),
      FormFieldWrapper(
        title: 'Parâmetros de RF',
        child: AppPanel(
          child: Column(
            children: [
              _pair(
                _numericField(
                  label: 'Frequência',
                  controller: _frequency,
                  validator: (value) => _validateNumber(
                    value,
                    label: 'a frequência',
                    required: true,
                  ),
                  unit: 'MHz',
                  insideAppPanel: true,
                ),
                _numericField(
                  label: 'Potência de transmissão',
                  controller: _transmitPower,
                  validator: (value) => _validateNumber(
                    value,
                    label: 'a potência',
                    required: true,
                  ),
                  unit: 'dBm',
                  insideAppPanel: true,
                ),
                wide,
              ),
              const SizedBox(height: 12),
              _pair(
                _numericField(
                  label: 'Sensibilidade de recepção',
                  controller: _receiveSensitivity,
                  validator: (value) => _validateNumber(
                    value,
                    label: 'a sensibilidade',
                    required: true,
                  ),
                  unit: 'dBm',
                  prefix: '-',
                  unsigned: true,
                  insideAppPanel: true,
                ),
                _numericField(
                  label: 'Atenuação adicional',
                  controller: _additionalAttenuation,
                  validator: (value) =>
                      _validateNumber(value, label: 'a atenuação'),
                  unit: 'dB',
                  insideAppPanel: true,
                ),
                wide,
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: _decoration(
                  'Alcance estimado',
                  unit: 'km',
                  insideAppPanel: true,
                ),
                child: Text(
                  _estimatedRangeKm == null
                      ? 'Preencha os parâmetros de RF'
                      : _format(_estimatedRangeKm!),
                  style: TextStyle(
                    color: _estimatedRangeKm == null
                        ? AppColors.textMuted
                        : AppColors.primaryLime,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      FormFieldWrapper(
        title: 'Parâmetros de instalação',
        child: AppPanel(
          child: Column(
            children: [
              _numericField(
                label: 'Altura do gateway em relação ao solo',
                controller: _gatewayHeight,
                validator: (value) =>
                    _validateNumber(value, label: 'a altura do gateway'),
                unit: 'm',
                insideAppPanel: true,
              ),
              const SizedBox(height: 12),
              _numericField(
                label: 'Altura do dispositivo em relação ao solo',
                controller: _deviceHeight,
                validator: (value) =>
                    _validateNumber(value, label: 'a altura do dispositivo'),
                unit: 'm',
                insideAppPanel: true,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _rightColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FormFieldWrapper(
        title: 'Condições de cobertura',
        child: Column(
          children: [
            _numericField(
              label: 'Máx. equipamentos atendidos',
              controller: _maximumEquipment,
              validator: _validateCapacity,
              unit: '',
              integer: true,
            ),
            const SizedBox(height: 12),
            SwitchField(
              label: 'Consideração de relevo',
              value: _considersRelief,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _considersRelief = value;
                      _dirty = true;
                    }),
            ),
            const SizedBox(height: 8),
            SwitchField(
              label: 'Consideração de vegetação',
              value: _considersVegetation,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _considersVegetation = value;
                      _dirty = true;
                    }),
            ),
            const SizedBox(height: 8),
            SwitchField(
              label: 'Consideração de edificações',
              value: _considersBuildings,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _considersBuildings = value;
                      _dirty = true;
                    }),
            ),
            const SizedBox(height: 8),
            SwitchField(
              label: 'Consideração de antenas',
              value: _considersAntennas,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _considersAntennas = value;
                      _dirty = true;
                    }),
            ),
          ],
        ),
      ),
      FormFieldWrapper(
        title: 'Prévia do perfil',
        child: AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.65,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final diameter = constraints.biggest.shortestSide * 0.72;
                    final rangeKm = _estimatedRangeKm;
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (rangeKm != null)
                            Container(
                              width: diameter,
                              height: diameter,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primaryLime.withValues(
                                      alpha: .36,
                                    ),
                                    AppColors.primaryLime.withValues(
                                      alpha: .14,
                                    ),
                                    AppColors.primaryLime.withValues(
                                      alpha: .02,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLime,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 8,
                            child: Text(
                              rangeKm == null
                                  ? 'alcance —'
                                  : 'raio ${_format(rangeKm)} km',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _previewMetric(
                'Cobertura estimada',
                _estimatedRangeKm == null
                    ? '— km²'
                    : '${_format(math.pi * math.pow(_estimatedRangeKm!, 2))} km²',
                AppColors.textWhite,
              ),
              const SizedBox(height: 6),
              _previewMetric(
                'Alcance estimado',
                _estimatedRangeKm == null
                    ? '— km'
                    : '${_format(_estimatedRangeKm!)} km',
                AppColors.primaryLime,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _previewMetric(String label, String value, Color valueColor) =>
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 300
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      );

  Widget _actions() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 8,
    children: [
      SecondaryButton(label: 'Cancelar', onPressed: _saving ? null : _close),
      const SizedBox(width: 12),
      PrimaryButton(
        label: _saving ? 'Salvando...' : 'Salvar perfil',
        onPressed: _saving ? null : _save,
      ),
    ],
  );

  Widget _mobileActions() => Row(
    children: [
      Expanded(
        child: SecondaryButton(
          label: 'Cancelar',
          onPressed: _saving ? null : _close,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: PrimaryButton(
          label: _saving ? 'Salvando...' : 'Salvar perfil',
          onPressed: _saving ? null : _save,
        ),
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
        final wideForm = constraints.maxWidth >= 1000;
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
                      widget.profile == null
                          ? 'Novo perfil de RF'
                          : 'Editar perfil de RF',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (desktop) _actions(),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(desktop ? 28 : 20),
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
                      if (wideForm)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _leftColumn(true)),
                            const SizedBox(width: 20),
                            Expanded(child: _rightColumn()),
                          ],
                        )
                      else ...[
                        _leftColumn(false),
                        _rightColumn(),
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
                    child: _mobileActions(),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
