import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/rf_profile.dart';

class RFProfileService {
  RFProfileService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? _defaultUrl).replaceFirst(RegExp(r'/+$'), '');

  static String get _defaultUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  final http.Client _client;
  final String _baseUrl;

  Future<RFProfilesPage> list({
    required int userId,
    int page = 1,
    int limit = 20,
  }) async {
    if (userId < 1 || page < 1 || page > 21474836 || limit < 1 || limit > 100) {
      throw ArgumentError('Parâmetros de listagem de perfis RF inválidos.');
    }
    final uri = Uri.parse('$_baseUrl/list-rf-profiles').replace(
      queryParameters: {
        'id_usuario': '$userId',
        'page': '$page',
        'limit': '$limit',
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw RFProfileApiException(
        response.statusCode,
        body['message']?.toString() ??
            'Não foi possível carregar os perfis RF.',
      );
    }
    final items = body['data'];
    if (items is! List) {
      throw const FormatException('Não foi possível ler a lista de perfis RF.');
    }
    return RFProfilesPage(
      items: List.unmodifiable(
        items.map(
          (item) => RFProfile.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      page: _readPositiveInt(body['page']) ?? page,
      limit: _readPositiveInt(body['limit']) ?? limit,
    );
  }

  Future<RFProfile> get(int id) async {
    if (id < 1) throw ArgumentError('Identificador de perfil RF inválido.');
    final response = await _client
        .get(Uri.parse('$_baseUrl/get-rf-profile/$id'))
        .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw RFProfileApiException(
        response.statusCode,
        body['message']?.toString() ?? 'Não foi possível abrir o perfil RF.',
      );
    }
    return RFProfile.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<RFProfile> save(Map<String, dynamic> values, {int? id}) async {
    final uri = Uri.parse(
      '$_baseUrl/${id == null ? 'create-rf-profile' : 'update-rf-profile/$id'}',
    );
    final headers = const {'Content-Type': 'application/json'};
    final response =
        await (id == null
                ? _client.post(uri, headers: headers, body: jsonEncode(values))
                : _client.patch(
                    uri,
                    headers: headers,
                    body: jsonEncode(values),
                  ))
            .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    final expectedStatus = id == null ? 201 : 200;
    if (response.statusCode != expectedStatus) {
      throw RFProfileApiException(
        response.statusCode,
        body['message']?.toString() ?? 'Não foi possível salvar o perfil RF.',
      );
    }
    return RFProfile.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<void> delete(int id) async {
    if (id < 1) throw ArgumentError('Identificador de perfil RF inválido.');
    final response = await _client
        .delete(Uri.parse('$_baseUrl/delete-rf-profile/$id'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 204) return;
    final body = _decode(response);
    throw RFProfileApiException(
      response.statusCode,
      body['message']?.toString() ?? 'Não foi possível excluir o perfil RF.',
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      if (response.body.isEmpty) return {};
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const FormatException(
        'O servidor retornou uma resposta inesperada.',
      );
    }
  }

  int? _readPositiveInt(Object? value) =>
      value is int && value > 0 ? value : null;

  void dispose() => _client.close();
}

class RFProfileApiException implements Exception {
  const RFProfileApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class RFProfilesPage {
  const RFProfilesPage({
    required this.items,
    required this.page,
    required this.limit,
  });
  final List<RFProfile> items;
  final int page;
  final int limit;
  bool get hasNext => items.length == limit;
}
