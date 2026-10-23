import 'package:flutter/material.dart';

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
  late final Future<ResultadoRecomendacao> _futureResultado;
  ManchaCenario? _scenarioCoverage;

  @override
  void initState() {
    super.initState();
    _ownedService = widget.repository == null ? RecomendacaoService() : null;
    _repository = widget.repository ?? _ownedService!;
    _futureResultado = widget.resultadoInicial != null
        ? Future.value(widget.resultadoInicial)
        : _repository.gerarRecomendacao(
            idEstudo: widget.idEstudo,
            idPerfilRf: widget.idPerfilRf,
            idCriterioInstalacao: widget.idCriterioInstalacao,
          );

    final shouldLoadCoverage =
        widget.coverageRepository != null ||
        (widget.resultadoInicial == null && widget.repository == null);
    if (shouldLoadCoverage) {
      _ownedCoverageService = widget.coverageRepository == null
          ? ManchaCenarioService()
          : null;
      _futureResultado.then(_loadScenarioCoverage);
    }
  }

  Future<void> _loadScenarioCoverage(ResultadoRecomendacao result) async {
    final repository = widget.coverageRepository ?? _ownedCoverageService!;
    try {
      final coverage = await repository.getManchaCenario(result.idCenario);
      if (!mounted) return;
      setState(() => _scenarioCoverage = coverage);
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
    body: FutureBuilder<ResultadoRecomendacao>(
      future: _futureResultado,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RecommendationLoading();
        }
        if (snapshot.hasError) {
          return _RecommendationError(message: snapshot.error.toString());
        }
        return _RecommendationContent(
          result: snapshot.data!,
          subtitle: widget.subtitulo,
          showBaseMap: widget.showBaseMap,
          scenarioCoverage: _scenarioCoverage?.gateways ?? const [],
          onGatewayTap: (gateway) => _openGateway(snapshot.data!, gateway),
        );
      },
    ),
  );

  void _openGateway(ResultadoRecomendacao result, GatewayProposto gateway) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GatewayDetailPage(
          gateway: gateway,
          assets: result.ativosMapa,
          scenarioCoverage:
              _scenarioCoverage?.gateways
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
      return Column(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: map,
            ),
          ),
          Expanded(flex: 6, child: summary),
        ],
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
  const _RecommendationError({required this.message});

  final String message;

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
            'Não foi possível gerar a recomendação.\n$message',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
