import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/ativo_bdgd.dart';
import '../services/ativos_service.dart';

class StudyAreaCountController extends ChangeNotifier {
  StudyAreaCountController(this.service);
  final AtivosService service;
  int? count = 0;
  bool loading = false;
  String? error;
  Timer? _timer;
  int _revision = 0;
  bool _disposed = false;

  void updateArea(
    List<LatLng> points, {
    String? distributor,
    List<AtivoBdgd>? ativosImportados,
  }) {
    if (_disposed) return;
    _timer?.cancel();
    final revision = ++_revision;
    final area = List<LatLng>.of(points);
    count = area.length < 3 ? 0 : null;
    error = null;
    loading = area.length >= 3;
    notifyListeners();
    if (!loading) return;
    if (ativosImportados != null) {
      count = ativosImportados
          .where((ativo) => _pontoDentroDaArea(ativo, area))
          .length;
      loading = false;
      notifyListeners();
      return;
    }
    _timer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final total = await service.contarAtivosNaArea(
          area,
          distribuidora: distributor,
        );
        if (_disposed || revision != _revision) return;
        count = total;
      } catch (_) {
        if (_disposed || revision != _revision) return;
        error = 'Não foi possível contar os ativos. Tente novamente.';
      }
      loading = false;
      notifyListeners();
    });
  }

  bool _pontoDentroDaArea(AtivoBdgd ativo, List<LatLng> area) {
    var dentro = false;
    var anterior = area.length - 1;
    for (var atual = 0; atual < area.length; atual++) {
      final latitudeAtual = area[atual].latitude;
      final latitudeAnterior = area[anterior].latitude;
      final longitudeAtual = area[atual].longitude;
      final longitudeAnterior = area[anterior].longitude;
      if ((latitudeAtual > ativo.latitude) !=
              (latitudeAnterior > ativo.latitude) &&
          ativo.longitude <
              (longitudeAnterior - longitudeAtual) *
                      (ativo.latitude - latitudeAtual) /
                      (latitudeAnterior - latitudeAtual) +
                  longitudeAtual) {
        dentro = !dentro;
      }
      anterior = atual;
    }
    return dentro;
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    super.dispose();
  }
}
