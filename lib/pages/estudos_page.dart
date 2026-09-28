import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/criterio_instalacao.dart';
import 'package:frontend_tecsys/models/estudo.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';
import 'package:frontend_tecsys/pages/recomendacao_resultado_page.dart';
import 'package:frontend_tecsys/services/criterio_service.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/services/perfil_rf_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';

class EstudosPage extends StatefulWidget {
  const EstudosPage({super.key});

  @override
  State<EstudosPage> createState() => _EstudosPageState();
}

class _EstudosPageState extends State<EstudosPage> {
  final EstudosService _estudosService = EstudosService();
  final PerfilRfService _perfisService = PerfilRfService();
  final CriterioService _criteriosService = CriterioService();

  late Future<_DadosEstudos> _dados;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _dados = _buscarDados();
  }

  @override
  void dispose() {
    _estudosService.dispose();
    _perfisService.dispose();
    _criteriosService.dispose();
    super.dispose();
  }

  Future<_DadosEstudos> _buscarDados() async {
    final estudos = await _estudosService.getEstudos();

    Map<int, ContagemPontos> contagem = {};
    try {
      contagem = await _estudosService.getContagemPontos();
    } catch (_) {
      contagem = {};
    }

    return _DadosEstudos(estudos: estudos, contagem: contagem);
  }

  void _recarregar() {
    setState(() => _dados = _buscarDados());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBackground,
        elevation: 0,
        title: const Text(
          'Estudos',
          style: TextStyle(color: AppColors.textWhite, fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: _recarregar,
            icon: const Icon(Icons.refresh, color: AppColors.textMuted),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_processando)
            const LinearProgressIndicator(
              color: AppColors.primaryLime,
              backgroundColor: AppColors.surfaceCard,
              minHeight: 2,
            ),
          Expanded(
            child: FutureBuilder<_DadosEstudos>(
              future: _dados,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primaryLime),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErro(snapshot.error.toString());
                }

                final dados = snapshot.data!;
                if (dados.estudos.isEmpty) {
                  return _buildVazio();
                }

                return RefreshIndicator(
                  color: AppColors.primaryLime,
                  onRefresh: () async => _recarregar(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: dados.estudos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final estudo = dados.estudos[index];
                      final contagem = dados.contagem[estudo.idEstudo] ??
                          const ContagemPontos(interesse: 0, candidato: 0);
                      return _buildCard(estudo, contagem);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErro(String mensagem) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 32),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os estudos.\n$mensagem',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _recarregar,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryLime,
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, color: AppColors.textMuted, size: 32),
          SizedBox(height: 12),
          Text(
            'Nenhum estudo cadastrado até o momento.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(EstudoResumo estudo, ContagemPontos contagem) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _processando ? null : () => _abrirEstudo(estudo, contagem),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    estudo.nome,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildBadge(estudo.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              estudo.local,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (estudo.descricao != null && estudo.descricao!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                estudo.descricao!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.secondaryTeal),
                const SizedBox(width: 4),
                Text(
                  '${contagem.interesse} interesse · ${contagem.candidato} candidato',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  contagem.completa ? 'Recomendar' : 'Sem pontos marcados',
                  style: TextStyle(
                    color: contagem.completa
                        ? AppColors.primaryLime
                        : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: contagem.completa
                      ? AppColors.primaryLime
                      : AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String status) {
    final rotulo = status.replaceAll('_', ' ').toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.badgeSuccessBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rotulo,
        style: const TextStyle(
          color: AppColors.badgeSuccessText,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _abrirEstudo(EstudoResumo estudo, ContagemPontos contagem) async {
    if (!contagem.completa) {
      _mostrarMensagem(
        'Este estudo ainda não possui pontos de interesse e candidatos marcados.',
      );
      return;
    }

    setState(() => _processando = true);

    try {
      final perfis = await _carregarPerfis();
      if (!mounted) return;

      final perfilSelecionado = await _escolherPerfil(perfis);
      if (perfilSelecionado == null || !mounted) return;

      final criterios = await _carregarCriterios();
      if (!mounted) return;

      final criterioSelecionado = await _escolherCriterio(criterios);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecomendacaoResultadoPage(
            idEstudo: estudo.idEstudo,
            idPerfilRf: perfilSelecionado.idPerfilRf ?? 1,
            idCriterioInstalacao: criterioSelecionado?.idCriterioInstalacao,
            titulo: estudo.nome,
            subtitulo: estudo.local,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Future<List<PerfilRf>> _carregarPerfis() async {
    try {
      final perfis = await _perfisService.getPerfis();
      if (perfis.isNotEmpty) return perfis;
    } catch (_) {
      // Fallback para a lista local caso a API não responda.
    }
    return PerfilRf.disponiveis;
  }

  Future<List<CriterioInstalacao>> _carregarCriterios() async {
    try {
      final criterios = await _criteriosService.getCriterios();
      if (criterios.isNotEmpty) return criterios;
    } catch (_) {
      // Fallback para a lista local caso a API não responda.
    }
    return CriterioInstalacao.disponiveis;
  }

  Future<PerfilRf?> _escolherPerfil(List<PerfilRf> perfis) async {
    PerfilRf? selecionado;

    await SelectionBottomSheet.show<PerfilRf>(
      context: context,
      title: 'Selecionar perfil RF',
      subtitle: 'Os parâmetros de rádio usados no cálculo de cobertura.',
      searchHint: 'Buscar perfil',
      notFoundMessage: 'Nenhum perfil encontrado.',
      items: perfis
          .map(
            (perfil) => SelectionItem(
              title: perfil.nome,
              subtitle: perfil.modeloGateway,
              value: perfil,
            ),
          )
          .toList(),
      selectedValue: perfis.isEmpty ? null : perfis.first,
      onSelected: (perfil) => selecionado = perfil,
    );

    return selecionado;
  }

  Future<CriterioInstalacao?> _escolherCriterio(
    List<CriterioInstalacao> criterios,
  ) async {
    CriterioInstalacao? selecionado;

    await SelectionBottomSheet.show<CriterioInstalacao>(
      context: context,
      title: 'Selecionar critério de instalação',
      subtitle: 'Regras usadas para posicionar os gateways.',
      searchHint: 'Buscar critério',
      notFoundMessage: 'Nenhum critério encontrado.',
      items: criterios
          .map(
            (criterio) => SelectionItem(
              title: criterio.nome,
              subtitle: 'Altura mínima ${criterio.alturaMinimaM} m',
              value: criterio,
            ),
          )
          .toList(),
      selectedValue: criterios.isEmpty ? null : criterios.first,
      onSelected: (criterio) => selecionado = criterio,
    );

    return selecionado;
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DadosEstudos {
  const _DadosEstudos({required this.estudos, required this.contagem});

  final List<EstudoResumo> estudos;
  final Map<int, ContagemPontos> contagem;
}
