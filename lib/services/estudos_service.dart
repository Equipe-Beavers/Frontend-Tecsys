import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/novo_estudo.dart';

class EstudosService {
  EstudosService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:3000',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> criarEstudo(NovoEstudo estudo) async {
    final resposta = await _client
        .post(
          Uri.parse('$_baseUrl/estudos'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(estudo.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    final corpo = resposta.body.isEmpty ? null : jsonDecode(resposta.body);

    if (resposta.statusCode != 201) {
      final mensagem = corpo is Map && corpo['erro'] != null
          ? corpo['erro'].toString()
          : 'A API de estudos respondeu com HTTP ${resposta.statusCode}.';
      throw StateError(mensagem);
    }
    if (corpo is! Map || corpo['estudo'] is! Map) {
      throw const FormatException('Resposta de criação de estudo inválida.');
    }
    return Map<String, dynamic>.from(corpo['estudo'] as Map);
  }
}
