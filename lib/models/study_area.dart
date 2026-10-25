import 'package:latlong2/latlong.dart';

class StudyArea {
  const StudyArea({required this.areaKm2, required this.points});

  final double areaKm2;
  final List<LatLng> points;
}
