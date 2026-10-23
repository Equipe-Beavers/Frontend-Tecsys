import 'package:latlong2/latlong.dart';

/// Converte uma geometria GeoJSON (Polygon ou MultiPolygon) na lista de anéis externos.
List<List<LatLng>> aneisExternosGeoJson(Object? geometria) {
  if (geometria is! Map) return [];

  final tipo = geometria['type'];
  final coordenadas = geometria['coordinates'];
  if (coordenadas is! List) return [];

  List<LatLng> converterAnel(Object? anel) {
    if (anel is! List) return [];
    return anel.whereType<List>().where((ponto) => ponto.length >= 2).map((ponto) {
      return LatLng(
        (ponto[1] as num).toDouble(),
        (ponto[0] as num).toDouble(),
      );
    }).toList();
  }

  if (tipo == 'Polygon') {
    if (coordenadas.isEmpty) return [];
    final anel = converterAnel(coordenadas.first);
    return anel.length >= 3 ? [anel] : [];
  }

  if (tipo == 'MultiPolygon') {
    return coordenadas
        .whereType<List>()
        .where((poligono) => poligono.isNotEmpty)
        .map((poligono) => converterAnel(poligono.first))
        .where((anel) => anel.length >= 3)
        .toList();
  }

  return [];
}

/// Indica se o ponto está dentro do polígono (algoritmo do raio).
bool pontoDentroDoPoligono(LatLng ponto, List<LatLng> poligono) {
  var dentro = false;

  for (int i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
    final a = poligono[i];
    final b = poligono[j];
    final cruza = (a.latitude > ponto.latitude) != (b.latitude > ponto.latitude) &&
        ponto.longitude <
            (b.longitude - a.longitude) *
                    (ponto.latitude - a.latitude) /
                    (b.latitude - a.latitude) +
                a.longitude;
    if (cruza) dentro = !dentro;
  }

  return dentro;
}
