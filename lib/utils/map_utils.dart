import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

double calculatePolygonAreaKm2(List<LatLng> points) {
  if (points.length < 3) return 0.0;

  const double earthRadiusMeters = 6371000.0;
  double areaMeters = 0.0;
  double meanLat = 0.0;

  for (var p in points) {
    meanLat += p.latitude;
  }
  meanLat = (meanLat / points.length) * math.pi / 180.0;
  List<math.Point<double>> projectedPoints = [];
  for (var p in points) {
    double x = p.longitude * math.pi / 180.0 * earthRadiusMeters * math.cos(meanLat);
    double y = p.latitude * math.pi / 180.0 * earthRadiusMeters;
    projectedPoints.add(math.Point(x, y));
  }

  for (int i = 0; i < projectedPoints.length; i++) {
    final p1 = projectedPoints[i];
    final p2 = projectedPoints[(i + 1) % projectedPoints.length];
    areaMeters += (p1.x * p2.y) - (p2.x * p1.y);
  }
  areaMeters = (areaMeters.abs()) / 2.0;

  return areaMeters / 1000000.0;
}