import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

typedef RecommendationMapOptionsBuilder = MapOptions Function(Size size);

class ResponsiveRecommendationMap extends StatefulWidget {
  const ResponsiveRecommendationMap({
    super.key,
    required this.optionsBuilder,
    required this.layers,
    required this.showBaseMap,
  });

  final RecommendationMapOptionsBuilder optionsBuilder;
  final List<Widget> layers;
  final bool showBaseMap;

  @override
  State<ResponsiveRecommendationMap> createState() =>
      _ResponsiveRecommendationMapState();
}

class _ResponsiveRecommendationMapState
    extends State<ResponsiveRecommendationMap> {
  final MapController _mapController = MapController();
  (Size, double, double, double, double)? _lastViewport;
  int _refitGeneration = 0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _scheduleCameraRefit(Size size, MapOptions options) {
    final fit = options.initialCameraFit;
    if (size.isEmpty || fit is! FitBounds) return;

    final bounds = fit.bounds;
    final viewport = (
      size,
      bounds.north,
      bounds.south,
      bounds.east,
      bounds.west,
    );
    final previousViewport = _lastViewport;
    _lastViewport = viewport;
    if (previousViewport == null || previousViewport == viewport) return;

    final generation = ++_refitGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _refitGeneration) return;
      _mapController.fitCamera(fit);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final options = widget.optionsBuilder(size);
      _scheduleCameraRefit(size, options);

      return FlutterMap(
        mapController: _mapController,
        options: options,
        children: [
          if (widget.showBaseMap)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.frontend_tecsys',
              panBuffer: 0,
              tileDisplay: const TileDisplay.instantaneous(),
            ),
          ...widget.layers,
        ],
      );
    },
  );
}
