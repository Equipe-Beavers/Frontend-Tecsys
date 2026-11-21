import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

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

  void updateArea(List<LatLng> points, {String? distributor}) {
    if (_disposed) return;
    _timer?.cancel();
    final revision = ++_revision;
    final area = List<LatLng>.of(points);
    count = area.length < 3 ? 0 : null;
    error = null;
    loading = area.length >= 3;
    notifyListeners();
    if (!loading) return;
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

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    super.dispose();
  }
}
