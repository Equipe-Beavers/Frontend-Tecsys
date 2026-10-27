import 'package:flutter/material.dart';

import '../models/mancha_cenario.dart';
import '../models/recomendacao_resultado.dart';
import '../theme/app_colors.dart';
import '../widgets/recommendation/gateway_details_panel.dart';
import '../widgets/recommendation_map.dart';

class GatewayDetailPage extends StatelessWidget {
  const GatewayDetailPage({
    super.key,
    required this.gateway,
    this.assets = const [],
    this.scenarioCoverage = const [],
    this.studyTitle,
    this.showBaseMap = true,
  });

  final GatewayProposto gateway;
  final List<AtivoResultadoMapa> assets;
  final List<ManchaGatewayCenario> scenarioCoverage;
  final String? studyTitle;
  final bool showBaseMap;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surfaceBackground,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 800;
          final map = RecommendationMap(
            gateways: [gateway],
            assets: assets,
            scenarioCoverage: scenarioCoverage,
            selectedGateway: gateway,
            lockPosition: true,
            showBaseMap: showBaseMap,
          );
          final details = GatewayDetailsPanel(
            gateway: gateway,
            scrollable: desktop,
          );

          return Column(
            children: [
              _DetailHeader(
                title: studyTitle,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: map,
                            ),
                          ),
                          SizedBox(width: 360, child: details),
                        ],
                      )
                    : SingleChildScrollView(
                        key: const ValueKey('mobile-gateway-scroll'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                12,
                              ),
                              child: SizedBox(
                                height: ((constraints.maxHeight - 64) * .43)
                                    .clamp(280.0, 360.0),
                                child: map,
                              ),
                            ),
                            details,
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.onBack});

  final String? title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Voltar ao resultado'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textWhite),
        ),
        if (title != null) ...[
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              title!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
