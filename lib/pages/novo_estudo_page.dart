import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/criterio_instalacao.dart';
import 'package:frontend_tecsys/models/estudo.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';
import 'package:frontend_tecsys/pages/recomendacao_resultado_page.dart';
import 'package:frontend_tecsys/services/ativos_service.dart';
import 'package:frontend_tecsys/services/criterio_service.dart';
import 'package:frontend_tecsys/services/estudos_service.dart'
    show EstudosService, ContagemPontos;
import 'package:frontend_tecsys/services/perfil_rf_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/utils/map_utils.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:latlong2/latlong.dart';

class NovoEstudoPage extends StatefulWidget {
  final String distribuidora;
  final String? municipio;
  final String? uf;
  final double areaKm2;
  final List<LatLng> pontosArea;
  final List<AtivoBdgd> ativos;
  final EstudoResumo? estudo;
  final ContagemPontos? contagem;

  const NovoEstudoPage({
    super.key,
    required this.distribuidora,
    required this.municipio,
    required this.areaKm2,
    required this.pontosArea,
    this.uf,
    this.ativos = const [],
  }) : estudo = null,
       contagem = null;

  /// Modo de visualização: exibe um estudo já salvo, com os campos
  /// preenchidos e prontos para prosseguir direto à recomendação.
  NovoEstudoPage.detalhes({
    super.key,
    required EstudoResumo estudo,
    ContagemPontos? contagem,
  }) : estudo = estudo,
       contagem = contagem,
       distribuidora = estudo.distribuidora ?? '',
       municipio = estudo.municipio,
       uf = estudo.uf,
       areaKm2 = calculatePolygonAreaKm2(estudo.pontosArea),
       pontosArea = estudo.pontosArea,
       ativos = const [];

  @override
  State<NovoEstudoPage> createState() => _NovoEstudoPageState();
}

class _NovoEstudoPageState extends State<NovoEstudoPage> {
  final EstudosService _estudosService = EstudosService();
  final PerfilRfService _perfilRfService = PerfilRfService();
  final CriterioService _criterioService = CriterioService();
  final AtivosService _ativosService = AtivosService();
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  late final _cidadeController = TextEditingController(text: widget.municipio);
  final _estadoController = TextEditingController();

  List<PerfilRf> _perfis = PerfilRf.disponiveis;
  List<CriterioInstalacao> _criterios = CriterioInstalacao.disponiveis;
  bool _carregandoOpcoes = true;

  PerfilRf _perfilSelecionado = PerfilRf.padrao;
  CriterioInstalacao _criterioSelecionado = CriterioInstalacao.padrao;
  bool _salvando = false;

  List<AtivoBdgd> _ativosDaArea = [];
  bool _carregandoAtivos = false;

  bool get _modoVisualizacao => widget.estudo != null;

  @override
  void initState() {
    super.initState();
    if (_modoVisualizacao) {
      final estudo = widget.estudo!;
      _nomeController.text = estudo.nome;
      _descricaoController.text = estudo.descricao ?? '';
      _carregarAtivosDaArea();
    }
    _estadoController.text = widget.uf ?? '';
    _carregarOpcoes();
  }

  Future<void> _carregarOpcoes() async {
    try {
      final perfis = await _perfilRfService.getPerfis();
      if (perfis.isNotEmpty && mounted) {
        setState(() {
          _perfis = perfis;
          _perfilSelecionado = perfis.first;
        });
      }
    } catch (_) {
      // Mantém a lista local caso a API não responda.
    }

    try {
      final criterios = await _criterioService.getCriterios();
      if (criterios.isNotEmpty && mounted) {
        setState(() {
          _criterios = criterios;
          _criterioSelecionado = criterios.first;
        });
      }
    } catch (_) {
      // Mantém a lista local caso a API não responda.
    }

    if (mounted) {
      setState(() => _carregandoOpcoes = false);
    }
  }

