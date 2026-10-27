import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../models/mancha_cenario.dart';
import '../../models/recomendacao_resultado.dart';
import '../../theme/app_colors.dart';
import 'recommendation_map_viewport.dart';

class ResponsiveRecommendationMap extends StatefulWidget {
  const ResponsiveRecommendationMap({
    super.key,
    required this.gateways,
    required this.assets,
    required this.scenarioCoverage,
    required this.viewport,
    required this.showBaseMap,
    required this.lockPosition,
    this.selectedGateway,
    this.onGatewayTap,
  });

  final List<GatewayProposto> gateways;
  final List<AtivoResultadoMapa> assets;
  final List<ManchaGatewayCenario> scenarioCoverage;
  final RecommendationMapViewport? viewport;
  final GatewayProposto? selectedGateway;
  final ValueChanged<GatewayProposto>? onGatewayTap;
  final bool showBaseMap;
  final bool lockPosition;

  @override
  State<ResponsiveRecommendationMap> createState() =>
      _ResponsiveRecommendationMapState();
}

class _ResponsiveRecommendationMapState
    extends State<ResponsiveRecommendationMap> {
  static const _scenarioSource = 'recommendation-scenario-source';
  static const _scenarioFillLayer = 'recommendation-scenario-fill';
  static const _scenarioLineLayer = 'recommendation-scenario-line';
  static const _coveredAssetsSource = 'recommendation-covered-assets-source';
  static const _coveredAssetsLayer = 'recommendation-covered-assets';
  static const _uncoveredAssetsSource =
      'recommendation-uncovered-assets-source';
  static const _uncoveredAssetsLayer = 'recommendation-uncovered-assets';
  static const _gatewaysSource = 'recommendation-gateways-source';
  static const _gatewayGlowLayer = 'recommendation-gateways-glow';
  static const _gatewayLayer = 'recommendation-gateways';

  MapboxMap? _map;
  bool _styleReady = false;
  bool _resizeNudge = false;
  bool _resizeNudgeScheduled = false;
  Size _size = Size.zero;
  String? _lastViewportSignature;
  double _minimumZoom = recommendationMinimumAllowedZoom;
  late final CameraViewportState _initialViewport;
  bool _constrainingCenter = false;

  @override
  void initState() {
    super.initState();
    final center = _centerGateway;
    _initialViewport = CameraViewportState(
      center: Point(
        coordinates: Position(
          center?.longitude ?? -45.88,
          center?.latitude ?? -23.2,
        ),
      ),
      zoom: 12.5,
    );
  }

  bool get _isWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  GatewayProposto? get _centerGateway =>
      widget.selectedGateway ?? widget.gateways.firstOrNull;

  @override
  void didUpdateWidget(covariant ResponsiveRecommendationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_styleReady) return;
    if (oldWidget.gateways != widget.gateways ||
        oldWidget.assets != widget.assets ||
        oldWidget.scenarioCoverage != widget.scenarioCoverage ||
        oldWidget.selectedGateway != widget.selectedGateway) {
      unawaited(_updateMapData());
      unawaited(_fitCamera(force: true));
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _styleReady = false;
    _lastViewportSignature = null;
    await Future.wait([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.gestures.updateSettings(
        GesturesSettings(
          rotateEnabled: false,
          pitchEnabled: false,
          scrollEnabled: true,
          scrollZoomEnabled: !kIsWeb,
          simultaneousRotateAndPinchToZoomEnabled: false,
          pitchWithRotateEnabled: false,
        ),
      ),
    ]);
    map.addInteraction(
      TapInteraction.onMap((context) {
        unawaited(_handleMapTap(context));
      }),
      interactionID: 'recommendation-gateway-tap',
    );
    _scheduleWebResizeNudge(map);
  }

  void _scheduleWebResizeNudge(MapboxMap map) {
    if (!kIsWeb || _resizeNudgeScheduled) return;
    _resizeNudgeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _map != map) return;
      setState(() => _resizeNudge = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _map != map) return;
        setState(() => _resizeNudge = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _map == map) unawaited(_fitCamera(force: true));
        });
      });
    });
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    try {
      await _addSourcesAndLayers(map);
      _styleReady = true;
      await _updateMapData();
      await _fitCamera(force: true);
    } catch (error, stackTrace) {
      debugPrint('Falha ao configurar o mapa de recomendação: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _onMapLoaded(MapLoadedEventData _) async {
    // On web, Mapbox can finish loading the style before its canvas reaches
    // the final size imposed by the result/detail layout. Refit on the next
    // frame so backend coverage is not cropped by that provisional size.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await _fitCamera(force: true);
  }

  Future<void> _addSourcesAndLayers(MapboxMap map) async {
    await map.addSource(
      GeoJsonSource(id: _scenarioSource, data: _scenarioGeoJson()),
    );
    await map.addLayer(
      FillLayer(
        id: _scenarioFillLayer,
        sourceId: _scenarioSource,
        slot: 'top',
        fillColor: AppColors.secondaryTeal.toARGB32(),
        fillOpacity: .18,
      ),
    );
    await map.addLayer(
      LineLayer(
        id: _scenarioLineLayer,
        sourceId: _scenarioSource,
        slot: 'top',
        lineColor: AppColors.secondaryTeal.toARGB32(),
        lineOpacity: .85,
        lineWidth: 1.6,
      ),
    );

    await _addAssetLayer(
      map,
      sourceId: _coveredAssetsSource,
      layerId: _coveredAssetsLayer,
      covered: true,
      color: AppColors.secondaryTeal,
    );
    await _addAssetLayer(
      map,
      sourceId: _uncoveredAssetsSource,
      layerId: _uncoveredAssetsLayer,
      covered: false,
      color: AppColors.layerChaveFusivel,
    );

    await map.addSource(
      GeoJsonSource(id: _gatewaysSource, data: _gatewaysGeoJson()),
    );
    await map.addLayer(
      CircleLayer(
        id: _gatewayGlowLayer,
        sourceId: _gatewaysSource,
        slot: 'top',
        circleRadius: widget.selectedGateway == null ? 13 : 15,
        circleColor: AppColors.primaryLime.toARGB32(),
        circleOpacity: .28,
        circleBlur: .65,
      ),
    );
    await map.addLayer(
      CircleLayer(
        id: _gatewayLayer,
        sourceId: _gatewaysSource,
        slot: 'top',
        circleRadius: widget.selectedGateway == null ? 8 : 10,
        circleColor: AppColors.primaryLime.toARGB32(),
        circleStrokeColor: AppColors.textWhite.toARGB32(),
        circleStrokeWidth: 2,
      ),
    );
  }

  Future<void> _addAssetLayer(
    MapboxMap map, {
    required String sourceId,
    required String layerId,
    required bool covered,
    required Color color,
  }) async {
    await map.addSource(
      GeoJsonSource(id: sourceId, data: _assetsGeoJson(covered)),
    );
    await map.addLayer(
      CircleLayer(
        id: layerId,
        sourceId: sourceId,
        slot: 'top',
        circleRadius: 5,
        circleColor: color.toARGB32(),
        circleStrokeColor: AppColors.surfaceBackground.toARGB32(),
        circleStrokeOpacity: .7,
        circleStrokeWidth: 1.2,
      ),
    );
  }

  Future<void> _updateMapData() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    await Future.wait([
      _updateSource(map, _scenarioSource, _scenarioGeoJson()),
      _updateSource(map, _coveredAssetsSource, _assetsGeoJson(true)),
      _updateSource(map, _uncoveredAssetsSource, _assetsGeoJson(false)),
      _updateSource(map, _gatewaysSource, _gatewaysGeoJson()),
    ]);
  }

  Future<void> _updateSource(
    MapboxMap map,
    String sourceId,
    String data,
  ) async {
    final source = await map.getSource(sourceId);
    if (source is GeoJsonSource) await source.updateGeoJSON(data);
  }

  Future<void> _handleMapTap(MapContentGestureContext context) async {
    final map = _map;
    final callback = widget.onGatewayTap;
    if (map == null || callback == null) return;
    final features = await map.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(context.touchPosition),
      RenderedQueryOptions(layerIds: const [_gatewayLayer], filter: null),
    );
    if (features.isEmpty) return;
    final properties = features.first?.queriedFeature.feature['properties'];
    if (properties is! Map) return;
    final id = int.tryParse(properties['gatewayId']?.toString() ?? '');
    if (id == null) return;
    final gateway = widget.gateways
        .where((item) => item.idEstudoPonto == id)
        .firstOrNull;
    if (gateway != null) callback(gateway);
  }

  Future<void> _fitCamera({bool force = false}) async {
    final map = _map;
    final viewport = widget.viewport;
    if (map == null || viewport == null || _size.isEmpty) return;
    final signature =
        '${_size.width}x${_size.height}:'
        '${viewport.displayBounds.north}:${viewport.displayBounds.south}:'
        '${viewport.displayBounds.east}:${viewport.displayBounds.west}';
    if (!force && signature == _lastViewportSignature) return;
    _lastViewportSignature = signature;

    // Geographic camera bounds can force the native SDK to zoom back in.
    // Constrain the center separately so the fitted coverage can stay visible.
    await map.setBounds(
      CameraBoundsOptions(
        minZoom: recommendationMinimumAllowedZoom,
        maxZoom: recommendationMaximumZoom,
      ),
    );

    final horizontalPadding = (_size.width * .07).clamp(24.0, 72.0);
    final verticalPadding = (_size.height * .07).clamp(24.0, 64.0);
    final camera = await map.cameraForCoordinateBounds(
      viewport.displayBounds.toMapboxBounds(),
      MbxEdgeInsets(
        top: verticalPadding,
        left: horizontalPadding,
        bottom: verticalPadding,
        right: horizontalPadding,
      ),
      0,
      0,
      13.4,
      null,
    );
    final fittedZoom =
        ((camera.zoom ?? 12.5) -
                recommendationCameraSafetyZoomOut(
                  _size.width,
                  focused: widget.selectedGateway != null,
                ))
            .clamp(recommendationMinimumAllowedZoom, recommendationMaximumZoom);
    camera.zoom = fittedZoom;
    await map.setCamera(camera);
    final minimumZoom = recommendationMinimumZoom(fittedZoom);
    _minimumZoom = minimumZoom;
    await map.setBounds(
      CameraBoundsOptions(
        minZoom: minimumZoom,
        maxZoom: recommendationMaximumZoom,
      ),
    );
  }

  Future<void> _constrainCenter() async {
    final map = _map;
    final bounds = widget.viewport?.coverageBounds;
    if (map == null || bounds == null || !_styleReady || _constrainingCenter) {
      return;
    }
    _constrainingCenter = true;
    try {
      final camera = await map.getCameraState();
      final position = camera.center.coordinates;
      final latitude = position.lat.toDouble().clamp(
        bounds.south,
        bounds.north,
      );
      final longitude = position.lng.toDouble().clamp(bounds.west, bounds.east);
      if ((latitude - position.lat).abs() > .000001 ||
          (longitude - position.lng).abs() > .000001) {
        await map.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(longitude, latitude)),
          ),
        );
      }
    } finally {
      _constrainingCenter = false;
    }
  }

  DateTime _lastScrollTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _handlePointerScroll(PointerScrollEvent event) async {
    final map = _map;
    if (map == null) return;
    final now = DateTime.now();
    if (now.difference(_lastScrollTime).inMilliseconds < 60) return;
    _lastScrollTime = now;

    try {
      final camera = await map.getCameraState();
      final currentZoom = camera.zoom;
      final delta = event.scrollDelta.dy < 0 ? 0.65 : -0.65;
      final targetZoom = (currentZoom + delta).clamp(
        _minimumZoom,
        recommendationMaximumZoom,
      );
      await map.flyTo(
        CameraOptions(zoom: targetZoom),
        MapAnimationOptions(duration: 150),
      );
    } catch (_) {}
  }

  Future<void> _zoomIn() async {
    final map = _map;
    if (map == null) return;
    try {
      final camera = await map.getCameraState();
      final nextZoom = (camera.zoom + 1.0).clamp(
        _minimumZoom,
        recommendationMaximumZoom,
      );
      await map.flyTo(
        CameraOptions(zoom: nextZoom),
        MapAnimationOptions(duration: 250),
      );
    } catch (_) {}
  }

  Future<void> _zoomOut() async {
    final map = _map;
    if (map == null) return;
    try {
      final camera = await map.getCameraState();
      final nextZoom = (camera.zoom - 1.0).clamp(
        _minimumZoom,
        recommendationMaximumZoom,
      );
      await map.flyTo(
        CameraOptions(zoom: nextZoom),
        MapAnimationOptions(duration: 250),
      );
    } catch (_) {}
  }

  String _scenarioGeoJson() => _featureCollection([
    for (var index = 0; index < widget.scenarioCoverage.length; index++)
      if (widget.scenarioCoverage[index].mancha.length >= 3)
        _polygonFeature(
          id: index,
          points: widget.scenarioCoverage[index].mancha,
          properties: {
            'gatewayId': widget.scenarioCoverage[index].idEstudoPonto,
          },
        ),
  ]);

  String _assetsGeoJson(bool covered) => _featureCollection([
    for (final asset in widget.assets)
      if (asset.coberto == covered)
        _pointFeature(
          id: asset.idEstudoPonto,
          latitude: asset.latitude,
          longitude: asset.longitude,
          properties: {'assetId': asset.idEstudoPonto},
        ),
  ]);

  String _gatewaysGeoJson() => _featureCollection([
    for (final gateway in widget.gateways)
      _pointFeature(
        id: gateway.idEstudoPonto,
        latitude: gateway.latitude,
        longitude: gateway.longitude,
        properties: {'gatewayId': gateway.idEstudoPonto},
      ),
  ]);

  Map<String, dynamic> _pointFeature({
    required int id,
    required double latitude,
    required double longitude,
    required Map<String, dynamic> properties,
  }) => {
    'type': 'Feature',
    'id': id,
    'properties': properties,
    'geometry': {
      'type': 'Point',
      'coordinates': [longitude, latitude],
    },
  };

  Map<String, dynamic> _polygonFeature({
    required int id,
    required List<LatLng> points,
    required Map<String, dynamic> properties,
  }) {
    final coordinates = [
      for (final point in points) [point.longitude, point.latitude],
    ];
    if (coordinates.isNotEmpty) {
      coordinates.add(List<double>.from(coordinates.first));
    }
    return {
      'type': 'Feature',
      'id': id,
      'properties': properties,
      'geometry': {
        'type': 'Polygon',
        'coordinates': [coordinates],
      },
    };
  }

  String _featureCollection(List<Map<String, dynamic>> features) =>
      jsonEncode({'type': 'FeatureCollection', 'features': features});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final nextSize = Size(constraints.maxWidth, constraints.maxHeight);
      if (nextSize != _size) {
        _size = nextSize;
        if (_styleReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_fitCamera());
          });
        }
      }

      if (_isWidgetTest) return _buildTestSurface();
      return Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                right: _resizeNudge ? 1 : 0,
                bottom: _resizeNudge ? 1 : 0,
              ),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerSignal: kIsWeb
                    ? (event) {
                        if (event is PointerScrollEvent) {
                          unawaited(_handlePointerScroll(event));
                        }
                      }
                    : null,
                child: MapWidget(
                  key: const ValueKey('recommendation-mapbox-map'),
                  styleUri: MapboxStyles.STANDARD,
                  viewport: _initialViewport,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      EagerGestureRecognizer.new,
                    ),
                  },
                  onMapIdleListener: (_) => unawaited(_constrainCenter()),
                  onMapCreated: _onMapCreated,
                  onStyleLoadedListener: _onStyleLoaded,
                  onMapLoadedListener: _onMapLoaded,
                ),
              ),
            ),
          ),
          if (constraints.maxWidth >= 600)
            Positioned(
              key: const ValueKey('recommendation-zoom-controls'),
              right: 14,
              bottom: 38,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceBackground.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _zoomIn,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.add,
                          color: AppColors.textWhite,
                          size: 20,
                        ),
                      ),
                    ),
                    Container(height: 1, width: 28, color: Colors.white12),
                    InkWell(
                      onTap: _zoomOut,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.remove,
                          color: AppColors.textWhite,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _buildTestSurface() => ColoredBox(
    key: const ValueKey('recommendation-mapbox-test-surface'),
    color: widget.showBaseMap
        ? const Color(0xFFE6E6E6)
        : AppColors.surfaceBackground,
    child: Stack(
      children: [
        for (var index = 0; index < widget.scenarioCoverage.length; index++)
          if (widget.scenarioCoverage[index].mancha.length >= 3)
            SizedBox(key: ValueKey('scenario-coverage-layer-$index')),
        for (final asset in widget.assets)
          SizedBox(
            key: ValueKey(
              '${asset.coberto ? 'covered' : 'uncovered'}-asset-${asset.idEstudoPonto}',
            ),
          ),
        for (final gateway in widget.gateways)
          Semantics(
            button: widget.onGatewayTap != null,
            label: 'Abrir detalhes de ${gateway.rotulo ?? 'gateway'}',
            child: GestureDetector(
              key: ValueKey('gateway-${gateway.idEstudoPonto}'),
              onTap: widget.onGatewayTap == null
                  ? null
                  : () => widget.onGatewayTap!(gateway),
              child: const SizedBox(width: 42, height: 42),
            ),
          ),
      ],
    ),
  );
}
