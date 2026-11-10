import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/auth/auth_scope.dart';

import '../models/mancha_cenario.dart';
import '../models/recomendacao_resultado.dart';
import '../services/mancha_cenario_service.dart';
import '../services/recomendacao_service.dart';
import '../theme/app_colors.dart';
import '../widgets/recommendation/recommendation_result_panel.dart';
import '../widgets/recommendation_map.dart';
import 'gateway_detail_page.dart';

class RecomendacaoResultadoPage extends StatefulWidget {
  const RecomendacaoResultadoPage({
    super.key,
    required this.idEstudo,
    required this.idPerfilRf,
    this.idCriterioInstalacao,
    this.titulo,
    this.subtitulo,
    this.resultadoInicial,
    this.showBaseMap = true,
    this.repository,
    this.coverageRepository,
  });

  final int idEstudo;
  final int idPerfilRf;
  final int? idCriterioInstalacao;
  final String? titulo;
  final String? subtitulo;
  final ResultadoRecomendacao? resultadoInicial;
  final bool showBaseMap;
  final RecommendationRepository? repository;
  final ScenarioCoverageRepository? coverageRepository;

  @override
  State<RecomendacaoResultadoPage> createState() =>
      _RecomendacaoResultadoPageState();
}

class _RecomendacaoResultadoPageState extends State<RecomendacaoResultadoPage> {
  late final RecommendationRepository _repository;
  RecomendacaoService? _ownedService;
  ManchaCenarioService? _ownedCoverageService;
  late Future<RecommendationScenarios> _futureScenarios;
  final Map<int, ManchaCenario> _coverageByScenario = {};
  int? _activeScenarioId;
  int? _selectedScenarioId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ownedService = widget.repository == null
        ? RecomendacaoService(client: AuthScope.clientOf(context))
        : null;
    _repository = widget.repository ?? _ownedService!;
    final shouldLoadCoverage =
        widget.coverageRepository != null ||
        (widget.resultadoInicial == null && widget.repository == null);
    if (shouldLoadCoverage) {
      _ownedCoverageService = widget.coverageRepository == null
          ? ManchaCenarioService(client: AuthScope.clientOf(context))
          : null;
    }
    _futureScenarios = _loadScenarios();
  }

  Future<RecommendationScenarios> _loadScenarios() async {
    final initial = widget.resultadoInicial;
    final group = initial != null
        ? RecommendationScenarios(scenarios: [initial])
        : await _repository.loadScenarios(
            studyId: widget.idEstudo,
            profileId: widget.idPerfilRf,
            criterionId: widget.idCriterioInstalacao,
          );
    if (group.scenarios.isEmpty) {
      throw StateError('Nenhum cenário disponível para este estudo.');
    }
    if (!mounted) return group;
    _selectedScenarioId = group.selectedScenarioId;
    final active = group.scenarios.firstWhere(
      (scenario) => scenario.idCenario == group.selectedScenarioId,
      orElse: () => group.scenarios.first,
    );
    _activeScenarioId = active.idCenario;
    unawaited(_loadScenarioCoverage(active));
    return group;
  }

  Future<void> _loadScenarioCoverage(ResultadoRecomendacao result) async {
    final repository = widget.coverageRepository ?? _ownedCoverageService;
    if (repository == null || _coverageByScenario.containsKey(result.idCenario))
      return;
    try {
      final coverage = await repository.getManchaCenario(result.idCenario);
      if (!mounted) return;
      setState(() => _coverageByScenario[result.idCenario] = coverage);
    } on Object {
      // A recomendacao continua utilizavel quando a mancha ainda nao existe.
    }
  }

  @override
  void dispose() {
    _ownedService?.dispose();
    _ownedCoverageService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surfaceBackground,
    appBar: AppBar(
      backgroundColor: AppColors.surfaceBackground,
      elevation: 0,
      leading: const BackButton(color: AppColors.textWhite),
      title: Text(
        widget.titulo ?? 'Resultado da recomendação',
        style: const TextStyle(color: AppColors.textWhite, fontSize: 16),
      ),
    ),
    body: FutureBuilder<RecommendationScenarios>(
      future: _futureScenarios,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RecommendationLoading();
        }
        if (snapshot.hasError) {
          return _RecommendationError(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _futureScenarios = _loadScenarios()),
          );
        }
        final group = snapshot.data!;
        final result = group.scenarios.firstWhere(
          (scenario) => scenario.idCenario == _activeScenarioId,
          orElse: () => group.scenarios.first,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (group.scenarios.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (final scenario in group.scenarios)
                      ButtonSegment(
                        value: scenario.idCenario,
                        label: Text(
                          scenario.optimized ? 'Otimizada' : scenario.name,
                          key: ValueKey('scenario-tab-${scenario.idCenario}'),
                        ),
                        icon: scenario.idCenario == _selectedScenarioId
                            ? const Icon(Icons.check_circle_outline, size: 16)
                            : null,
                      ),
                  ],
                  selected: {result.idCenario},
                  onSelectionChanged: (selection) {
                    final active = group.scenarios.firstWhere(
                      (scenario) => scenario.idCenario == selection.first,
                    );
                    setState(() => _activeScenarioId = active.idCenario);
                    unawaited(_loadScenarioCoverage(active));
                  },
                ),
              ),
            if (group.warning != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  group.warning!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: _RecommendationContent(
                key: ValueKey('scenario-content-${result.idCenario}'),
                result: result,
                subtitle: widget.subtitulo,
                showBaseMap: widget.showBaseMap,
                scenarioCoverage:
                    _coverageByScenario[result.idCenario]?.gateways ?? const [],
                onGatewayTap: (gateway) => _openGateway(result, gateway),
              ),
            ),
            if (widget.resultadoInicial == null)
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const ValueKey('keep-scenario'),
                    onPressed:
                        _saving || result.idCenario == _selectedScenarioId
                        ? null
                        : () => _selectScenario(result),
                    icon: Icon(
                      result.idCenario == _selectedScenarioId
                          ? Icons.check_circle
                          : Icons.check,
                    ),
                    label: Text(
                      _saving
                          ? 'Salvando...'
                          : result.idCenario == _selectedScenarioId
                          ? 'Cenário mantido no estudo'
                          : 'Manter este cenário',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Future<void> _selectScenario(ResultadoRecomendacao result) async {
    setState(() => _saving = true);
    try {
      await _repository.selectScenario(
        studyId: widget.idEstudo,
        scenarioId: result.idCenario,
      );
      if (!mounted) return;
      setState(() => _selectedScenarioId = result.idCenario);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} mantida no estudo.')),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível manter o cenário. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openGateway(ResultadoRecomendacao result, GatewayProposto gateway) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GatewayDetailPage(
          gateway: gateway,
          assets: result.ativosMapa,
          scenarioCoverage:
              _coverageByScenario[result.idCenario]?.gateways
                  .where(
                    (coverage) =>
                        coverage.idEstudoPonto == gateway.idEstudoPonto,
                  )
                  .toList() ??
              const [],
          studyTitle: widget.titulo,
          showBaseMap: widget.showBaseMap,
        ),
      ),
    );
  }
}

