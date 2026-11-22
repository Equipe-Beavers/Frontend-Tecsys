String formatStudyArea(double areaKm2) {
  if (areaKm2 >= 1) {
    return '${areaKm2.toStringAsFixed(1).replaceAll('.', ',')} km²';
  }
  final squareMeters = areaKm2 * 1000000;
  return '${squareMeters.toStringAsFixed(squareMeters > 0 && squareMeters < 1 ? 2 : 1).replaceAll('.', ',')} m²';
}
