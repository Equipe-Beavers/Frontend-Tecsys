import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';

/// Session shared during navigation. No password or token is written to disk.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? service})
    : service = service ?? AuthService(),
      _ownsService = service == null;

  final AuthService service;
  final bool _ownsService;
  AuthUser? _user;
  String? _token;
  bool _disposed = false;
  int _revision = 0;
  AuthUser? get user => _user;
  String? get accessToken => _token;

  Future<void> login({required String email, required String password}) async {
    final revision = ++_revision;
    final result = await service.login(email: email, password: password);
    if (_disposed || revision != _revision) return;
    _user = result.user;
    _token = result.token;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final token = _token;
    if (token == null) return;
    try {
      final user = await service.me(token);
      if (_disposed || _token != token) return;
      _user = user;
      notifyListeners();
    } on AuthApiException catch (error) {
      if (!_disposed && _token == token && error.status == 401) _clear();
      rethrow;
    }
  }

  Future<void> logout() async {
    final token = _token;
    if (token == null) return;
    try {
      await service.logout(token);
    } on AuthApiException catch (error) {
      // An already expired/revoked session is also safely signed out locally.
      if (error.status != 401) rethrow;
    }
    if (!_disposed && _token == token) _clear();
  }

  void _clear() {
    _revision++;
    _user = null;
    _token = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    if (_ownsService) service.dispose();
    super.dispose();
  }
}