class _RecommendationContent extends StatelessWidget {
  const _RecommendationContent({
    super.key,
    required this.result,
    required this.showBaseMap,
    required this.scenarioCoverage,
    required this.onGatewayTap,
    this.subtitle,
  });

  final ResultadoRecomendacao result;
  final bool showBaseMap;
  final List<ManchaGatewayCenario> scenarioCoverage;
  final ValueChanged<GatewayProposto> onGatewayTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      final map = RecommendationMap(
        gateways: result.gateways,
        assets: result.ativosMapa,
        scenarioCoverage: scenarioCoverage,
        onGatewayTap: onGatewayTap,
        showBaseMap: showBaseMap,
      );
      final summary = RecommendationResultPanel(
        scrollable: desktop,
        result: result,
        subtitle: subtitle,
        onGatewayTap: onGatewayTap,
      );

      if (desktop) {
        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                child: map,
              ),
            ),
            SizedBox(width: 390, child: summary),
          ],
        );
      }
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('mobile-recommendation-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: SizedBox(
                  height: (constraints.maxHeight * .43).clamp(280.0, 360.0),
                  child: map,
                ),
              ),
              summary,
            ],
          ),
        ),
      );
    },
  );
}

class _RecommendationLoading extends StatelessWidget {
  const _RecommendationLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppColors.primaryLime),
        SizedBox(height: 16),
        Text(
          'Calculando a recomendação de cobertura...',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    ),
  );
}

class _RecommendationError extends StatelessWidget {
  const _RecommendationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.textMuted, size: 32),
          const SizedBox(height: 12),
          Text(
            'Não foi possível gerar a recomendação.\n\n$message',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
