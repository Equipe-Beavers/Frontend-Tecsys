import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/widgets/appbar.dart';
import 'package:frontend_tecsys/widgets/navbar.dart';
import 'package:flutter_map/flutter_map.dart';
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
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.frontend_tecsys',
                ),
              ],
            ),
            // Positioned(
            //   top: 60,
            //   left: 16,
            //   right: 16,
            //   child: MapNavigationControls(onZoomIn: _zoomIn, onZoomOut: _zoomOut, onLocationPressed: _onLocationPressed),
            // ),
          ],
        ),
        bottomNavigationBar: Navbar(),
      ),
    );
  }
}
