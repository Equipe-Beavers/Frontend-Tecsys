import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/auth_user.dart';

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  @override
  String toString() => message;
}

class AuthLoginResult {
  const AuthLoginResult({required this.user, required this.token});
  final AuthUser user;
  final String token;
}

/// The secret/hash and password confirmation never belong in the API payload.
class AuthService {
  AuthService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = ApiConfig.resolve(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  Future<AuthUser> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final body = await _request(
      'POST',
      '/auth/register',
      expected: 201,
      payload: {
        'username': username.trim(),
        'email': email.trim().toLowerCase(),
        'senha': password,
      },
    );
    return _user(body['data']);
  }

  Future<AuthLoginResult> login({
    required String email,
    required String password,
  }) async {
    final body = await _request(
      'POST',
      '/auth/login',
      expected: 200,
      payload: {'email': email.trim().toLowerCase(), 'senha': password},
    );
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw const AuthApiException(
        'O servidor retornou uma resposta inesperada. Tente novamente.',
      );
    }
    return AuthLoginResult(user: _user(body['usuario']), token: token);
  }

  Future<AuthUser> me(String token) async => _user(
    (await _request('GET', '/auth/me', expected: 200, token: token))['usuario'],
  );

  Future<void> logout(String token) async {
    await _request('POST', '/auth/logout', expected: 204, token: token);
  }

  AuthUser _user(dynamic value) {
    try {
      return AuthUser.fromJson(Map<String, dynamic>.from(value as Map));
    } catch (_) {
      throw const AuthApiException(
        'O servidor retornou uma resposta inesperada. Tente novamente.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    required int expected,
    Map<String, dynamic>? payload,
    String? token,
  }) async {
    try {
      final headers = {
        'Accept': 'application/json',
        if (payload != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final uri = Uri.parse('$_baseUrl$path');
      final response =
          await (method == 'GET'
                  ? _client.get(uri, headers: headers)
                  : _client.post(
                      uri,
                      headers: headers,
                      body: payload == null ? null : jsonEncode(payload),
                    ))
              .timeout(const Duration(seconds: 15));
      Map<String, dynamic> body = {};
      try {
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map) body = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        /* Translate non-JSON errors without exposing server details. */
      }
      if (response.statusCode != expected) {
        final code = body['code']?.toString();
        final message = switch (response.statusCode) {
          400 => 'Confira os dados informados e tente novamente.',
          401 =>
            path == '/auth/login'
                ? 'E-mail ou senha inválidos.'
                : 'Sua sessão expirou. Entre novamente.',
          409 =>
            code == 'USERNAME_ALREADY_EXISTS'
                ? 'Nome de usuário já cadastrado.'
                : 'E-mail já cadastrado.',
          429 => 'Muitas tentativas. Aguarde alguns minutos e tente novamente.',
          _ =>
            'Não foi possível concluir a operação. Tente novamente mais tarde.',
        };
        throw AuthApiException(
          message,
          status: response.statusCode,
          code: code,
        );
      }
      return body;
    } on AuthApiException {
      rethrow;
    } on TimeoutException {
      throw const AuthApiException(
        'O servidor demorou para responder. Tente novamente.',
      );
    } on http.ClientException {
      throw const AuthApiException(
        'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
      );
    }
  }

  void dispose() => _client.close();
}
