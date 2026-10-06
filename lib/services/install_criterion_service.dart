import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/install_criterion.dart';

class InstallCriterionService {
  InstallCriterionService({http.Client? client, String? baseUrl})
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

  Future<InstallCriteriaPage> list({
    required int userId,
    int page = 1,
    int limit = 20,
  }) async {
    if (page < 1 || page > 21474836 || limit < 1 || limit > 100) {
      throw ArgumentError('Paginação inválida.');
    }
    final response = await _client
        .get(
          Uri.parse(
            '$_baseUrl/list-install-criteria?id_usuario=$userId&page=$page&limit=$limit',
          ),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decode(response, 200);
    final items = body['data'];
    if (items is! List) {
      throw const FormatException('Não foi possível ler a lista de critérios.');
    }
    return InstallCriteriaPage(
      items: List.unmodifiable(
        items.map(
          (item) =>
              InstallCriterion.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      page: page,
      limit: limit,
    );
  }

  Future<InstallCriterion> get(int id) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/get-install-criterion/$id'))
        .timeout(const Duration(seconds: 15));
    return InstallCriterion.fromJson(
      Map<String, dynamic>.from(_decode(response, 200)['data'] as Map),
    );
  }

  Future<void> save(Map<String, dynamic> values, {int? id}) async {
    final uri = Uri.parse(
      '$_baseUrl/${id == null ? 'create-install-criterion' : 'update-install-criterion/$id'}',
    );
    const headers = {'Content-Type': 'application/json'};
    final response =
        await (id == null
                ? _client.post(uri, headers: headers, body: jsonEncode(values))
                : _client.patch(
                    uri,
                    headers: headers,
                    body: jsonEncode(values),
                  ))
            .timeout(const Duration(seconds: 15));
    _decode(response, id == null ? 201 : 200);
  }

  Future<void> delete(int id) async {
    final response = await _client
        .delete(Uri.parse('$_baseUrl/delete-install-criterion/$id'))
        .timeout(const Duration(seconds: 15));
    _decode(response, 204);
  }

  Map<String, dynamic> _decode(http.Response response, int expected) {
    Map<String, dynamic> body = {};
    try {
      if (response.body.isNotEmpty) {
        body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
    } catch (_) {
      throw const FormatException(
        'O servidor retornou uma resposta inesperada.',
      );
    }
    if (response.statusCode != expected) {
      throw CriterionApiException(
        response.statusCode,
        body['message']?.toString() ??
            'Não foi possível concluir a operação. Tente novamente.',
      );
    }
    return body;
  }

  void dispose() => _client.close();
}

class CriterionApiException implements Exception {
  const CriterionApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class InstallCriteriaPage {
  const InstallCriteriaPage({
    required this.items,
    required this.page,
    required this.limit,
  });
  final List<InstallCriterion> items;
  final int page;
  final int limit;
  bool get hasNext => items.length == limit;
}
