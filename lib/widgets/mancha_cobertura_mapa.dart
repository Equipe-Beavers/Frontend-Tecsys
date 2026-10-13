import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/models/edificacao.dart';
import 'package:frontend_tecsys/services/edificacoes_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

/// Mapa com a mancha de cobertura de cada gateway de um cenário (calculada com as edificações).
/// Busca os dados em `GET /get-scenario-coverage/:id`; se não houver mancha, não mostra nada.
class ManchaCoberturaMapa extends StatefulWidget {
  final int idCenario;
  final double altura;

  const ManchaCoberturaMapa({
    super.key,
    required this.idCenario,
    this.altura = 280,
  });

  @override
  State<ManchaCoberturaMapa> createState() => _ManchaCoberturaMapaState();
}

class _ManchaCoberturaMapaState extends State<ManchaCoberturaMapa> {
  final _service = EdificacoesService();
  late Future<ManchaCenario> _futureMancha;

  @override
  void initState() {
    super.initState();
    _futureMancha = _service.getManchaCenario(widget.idCenario);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ManchaCenario>(
      future: _futureMancha,
      builder: (context, snapshot) {
        final dados = snapshot.data;
        if (snapshot.hasError || dados == null || dados.vazia) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _buildMapa(dados),
        );
      },
    );
  }

  Widget _buildMapa(ManchaCenario dados) {
    final manchas = dados.gateways
        .where((g) => g.mancha.length >= 3)
        .map((g) => g.mancha)
        .toList();
    final pontos = <LatLng>[
      for (final mancha in manchas) ...mancha,
      for (final g in dados.gateways) g.posicao,
    ];

    return Container(
      height: widget.altura,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pontos),
            padding: const EdgeInsets.all(24),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.frontend_tecsys',
          ),
          PolygonLayer(
            polygons: <Polygon<Object>>[
              for (final mancha in manchas)
                Polygon<Object>(
                  points: mancha,
                  color: AppColors.secondaryTeal.withValues(alpha: 0.2),
                  borderColor: AppColors.secondaryTeal,
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              for (final g in dados.gateways)
                Marker(
                  point: g.posicao,
                  width: 30,
                  height: 30,
                  child: Tooltip(
                    message: g.alcanceMedioM != null
                        ? '${g.rotulo ?? 'Gateway ${g.idEstudoPonto}'} · alcance médio ${g.alcanceMedioM} m'
                        : g.rotulo ?? 'Gateway ${g.idEstudoPonto}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryLime, width: 2),
                      ),
                      child: const Icon(
                        Icons.wifi_tethering,
                        color: AppColors.primaryLime,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
