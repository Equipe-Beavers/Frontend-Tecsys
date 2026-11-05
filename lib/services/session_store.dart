import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Browser tokens remain in memory, never in localStorage/sessionStorage.
/// Native platforms use the OS credential vault.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'geomash.access_token';
  @override
  Future<String?> read() async => kIsWeb ? null : _storage.read(key: _key);
  @override
  Future<void> write(String token) async {
    if (!kIsWeb) await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() async {
    if (!kIsWeb) await _storage.delete(key: _key);
  }
}

class MemorySessionStore implements SessionStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
