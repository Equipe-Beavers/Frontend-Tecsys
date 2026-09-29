import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:frontend_tecsys/config/api_config.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/estudo.dart';
import 'package:frontend_tecsys/models/estudo_ponto.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';

class ContagemPontos {
  const ContagemPontos({required this.interesse, required this.candidato});

  final int interesse;
  final int candidato;

  bool get completa => interesse > 0 && candidato > 0;
}

class EstudosService {
  EstudosService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(
        RegExp(r'/+$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  Future<List<EstudoResumo>> getEstudos() async {
    final resposta = await _client
        .get(Uri.parse('$_baseUrl/estudos'))
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 200) {
      throw StateError(
        'A API de estudos respondeu com HTTP ${resposta.statusCode}.',
      );
    }

    final corpo = jsonDecode(resposta.body);

    if (corpo is! Map || corpo['estudos'] is! List) {
      throw const FormatException('Resposta da listagem de estudos inválida.');
    }

    return (corpo['estudos'] as List)
        .map(
          (item) =>
              EstudoResumo.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<Map<int, ContagemPontos>> getContagemPontos() async {
    final resposta = await _client
        .get(Uri.parse('$_baseUrl/estudo-pontos'))
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 200) {
      throw StateError(
        'A API de pontos respondeu com HTTP ${resposta.statusCode}.',
      );
    }

    final corpo = jsonDecode(resposta.body);

    if (corpo is! Map || corpo['pontos'] is! List) {
      throw const FormatException('Resposta dos pontos do estudo inválida.');
    }

    final contagens = <int, ContagemPontos>{};
    final acumulado = <int, List<int>>{};

    for (final item in corpo['pontos'] as List) {
      final ponto = Map<String, dynamic>.from(item as Map);
      final idEstudo = (ponto['id_estudo'] as num?)?.toInt();
      if (idEstudo == null) continue;

      final papel = ponto['papel']?.toString();
      final conta = acumulado.putIfAbsent(idEstudo, () => [0, 0]);

      // Qualquer ponto cadastrado para o estudo já conta como interesse.
      conta[0] += 1;
      if (papel == 'candidato' || papel == 'ambos') {
        conta[1] += 1;
      }
    }

    acumulado.forEach((idEstudo, conta) {
      contagens[idEstudo] = ContagemPontos(
        interesse: conta[0],
        candidato: conta[1],
      );
    });

    return contagens;
  }

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

  Future<void> criarPontoEstudo(int idEstudo, NovoEstudoPonto ponto) async {
    final resposta = await _client
        .post(
          Uri.parse('$_baseUrl/estudos/$idEstudo/pontos'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(ponto.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 201) {
      final corpo = resposta.body.isEmpty ? null : jsonDecode(resposta.body);
      final mensagem = corpo is Map && corpo['erro'] != null
          ? corpo['erro'].toString()
          : 'A API de pontos respondeu com HTTP ${resposta.statusCode}.';
      throw StateError(mensagem);
    }
  }

  /// Cria um ponto de estudo para cada ativo, em lotes concorrentes.
  /// Retorna a quantidade de pontos criados com sucesso.
  Future<int> criarPontosEstudoParaAtivos(
    int idEstudo,
    List<AtivoBdgd> ativos, {
    String papel = 'interesse',
    int tamanhoLote = 15,
  }) async {
    var criados = 0;

    for (var inicio = 0; inicio < ativos.length; inicio += tamanhoLote) {
      final lote = ativos.skip(inicio).take(tamanhoLote);

      final resultados = await Future.wait(
        lote.map((ativo) async {
          try {
            await criarPontoEstudo(
              idEstudo,
              NovoEstudoPonto(
                idEstudo: idEstudo,
                idAtivoBdgd: ativo.id,
                tipoAtivo: ativo.tipo.apiValue,
                rotulo: ativo.codId,
                papel: papel,
                latitude: ativo.latitude,
                longitude: ativo.longitude,
                atributos: {
                  'municipio': ativo.municipio,
                  'distribuidora': ativo.distribuidora,
                  'status_operacional': ativo.statusOperacional,
                },
              ),
            );
            return true;
          } catch (_) {
            return false;
          }
        }),
      );

      criados += resultados.where((sucesso) => sucesso).length;
    }

    return criados;
  }

  void dispose() => _client.close();
}