  @override
  void dispose() {
    _estudosService.dispose();
    _perfilRfService.dispose();
    _criterioService.dispose();
    _ativosService.dispose();
    _nomeController.dispose();
    _descricaoController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  String _formatarNumero(double valor) {
    final texto = valor == valor.roundToDouble()
        ? valor.toStringAsFixed(0)
        : valor.toStringAsFixed(1);
    return texto.replaceAll('.', ',');
  }

  String get _descricaoArea {
    final local = widget.municipio ?? widget.distribuidora;
    return '$local · ${_formatarNumero(widget.areaKm2)} km²';
  }

  Future<void> _carregarAtivosDaArea() async {
    if (widget.pontosArea.length < 3) return;

    setState(() => _carregandoAtivos = true);

    final latitudes = widget.pontosArea.map((ponto) => ponto.latitude);
    final longitudes = widget.pontosArea.map((ponto) => ponto.longitude);

    try {
      final resultado = await _ativosService.getAtivos(
        minLatitude: latitudes.reduce((a, b) => a < b ? a : b),
        maxLatitude: latitudes.reduce((a, b) => a > b ? a : b),
        minLongitude: longitudes.reduce((a, b) => a < b ? a : b),
        maxLongitude: longitudes.reduce((a, b) => a > b ? a : b),
        distribuidora: widget.distribuidora.isEmpty
            ? null
            : widget.distribuidora,
        municipio: widget.municipio,
        limit: 5000,
      );

      if (!mounted) return;

      setState(() {
        _ativosDaArea = resultado.ativos
            .where(
              (ativo) => isPointInPolygon(
                LatLng(ativo.latitude, ativo.longitude),
                widget.pontosArea,
              ),
            )
            .toList();
        _carregandoAtivos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregandoAtivos = false);
    }
  }

  List<AtivoBdgd> get _ativosParaExibir =>
      _modoVisualizacao ? _ativosDaArea : widget.ativos;

  Map<TipoAtivo, List<AtivoBdgd>> get _ativosPorTipo {
    final grupos = <TipoAtivo, List<AtivoBdgd>>{};
    for (final ativo in _ativosParaExibir) {
      (grupos[ativo.tipo] ??= <AtivoBdgd>[]).add(ativo);
    }
    final ordenado = grupos.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Map.fromEntries(ordenado);
  }

  void _abrirListaAtivos(TipoAtivo tipo, List<AtivoBdgd> ativos) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCardLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(tipo.icone, color: tipo.cor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tipo.label,
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${ativos.length} ativo(s)',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: ativos.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final ativo = ativos[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tipo.cor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ativo.codId,
                                style: const TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              'ID ${ativo.id}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAtivosACobrir() {
    final grupos = _ativosPorTipo;

    if (_carregandoAtivos) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryLime),
        ),
      );
    }

    if (grupos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Nenhum ativo dentro da área selecionada.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: grupos.entries.map((entry) {
        final tipo = entry.key;
        final ativos = entry.value;
        return Material(
          color: AppColors.surfaceCardLight,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _abrirListaAtivos(tipo, ativos),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: tipo.cor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tipo.cor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${tipo.label} - ${ativos.length}',
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _selecionarPerfil() {
    SelectionBottomSheet.show<PerfilRf>(
      context: context,
      title: 'Selecionar perfil RF e gateway',
      subtitle: _carregandoOpcoes
          ? 'Carregando perfis do servidor...'
          : 'Perfis disponíveis no banco de dados.',
      items: _perfis
          .map(
            (perfil) => SelectionItem(
              title: '${perfil.nome} · ${perfil.modeloGateway}',
              value: perfil,
            ),
          )
          .toList(),
      selectedValue: _perfilSelecionado,
      onSelected: (perfil) =>
          setState(() => _perfilSelecionado = perfil ?? _perfilSelecionado),
    );
  }

  void _selecionarCriterio() {
    SelectionBottomSheet.show<CriterioInstalacao>(
      context: context,
      title: 'Selecionar critério de instalação',
      items: _criterios
          .map(
            (criterio) => SelectionItem(title: criterio.nome, value: criterio),
          )
          .toList(),
      selectedValue: _criterioSelecionado,
      onSelected: (criterio) => setState(
        () => _criterioSelecionado = criterio ?? _criterioSelecionado,
      ),
    );
  }

  String? _textoOuNulo(TextEditingController controller) {
    final texto = controller.text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _criarEstudo() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    if (widget.ativos.isEmpty) {
      _mostrarMensagem(
        'Não há ativos na área para criar os pontos do estudo e gerar a recomendação.',
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final estudoCriado = await _estudosService.criarEstudo(
        NovoEstudo(
          nome: _nomeController.text.trim(),
          descricao: _textoOuNulo(_descricaoController),
          uf: _textoOuNulo(_estadoController)?.toUpperCase(),
          municipio: _textoOuNulo(_cidadeController),
          distribuidora: widget.distribuidora.isEmpty
              ? null
              : widget.distribuidora,
          pontosArea: widget.pontosArea,
        ),
      );
      if (!mounted) return;

      final idEstudo = (estudoCriado['id_estudo'] as num?)?.toInt();
      if (idEstudo == null) {
        Navigator.pop(context, true);
        return;
      }

      final candidato = widget.ativos.firstWhere(
        (ativo) =>
            ativo.tipo == TipoAtivo.poste || ativo.tipo == TipoAtivo.subestacao,
        orElse: () => widget.ativos.first,
      );
      final interesse = [...widget.ativos]..remove(candidato);

      final pontosCandidatoCriados = await _estudosService
          .criarPontosEstudoParaAtivos(idEstudo, [
            candidato,
          ], papel: interesse.isEmpty ? 'ambos' : 'candidato');
      var pontosInteresseCriados = 0;
      if (interesse.isNotEmpty) {
        pontosInteresseCriados = await _estudosService
            .criarPontosEstudoParaAtivos(
              idEstudo,
              interesse,
              papel: 'interesse',
            );
      } else {
        pontosInteresseCriados = pontosCandidatoCriados;
      }

      if (!mounted) return;
      if (pontosCandidatoCriados == 0 || pontosInteresseCriados == 0) {
        setState(() => _salvando = false);
        _mostrarMensagem(
          'O estudo foi salvo, mas não há pontos suficientes com os papéis candidato e interesse. Verifique os ativos da área e tente novamente.',
        );
        return;
      }

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RecomendacaoResultadoPage(
            idEstudo: idEstudo,
            idPerfilRf: _perfilSelecionado.idPerfilRf ?? 1,
            idCriterioInstalacao: _criterioSelecionado.idCriterioInstalacao,
            titulo: _nomeController.text.trim(),
            subtitulo: _descricaoArea,
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível criar o estudo: $erro'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _abrirRecomendacao() async {
    final estudo = widget.estudo;
    if (_salvando || estudo == null) return;

    final contagem = widget.contagem;
    if (contagem != null && !contagem.completa) {
      final semInteresse = contagem.interesse == 0;
      final semCandidato = contagem.candidato == 0;
      final mensagem = semInteresse && semCandidato
          ? 'Este estudo ainda não possui pontos de interesse e candidatos marcados.'
          : semInteresse
          ? 'Este estudo ainda não possui pontos de interesse marcados.'
          : 'Este estudo ainda não possui candidatos marcados.';
      _mostrarMensagem(mensagem);
      return;
    }

    setState(() => _salvando = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecomendacaoResultadoPage(
            idEstudo: estudo.idEstudo,
            idPerfilRf: _perfilSelecionado.idPerfilRf ?? 1,
            idCriterioInstalacao: _criterioSelecionado.idCriterioInstalacao,
            titulo: estudo.nome,
            subtitulo: estudo.local,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCabecalho(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _buildRotulo('NOME DO ESTUDO'),
                    _buildCampoTexto(
                      controller: _nomeController,
                      dica: 'Ex.: Zona Oeste — Religadores',
                      validador: (valor) =>
                          (valor == null || valor.trim().isEmpty)
                          ? 'Informe o nome do estudo'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildRotulo('DESCRIÇÃO'),
                    _buildCampoTexto(
                      controller: _descricaoController,
                      dica: 'Descreva o objetivo do estudo',
                      linhas: 3,
                    ),
                    const SizedBox(height: 20),
                    _buildCardArea(),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRotulo('CIDADE'),
                              _buildCampoTexto(
                                controller: _cidadeController,
                                dica: 'Ex.: Uberaba',
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRotulo('ESTADO'),
                              _buildCampoTexto(
                                controller: _estadoController,
                                tamanhoMaximo: 2,
                                dica: 'UF',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildRotulo('PERFIL DE RF E GATEWAY'),
                    _buildCardSelecao(
                      titulo:
                          '${_perfilSelecionado.nome} · ${_perfilSelecionado.modeloGateway}',
                      onTap: _selecionarPerfil,
                      conteudo: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _buildDetalhe(
                            '${_formatarNumero(_perfilSelecionado.frequenciaMhz)} MHz',
                          ),
                          _buildDetalhe(
                            '${_formatarNumero(_perfilSelecionado.potenciaTransmissaoDbm)} dBm TX',
                          ),
                          _buildDetalhe(
                            '${_formatarNumero(_perfilSelecionado.sensibilidadeRecepcaoDbm)} dBm RX',
                          ),
                          _buildDetalhe(
                            'Gateway ${_formatarNumero(_perfilSelecionado.alturaGatewayM)} m',
                            destaque: true,
                          ),
                          _buildDetalhe(
                            'Dispositivo ${_formatarNumero(_perfilSelecionado.alturaDispositivoM)} m',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRotulo('CRITÉRIOS DE INSTALAÇÃO'),
                    _buildCardSelecao(
                      titulo: _criterioSelecionado.nome,
                      onTap: _selecionarCriterio,
                      conteudo: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildEtiqueta(
                            'Altura mín. ${_formatarNumero(_criterioSelecionado.alturaMinimaM)} m',
                          ),
                          if (_criterioSelecionado.requerAlimentacaoEletrica)
                            _buildEtiqueta('Requer alimentação'),
                          _buildEtiqueta(
                            'Máx. ${_criterioSelecionado.limiteGateways} gateways',
                            destaque: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRotulo('ATIVOS A COBRIR'),
                    _buildAtivosACobrir(),
                  ],
                ),
              ),
              _buildRodape(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textWhite,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              _modoVisualizacao ? 'Detalhes do estudo' : 'Novo estudo',
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryTeal,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _modoVisualizacao ? 'SIMULAR' : 'PASSO 4 DE 4',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String dica,
    int linhas = 1,
    FormFieldValidator<String>? validador,
    int? tamanhoMaximo,
    bool habilitado = true,
  }) {
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextFormField(
      controller: controller,
      maxLines: linhas,
      validator: validador,
      enabled: habilitado,
      inputFormatters: tamanhoMaximo == null
          ? null
          : [LengthLimitingTextInputFormatter(tamanhoMaximo)],
      style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
      cursorColor: AppColors.primaryLime,
      decoration: InputDecoration(
        hintText: dica,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: borda,
        border: borda,
        focusedBorder: borda.copyWith(
          borderSide: const BorderSide(color: AppColors.primaryLime),
        ),
      ),
    );
  }

  Widget _buildCardArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceCardLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.crop_free,
              color: AppColors.primaryLime,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ÁREA SELECIONADA',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _descricaoArea,
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!_modoVisualizacao)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Editar',
                style: TextStyle(
                  color: AppColors.secondaryTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardSelecao({
    required String titulo,
    required VoidCallback onTap,
    required Widget conteudo,
  }) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              conteudo,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetalhe(String texto, {bool destaque = false}) {
    return Text(
      texto,
      style: TextStyle(
        color: destaque ? AppColors.primaryLime : AppColors.textMuted,
        fontSize: 12,
      ),
    );
  }

  Widget _buildEtiqueta(String texto, {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: destaque
              ? AppColors.primaryLime.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: destaque ? AppColors.primaryLime : AppColors.textMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRodape() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _salvando
              ? null
              : (_modoVisualizacao ? _abrirRecomendacao : _criarEstudo),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLime,
            foregroundColor: AppColors.textDark,
            disabledBackgroundColor: AppColors.primaryLime.withValues(
              alpha: 0.6,
            ),
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textDark,
                  ),
                )
              : Text(
                  _modoVisualizacao
                      ? 'Ver recomendação'
                      : 'Criar estudo e simular',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
