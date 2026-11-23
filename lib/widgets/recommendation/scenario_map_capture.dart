import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/mancha_cenario.dart';
import '../../models/recomendacao_resultado.dart';
import '../recommendation_map.dart';
import 'map_snapshot_controller.dart';

class ScenarioMapData {
  const ScenarioMapData({
    required this.idCenario,
    required this.gateways,
    required this.assets,
    this.coverage = const [],
  });

  ScenarioMapData.fromResult(
    ResultadoRecomendacao result, {
    List<ManchaGatewayCenario> coverage = const [],
  }) : this(
         idCenario: result.idCenario,
         gateways: result.gateways,
         assets: result.ativosMapa,
         coverage: coverage,
       );

  final int idCenario;
  final List<GatewayProposto> gateways;
  final List<AtivoResultadoMapa> assets;

  final List<ManchaGatewayCenario> coverage;
}

class ScenarioMapCaptureController {
  _ScenarioMapCaptureHostState? _host;
  Future<void> _fila = Future.value();

  bool get isAttached => _host != null;

  Future<Uint8List?> capturar(
    ScenarioMapData data, {
    Duration timeout = const Duration(seconds: 12),
  }) {
    final resultado = _fila.then((_) {
      final host = _host;
      if (host == null) return Future<Uint8List?>.value();
      return host._capturar(data, timeout);
    });
    _fila = resultado.then((_) {}, onError: (_) {});
    return resultado;
  }
}

class ScenarioMapCaptureHost extends StatefulWidget {
  const ScenarioMapCaptureHost({
    super.key,
    required this.controller,
    this.showBaseMap = true,
  });

  final ScenarioMapCaptureController controller;
  final bool showBaseMap;

  @override
  State<ScenarioMapCaptureHost> createState() => _ScenarioMapCaptureHostState();
}

class _ScenarioMapCaptureHostState extends State<ScenarioMapCaptureHost> {
  ScenarioMapData? _atual;
  MapSnapshotController? _snapshot;

  @override
  void initState() {
    super.initState();
    widget.controller._host = this;
  }

  @override
  void didUpdateWidget(covariant ScenarioMapCaptureHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._host == this) oldWidget.controller._host = null;
      widget.controller._host = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._host == this) widget.controller._host = null;
    super.dispose();
  }

  Future<Uint8List?> _capturar(ScenarioMapData data, Duration timeout) async {
    if (!mounted || data.gateways.isEmpty) return null;
    final snapshot = MapSnapshotController();
    setState(() {
      _atual = data;
      _snapshot = snapshot;
    });
    try {
      final pronto = await snapshot.waitUntilReady(timeout: timeout);
      if (!pronto) {
        debugPrint(
          'Mapa do cenário ${data.idCenario} não ficou pronto a tempo; '
          'capturando assim mesmo.',
        );
      }
      return await snapshot.capture();
    } finally {
      if (mounted) {
        setState(() {
          _atual = null;
          _snapshot = null;
        });
        await WidgetsBinding.instance.endOfFrame;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final atual = _atual;
    if (atual == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RecommendationMap(
          key: ValueKey('scenario-capture-map-${atual.idCenario}'),
          gateways: atual.gateways,
          assets: atual.assets,
          scenarioCoverage: atual.coverage,
          showBaseMap: widget.showBaseMap,
          snapshotController: _snapshot,
        ),
      ),
    );
  }
}

class OtherScenarioMapsCollector {
  OtherScenarioMapsCollector({
    required this.capturar,
    this.maxCenarios = 20,
    this.limiteImagemBase64 = 10 * 1024 * 1024,
    this.limiteTotalBase64 = 38 * 1024 * 1024,
  });

  final Future<Uint8List?> Function(ScenarioMapData data) capturar;

  final int maxCenarios;
  final int limiteImagemBase64;
  final int limiteTotalBase64;

  static int tamanhoBase64(int bytes) => ((bytes + 2) ~/ 3) * 4;

  Future<Map<int, Uint8List>> coletar({
    required List<ScenarioMapData> cenarios,
    required int? idCenarioVisivel,
    Uint8List? imagemVisivel,
  }) async {
    var usado = imagemVisivel == null ? 0 : tamanhoBase64(imagemVisivel.length);
    final imagens = <int, Uint8List>{};

    for (final cenario in cenarios) {
      if (cenario.idCenario == idCenarioVisivel) continue;
      if (imagens.length >= maxCenarios) break;
      try {
        final imagem = await capturar(cenario);
        if (imagem == null || imagem.isEmpty) continue;
        final tamanho = tamanhoBase64(imagem.length);
        if (tamanho > limiteImagemBase64 ||
            usado + tamanho > limiteTotalBase64) {
          debugPrint(
            'Mapa do cenário ${cenario.idCenario} excede o limite de envio.',
          );
          continue;
        }
        usado += tamanho;
        imagens[cenario.idCenario] = imagem;
      } on Object catch (error) {
        debugPrint(
          'Não foi possível capturar o mapa do cenário ${cenario.idCenario}: '
          '$error',
        );
      }
    }
    return imagens;
  }
}
