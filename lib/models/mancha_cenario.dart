import 'package:latlong2/latlong.dart';
import 'package:frontend_tecsys/utils/geojson_utils.dart';

class ManchaGatewayCenario {
  final int idEstudoPonto;
  final String? rotulo;
  final LatLng posicao;
  final int? alcanceMedioM;
  final List<LatLng> mancha;

  const ManchaGatewayCenario({
    required this.idEstudoPonto,
    required this.rotulo,
    required this.posicao,
    required this.alcanceMedioM,
    required this.mancha,
  });

  factory ManchaGatewayCenario.fromJson(Map<String, dynamic> json) {
    final aneis = aneisExternosGeoJson(json['mancha_cobertura']);
    return ManchaGatewayCenario(
      idEstudoPonto: (json['id_estudo_ponto'] as num).toInt(),
      rotulo: json['rotulo']?.toString(),
      posicao: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      alcanceMedioM: (json['alcance_medio_m'] as num?)?.toInt(),
      mancha: aneis.isEmpty ? <LatLng>[] : aneis.first,
    );
  }
}

class ManchaCenario {
  final List<List<LatLng>> manchaConsolidada;
  final List<ManchaGatewayCenario> gateways;

  const ManchaCenario({
    required this.manchaConsolidada,
    required this.gateways,
  });

  bool get vazia => gateways.every((gateway) => gateway.mancha.length < 3);

  factory ManchaCenario.fromJson(Map<String, dynamic> json) {
    return ManchaCenario(
      manchaConsolidada: aneisExternosGeoJson(json['mancha_consolidada']),
      gateways: (json['gateways'] as List? ?? [])
          .map(
            (gateway) => ManchaGatewayCenario.fromJson(
              Map<String, dynamic>.from(gateway as Map),
            ),
          )
          .toList(),
    );
  }
}
