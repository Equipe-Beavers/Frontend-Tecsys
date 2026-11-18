import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/session_store.dart';

import '../models/auth_user.dart';
import '../models/auth_operation.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthService? service, SessionStore? store})
    : service = service ?? AuthService(),
      _store = store ?? MemorySessionStore(),
      _ownsService = service == null;

  final AuthService service;
  final Map<Object, AuthOperation> _operations = {};
  AuthOperation? get operation =>
      _operations.isEmpty ? null : _operations.values.last;

  Future<T> _during<T>(
    AuthOperation operation,
    Future<T> Function() action,
  ) async {
    if (_disposed) throw StateError('AuthController disposed');
    final ticket = Object();
    _operations[ticket] = operation;
    notifyListeners();
    try {
      return await action();
    } finally {
      _operations.remove(ticket);
      if (!_disposed) notifyListeners();
    }
  }

  Future<AuthUser> register({
    required String username,
    required String email,
    required String password,
  }) => _during(
    AuthOperation.register,
    () =>
        service.register(username: username, email: email, password: password),
  );

  Future<void> requestPasswordReset(String email) => _during(
    AuthOperation.requestPasswordReset,
    () => service.requestPasswordReset(email),
  );

  Future<void> resetPassword({
    required String token,
    required String password,
  }) => _during(AuthOperation.resetPassword, () async {
    await service.resetPassword(token: token, password: password);
    final current = _token;
    if (current != null) {
      try {
        await invalidate(current);
      } catch (_) {
        /* Server revocation and local memory cleanup already succeeded. */
      }
    }
  });

  final bool _ownsService;
  final SessionStore _store;
  bool _restoring = false;
  bool get restoring => _restoring;
  String? restoreError;
  Timer? _expiry;
  Future<void> _storageQueue = Future.value();
  AuthUser? _user;
  String? _token;
  bool _disposed = false;
  int _revision = 0;
  AuthUser? get user => _user;
  String? get accessToken => _token;

  Future<void> _save(Future<void> Function() action) {
    final future = _storageQueue.then((_) => action());
    _storageQueue = future.catchError((Object _) {});
    return future;
  }

  Future<void> restore() async {
    if (_restoring || _disposed || _token != null) return;
    await _during(AuthOperation.restoreSession, _restore);
  }

  Future<void> _restore() async {
    if (_restoring || _disposed || _token != null) return;
    final revision = ++_revision;
    _restoring = true;
    restoreError = null;
    notifyListeners();
    try {
      final token = await _store.read();
      if (token == null) return;
      final user = await service.me(token);
      if (_disposed || revision != _revision) return;
      _user = user;
      _token = token;
      _scheduleExpiry(token);
    } on AuthApiException catch (error) {
      if (revision != _revision) return;
      if (error.status == 401) {
        await _save(_store.clear);
      } else {
        restoreError = error.message;
      }
    } catch (_) {
      if (revision == _revision) restoreError = 'Não foi possível restaurar sua sessão. Tente novamente ou entre na sua conta.';
    } finally {
      if (!_disposed && revision == _revision) {
        _restoring = false;
        notifyListeners();
      }
    }
  }

  Future<void> login({required String email, required String password}) =>
      _during(
        AuthOperation.login,
        () => _login(email: email, password: password),
      );

  Future<void> _login({required String email, required String password}) async {
    final revision = ++_revision;
    final result = await service.login(email: email, password: password);
    if (_disposed || revision != _revision) return;
    try {
      await _save(() => _store.write(result.token));
    } catch (_) {
      try {
        await service.logout(result.token);
      } catch (_) {
        /* Best-effort revocation. */
      }
      throw const AuthApiException(
        'Não foi possível armazenar sua sessão com segurança. Tente novamente.',
      );
    }
    if (_disposed || revision != _revision) return;
    _restoring = false;
    restoreError = null;
    _user = result.user;
    _token = result.token;
    _scheduleExpiry(result.token);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token == null) return;
    await _during(AuthOperation.restoreSession, _refreshUser);
  }

  Future<void> _refreshUser() async {
    final token = _token;
    if (token == null) return;
    try {
      final user = await service.me(token);
      if (_disposed || _token != token) return;
      _user = user;
      notifyListeners();
    } on AuthApiException catch (error) {
      if (error.status == 401) await invalidate(token);
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_token == null) return;
    await _during(AuthOperation.logout, _logout);
  }

  Future<void> _logout() async {
    final token = _token;
    if (token == null) return;
    try {
      await service.logout(token);
    } on AuthApiException catch (error) {
      // An already expired/revoked session is also safely signed out locally.
      if (error.status != 401) rethrow;
    }
    await invalidate(token);
  }

  Future<void> invalidate(String token) async {
    if (_disposed || _token != token) return;
    _revision++;
    _expiry?.cancel();
    _user = null;
    _token = null;
    notifyListeners();
    await _save(_store.clear);
  }

  void _scheduleExpiry(String token) {
    _expiry?.cancel();
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map;
      final expiry = payload['exp'];
      if (expiry is! num) return;
      final remaining = DateTime.fromMillisecondsSinceEpoch(
        (expiry * 1000).toInt(),
      ).difference(DateTime.now());
      _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        unawaited(invalidate(token).catchError((Object _) {}));
      });
    } catch (_) {
      /* The server remains authoritative for token validity. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    _revision++;
    if (_ownsService) service.dispose();
    super.dispose();
  }
}
