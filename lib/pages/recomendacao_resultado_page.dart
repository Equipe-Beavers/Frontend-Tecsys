import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/auth/auth_scope.dart';
import '../widgets/branded_loading_screen.dart';

import '../models/mancha_cenario.dart';
import '../models/recomendacao_resultado.dart';
import '../services/mancha_cenario_service.dart';
import '../services/exportacao_service.dart';
import '../services/file_download_service.dart';
import '../services/recomendacao_service.dart';
import '../theme/app_colors.dart';
import '../widgets/recommendation/export_results_button.dart';
import '../widgets/recommendation/map_snapshot_controller.dart';
import '../widgets/recommendation/recommendation_result_panel.dart';
import '../widgets/recommendation/scenario_map_capture.dart';
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
    this.exportRepository,
    this.fileDownloader,
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

  final StudyExportRepository? exportRepository;
  final FileDownloader? fileDownloader;

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
  final _mapSnapshot = MapSnapshotController();
  final _scenarioCapture = ScenarioMapCaptureController();
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
    if (repository == null ||
        _coverageByScenario.containsKey(result.idCenario)) {
      return;
    }
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

  Future<Map<int, Uint8List>> _captureOtherScenarioMaps(
    RecommendationScenarios group,
    ResultadoRecomendacao visible,
    Uint8List? imagemVisivel,
  ) => OtherScenarioMapsCollector(capturar: _scenarioCapture.capturar).coletar(
    cenarios: [
      for (final scenario in group.scenarios)
        ScenarioMapData.fromResult(
          scenario,
          coverage:
              _coverageByScenario[scenario.idCenario]?.gateways ?? const [],
        ),
    ],
    idCenarioVisivel: visible.idCenario,
    imagemVisivel: imagemVisivel,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<RecommendationScenarios>(
    future: _futureScenarios,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const BrandedLoadingScreen(
          message: 'Calculando a recomendação de cobertura...',
        );
      }
      return Scaffold(
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
        body: snapshot.hasError
            ? _RecommendationError(
                message: snapshot.error.toString(),
                onRetry: () =>
                    setState(() => _futureScenarios = _loadScenarios()),
              )
            : Builder(
                builder: (context) {
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.navBarBackground,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final scenario in group.scenarios)
                                  _ScenarioTab(
                                    key: ValueKey(
                                      'scenario-tab-${scenario.idCenario}',
                                    ),
                                    label: scenario.optimized
                                        ? 'Otimizada'
                                        : scenario.name,
                                    selected:
                                        scenario.idCenario == result.idCenario,
                                    kept:
                                        scenario.idCenario ==
                                        _selectedScenarioId,
                                    onTap: () {
                                      final active = group.scenarios.firstWhere(
                                        (item) =>
                                            item.idCenario ==
                                            scenario.idCenario,
                                      );
                                      setState(
                                        () => _activeScenarioId =
                                            active.idCenario,
                                      );
                                      unawaited(_loadScenarioCoverage(active));
                                    },
                                  ),
                              ],
                            ),
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
                              _coverageByScenario[result.idCenario]?.gateways ??
                              const [],
                          onGatewayTap: (gateway) =>
                              _openGateway(result, gateway),
                          snapshotController: _mapSnapshot,
                          scenarioCaptureHost: ScenarioMapCaptureHost(
                            controller: _scenarioCapture,
                            showBaseMap: widget.showBaseMap,
                          ),
                          exportButton: ExportResultsButton(
                            idEstudo: widget.idEstudo,
                            idCenario: result.idCenario,
                            snapshotController: _mapSnapshot,
                            capturarOutrosMapas: group.scenarios.length > 1
                                ? (imagem) => _captureOtherScenarioMaps(
                                    group,
                                    result,
                                    imagem,
                                  )
                                : null,
                            repository: widget.exportRepository,
                            downloader: widget.fileDownloader,
                          ),
                        ),
                      ),
                      if (widget.resultadoInicial == null &&
                          group.scenarios.length > 1)
                        SafeArea(
                          top: false,
                          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              key: const ValueKey('keep-scenario'),
                              onPressed:
                                  _saving ||
                                      result.idCenario == _selectedScenarioId
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
    },
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
    required this.snapshotController,
    required this.scenarioCaptureHost,
    required this.exportButton,
    this.subtitle,
  });

  final ResultadoRecomendacao result;
  final bool showBaseMap;
  final List<ManchaGatewayCenario> scenarioCoverage;
  final ValueChanged<GatewayProposto> onGatewayTap;
  final MapSnapshotController snapshotController;
  final Widget scenarioCaptureHost;
  final Widget exportButton;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      final map = Stack(
        children: [
          Positioned.fill(child: scenarioCaptureHost),
          Positioned.fill(
            child: RecommendationMap(
              gateways: result.gateways,
              assets: result.ativosMapa,
              scenarioCoverage: scenarioCoverage,
              onGatewayTap: onGatewayTap,
              showBaseMap: showBaseMap,
              snapshotController: snapshotController,
            ),
          ),
        ],
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
            SizedBox(
              width: 390,
              child: Column(
                children: [
                  Expanded(child: summary),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: exportButton,
                  ),
                ],
              ),
            ),
          ],
        );
      }
      return SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('mobile-recommendation-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: SizedBox(
                        height: (constraints.maxHeight * .43).clamp(
                          280.0,
                          360.0,
                        ),
                        child: map,
                      ),
                    ),
                    summary,
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceBackground,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: exportButton,
            ),
          ],
        ),
      );
    },
  );
}

class _ScenarioTab extends StatelessWidget {
  const _ScenarioTab({
    super.key,
    required this.label,
    required this.selected,
    required this.kept,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool kept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: kept ? '$label, cenário mantido no estudo' : label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLime : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kept) ...[
              Icon(
                Icons.check,
                size: 16,
                color: selected ? AppColors.textDark : AppColors.primaryLime,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textDark : AppColors.textMuted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
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
