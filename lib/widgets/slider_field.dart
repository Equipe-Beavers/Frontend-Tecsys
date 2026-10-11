import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SliderField extends StatelessWidget {
  const SliderField({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.minValue,
    required this.maxValue,
    required this.values,
    required this.onChanged,
    this.enableMin = false,
    this.enableMax = true,
    this.enabled = true,
    this.divisions,
    this.rangeLabel,
    this.valueFormatter,
  }) : assert(enableMin || enableMax),
       assert(minValue < maxValue);

  final String label;
  final String valueLabel;
  final double minValue;
  final double maxValue;
  final RangeValues values;
  final ValueChanged<RangeValues>? onChanged;
  final bool enableMin;
  final bool enableMax;
  final bool enabled;
  final int? divisions;
  final String? rangeLabel;
  final String Function(double value)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 4,
      activeTrackColor: AppColors.primaryLime,
      inactiveTrackColor: const Color(0xFF34534C),
      thumbColor: AppColors.primaryLime,
      overlayColor: AppColors.primaryLime.withValues(alpha: .12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      trackShape: const RoundedRectSliderTrackShape(),
    );
    final boundedValues = RangeValues(
      values.start.clamp(minValue, maxValue),
      values.end.clamp(minValue, maxValue),
    );

    Widget slider;
    if (enableMin && enableMax) {
      slider = RangeSlider(
        values: boundedValues,
        min: minValue,
        max: maxValue,
        divisions: divisions,
        labels: valueFormatter == null
            ? null
            : RangeLabels(
                valueFormatter!(boundedValues.start),
                valueFormatter!(boundedValues.end),
              ),
        onChanged: enabled ? onChanged : null,
      );
    } else {
      final controlsMin = enableMin;
      final value = controlsMin ? boundedValues.start : boundedValues.end;
      slider = Directionality(
        textDirection: controlsMin ? TextDirection.rtl : TextDirection.ltr,
        child: Slider(
          value: value,
          min: minValue,
          max: maxValue,
          divisions: divisions,
          label: valueFormatter?.call(value),
          onChanged: !enabled || onChanged == null
              ? null
              : (newValue) => onChanged!(
                  controlsMin
                      ? RangeValues(newValue, maxValue)
                      : RangeValues(minValue, newValue),
                ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Text(
                valueLabel,
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
                  label: label,
                  value: valueLabel,
                  child: SliderTheme(data: sliderTheme, child: slider),
                ),
              ),
              if (rangeLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  rangeLabel!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
