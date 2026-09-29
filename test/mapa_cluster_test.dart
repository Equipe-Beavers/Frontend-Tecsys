import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('agrupa ativos em cluster e separa ao aproximar o zoom',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const centro = LatLng(-23.5505, -46.6333);
    final markers = [
      for (var i = 0; i < 200; i++)
        Marker(
          point: LatLng(
            centro.latitude + (i ~/ 20) * 0.0005,
            centro.longitude + (i % 20) * 0.0005,
          ),
          width: 32,
          height: 32,
          child: const SizedBox.shrink(),
        ),
    ];

    final controller = MapController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 10,
              minZoom: 2,
              maxZoom: 18,
            ),
            children: [
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: markers,
                  disableClusteringAtZoom: 16,
                  maxClusterRadius: 55,
                  builder: (context, marcadoresDoCluster) => Text(
                    '${marcadoresDoCluster.length}',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('200'), findsOneWidget);

    controller.move(centro, 17);
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('200'), findsNothing);
  });
}
