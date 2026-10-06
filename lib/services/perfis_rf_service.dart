import 'dart:convert';

import 'package:frontend_tecsys/models/perfil_rf.dart';
import 'package:http/http.dart' as http;

class PerfisRfService {
  PerfisRfService({http.Client? cliente, String? baseUrl})
    : _cliente = cliente ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:3000',
          );

  final http.Client _cliente;
  final String _baseUrl;

  Future<Map<String, dynamic>> _requisitar(
    String metodo,
    String caminho, [
    Map<String, dynamic>? dados,
  ]) async {
    final requisicao = http.Request(metodo, Uri.parse('$_baseUrl$caminho'));
    requisicao.headers['Content-Type'] = 'application/json';
    if (dados != null) requisicao.body = jsonEncode(dados);
    final resposta = await _cliente
        .send(requisicao)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 15));
    final corpo = resposta.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(resposta.body);
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw StateError(
        corpo is Map
            ? (corpo['erro'] ??
                      corpo['message'] ??
                      'HTTP ${resposta.statusCode}')
                  .toString()
            : 'HTTP ${resposta.statusCode}',
      );
    }
    if (corpo is! Map<String, dynamic>) {
      throw const FormatException('Resposta de perfis RF inválida.');
    }
    return corpo;
  }

  Future<List<PerfilRf>> listar() async {
    final corpo = await _requisitar('GET', '/perfis-rf');
    if (corpo['perfis'] is! List) {
      throw const FormatException('Listagem de perfis RF inválida.');
    }
    return (corpo['perfis'] as List)
        .map(
          (dados) => PerfilRf.fromJson(Map<String, dynamic>.from(dados as Map)),
        )
        .toList();
  }

  Future<PerfilRf> salvar(PerfilRf perfil) async {
    final corpo = await _requisitar(
      perfil.id == null ? 'POST' : 'PATCH',
      perfil.id == null ? '/perfis-rf' : '/perfis-rf/${perfil.id}',
      perfil.toJson(),
    );
    final dados = corpo['perfil'] ?? corpo['perfis'];
    if (dados is! Map) throw const FormatException('Perfil RF inválido.');
    return PerfilRf.fromJson(Map<String, dynamic>.from(dados));
  }

  Future<void> excluir(int id) async {
    await _requisitar('DELETE', '/perfis-rf/$id');
  }

  void dispose() => _cliente.close();
}
