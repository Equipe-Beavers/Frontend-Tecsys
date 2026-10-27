import 'package:flutter/material.dart';

import '../../models/ativo_bdgd.dart';
import '../../models/recomendacao_resultado.dart';
import '../../theme/app_colors.dart';

class GatewayDetailsPanel extends StatelessWidget {
  const GatewayDetailsPanel({
    super.key,
    required this.gateway,
    this.scrollable = true,
  });

  final GatewayProposto gateway;
  final bool scrollable;

  Map<TipoAtivo, int> get _counts {
    final result = <TipoAtivo, int>{};
    for (final attendance in gateway.atendidos) {
      result.update(
        attendance.tipoAtivo,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return result;
  }

  String _distance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    }
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      key: const ValueKey('gateway-details-panel'),
      color: AppColors.surfaceCardLight,
      child: SingleChildScrollView(
        primary: scrollable ? null : false,
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gateway.rotulo ?? 'Gateway ${gateway.idEstudoPonto}',
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'RF-SIM-${gateway.idEstudoPonto.toString().padLeft(5, '0')}  ·  GATEWAY PROPOSTO',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ),
                ),
                if (gateway.status != null)
                  _StatusBadge(status: gateway.status!),
              ],
            ),
            const SizedBox(height: 22),
            _InfoLine(label: 'Local', value: gateway.local ?? 'Não informado'),
            _InfoLine(
              label: 'Coordenadas',
              value:
                  '${gateway.latitude.toStringAsFixed(4)}°, ${gateway.longitude.toStringAsFixed(4)}°',
            ),
            _InfoLine(
              label: 'Ativo elétrico',
              value: gateway.descricaoAtivo ?? 'Não informado',
            ),
            _InfoLine(
              label: 'ID do ativo (BDGD)',
              value: gateway.idAtivoBdgd ?? 'Não informado',
              highlight: gateway.idAtivoBdgd != null,
            ),
            _InfoLine(
              label: 'Alimentador',
              value: gateway.alimentador ?? 'Não informado',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'ATIVOS ATENDIDOS',
                    value: '${gateway.quantidadeAtendidos}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'ALCANCE EST.',
                    value: _distance(gateway.raioCoberturaM),
                    valueColor: AppColors.textWhite,
                  ),
                ),
              ],
            ),
            if (counts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final entry in counts)
                    _AttendanceChip(
                      label: '${entry.value} ${entry.key.label.toLowerCase()}',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primaryLime,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      status,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 8,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _AttendanceChip extends StatelessWidget {
  const _AttendanceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceInput,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: highlight ? AppColors.secondaryTeal : AppColors.textWhite,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.valueColor = AppColors.primaryLime,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 8,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
