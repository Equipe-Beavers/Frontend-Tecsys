import 'dart:async';

import 'package:flutter/foundation.dart';

class MapSnapshotController {
  Future<Uint8List> Function()? _capture;
  final _pronto = Completer<void>();

  bool get isAttached => _capture != null;

  bool get isReady => _pronto.isCompleted;

  void attach(Future<Uint8List> Function() capture) => _capture = capture;

  void detach(Future<Uint8List> Function() capture) {
    // `==` e não `identical`: cada tear-off de método (`_snapshot`) cria um
    // objeto novo, então `identical` nunca batia e o mapa descartado ficava
    // preso ao controller.
    if (_capture == capture) _capture = null;
  }

  void markReady() {
    if (!_pronto.isCompleted) _pronto.complete();
  }

  Future<bool> waitUntilReady({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      await _pronto.future.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<Uint8List?> capture({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final capture = _capture;
    if (capture == null) return null;
    try {
      final bytes = await capture().timeout(timeout);
      return bytes.isEmpty ? null : bytes;
    } on Object catch (error) {
      debugPrint('Não foi possível capturar o mapa: $error');
      return null;
    }
  }
}
