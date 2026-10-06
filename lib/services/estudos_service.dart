import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/models/estudo.dart';
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

  String _mensagemErro(http.Response resposta) {
    final corpo = resposta.body.isEmpty ? null : jsonDecode(resposta.body);
    return corpo is Map && corpo['erro'] != null
        ? corpo['erro'].toString()
        : 'A API de estudos respondeu com HTTP ${resposta.statusCode}.';
  }

  Future<List<EstudoResumo>> listarEstudos() async {
    final resposta = await _client
        .get(Uri.parse('$_baseUrl/estudos'))
        .timeout(const Duration(seconds: 15));
    if (resposta.statusCode != 200) throw StateError(_mensagemErro(resposta));

    final corpo = jsonDecode(resposta.body);
    if (corpo is! Map || corpo['estudos'] is! List) {
      throw const FormatException('Listagem de estudos inválida.');
    }
    final estudos = (corpo['estudos'] as List)
        .map((e) => EstudoResumo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    estudos.sort(
      (a, b) =>
          (b.criadoEm ?? DateTime(0)).compareTo(a.criadoEm ?? DateTime(0)),
    );
    return estudos;
  }

  Future<void> atualizarEstudo(int id, NovoEstudo estudo) async {
    final dados = estudo.toJson()
      ..remove('id_usuario')
      ..remove('status')
      ..remove('tipos_ativo_selecionados')
      ..remove('versao_bdgd')
      ..remove('nome_base_externa');
    if (estudo.pontosArea.isEmpty) dados.remove('geom');
    final resposta = await _client
        .patch(
          Uri.parse('$_baseUrl/estudos/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(dados),
        )
        .timeout(const Duration(seconds: 15));
    if (resposta.statusCode != 200) throw StateError(_mensagemErro(resposta));
  }

  Future<void> excluirEstudo(int id) async {
    final resposta = await _client
        .delete(Uri.parse('$_baseUrl/estudos/$id'))
        .timeout(const Duration(seconds: 15));
    if (resposta.statusCode != 200) throw StateError(_mensagemErro(resposta));
  }

  void dispose() => _client.close();
}
