import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/config/api_config.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';

class PerfilRfService {
  PerfilRfService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<List<PerfilRf>> getPerfis() async {
    final resposta = await _client
        .get(Uri.parse('$_baseUrl/perfis-rf'))
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 200) {
      throw StateError(
        'A API de perfis RF respondeu com HTTP ${resposta.statusCode}.',
      );
    }

    final corpo = jsonDecode(resposta.body);

    if (corpo is! Map || corpo['perfis'] is! List) {
      throw const FormatException('Resposta da listagem de perfis RF inválida.');
    }

    return (corpo['perfis'] as List)
        .map((item) => PerfilRf.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  void dispose() => _client.close();
}
