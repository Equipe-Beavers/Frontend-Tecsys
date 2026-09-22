import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/appbar.dart';
import 'package:frontend_tecsys/widgets/map_navigation.dart';
import 'package:frontend_tecsys/widgets/navbar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend_tecsys/widgets/search_bar.dart';
import 'package:frontend_tecsys/utils/map_utils.dart';
import 'package:latlong2/latlong.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => HomePage();
}

class HomePage extends State<MyApp> {
  final MapController _mapController = MapController();
  double _currentZoom = 3.8;
  bool isDrawing = false;
  List<LatLng> polygonPoints = [];

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_mapController.camera.zoom + 1).clamp(2.0, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_mapController.camera.zoom - 1).clamp(2.0, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _onLocationPressed() {
    print("Localização apertada");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(20),
          child: AppBarTime(),
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(-14.2350, -51.9253),
                initialZoom: _currentZoom,
                minZoom: 2.0,
                maxZoom: 18.0,
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    LatLng(-89.9, -180.0),
                    LatLng(89.9, 180.0),
                  ),
                ),
                onTap: (tapPosition, point) {
                  if (!isDrawing) return;
                  setState(() {
                    polygonPoints.add(point);
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.frontend_tecsys',
                ),
                PolygonLayer(
                  polygons: polygonPoints.length >= 3
                      ? <Polygon<Object>>[
                          Polygon<Object>(
                            points: polygonPoints,
                            color: AppColors.navBarBackground.withAlpha(100),
                            borderColor: AppColors.navBarBackground,
                            borderStrokeWidth: 2.5,
                            pattern: StrokePattern.dashed(segments: [10, 5]),
                          ),
                        ]
                      : <Polygon<Object>>[],
                ),
                MarkerLayer(
                  markers: polygonPoints.map((point) {
                    return Marker(
                      point: point,
                      width: 14.0,
                      height: 14.0,
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.navBarBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.navBarBackground,
                            width: 2.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            Positioned(
              top: 10,
              left: 15,
              right: 15,
              child: Column(
                spacing: 10,
                children: [
                  Center(
                    child: Row(
                      spacing: 20,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: MapSearchBar()),
                        IconButton(
                          onPressed: () => "Olá mundo",
                          icon: Icon(
                            Icons.layers_outlined,
                            color: AppColors.textPrimaryColor,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.searchBarFieldsBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            fixedSize: const Size(50, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    spacing: 5,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            isDrawing = !isDrawing;
                          });
                        },
                        icon: Icon(Icons.draw, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.backgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      if (isDrawing)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              polygonPoints.clear();
                            });
                          },
                          icon: Icon(Icons.delete, color: Colors.black),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      if (polygonPoints.length >= 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navBarBackground,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.square_foot,
                                color: AppColors.textPrimaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Área desenhada: ${calculatePolygonAreaKm2(polygonPoints).toStringAsFixed(2)} km²',
                                style: TextStyle(
                                  color: AppColors.textPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MapNavigationControls(
                      onZoomIn: _zoomIn,
                      onZoomOut: _zoomOut,
                      onLocationPressed: _onLocationPressed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Navbar(),
      ),
    );
  }
}
