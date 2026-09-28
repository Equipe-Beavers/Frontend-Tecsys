import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/estudo.dart';
import 'package:frontend_tecsys/pages/novo_estudo_page.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class EstudosPage extends StatefulWidget {
  const EstudosPage({super.key, this.estudosService});

  /// Permite injetar um serviço em testes; em produção usa o padrão.
  final EstudosService? estudosService;

  @override
  State<EstudosPage> createState() => EstudosPageState();
}

class EstudosPageState extends State<EstudosPage> {
  late final EstudosService _estudosService =
      widget.estudosService ?? EstudosService();

  late Future<_DadosEstudos> _dados;
  bool _atualizando = false;

  @override
  void initState() {
    super.initState();
    _dados = _buscarDados();
  }

  @override
  void dispose() {
    _estudosService.dispose();
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

  /// Recarrega a lista de estudos. Público para que a navegação principal
  /// possa acionar a atualização ao selecionar a aba Estudos.
  Future<void> recarregar() async {
    if (_atualizando || !mounted) return;

    setState(() => _atualizando = true);
    final busca = _buscarDados();
    // Precisa de bloco {}: com "=>" o callback devolveria a Future e o Flutter
    // lança erro de assert ANTES do try, travando _atualizando em true.
    setState(() {
      _dados = busca;
    });

    try {
      await busca;
    } finally {
      if (mounted) setState(() => _atualizando = false);
    }
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
            onPressed: _atualizando ? null : recarregar,
            icon: _atualizando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textMuted,
                    ),
                  )
                : const Icon(Icons.refresh, color: AppColors.textMuted),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<_DadosEstudos>(
              future: _dados,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryLime,
                    ),
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
                  onRefresh: recarregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: dados.estudos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final estudo = dados.estudos[index];
                      final contagem =
                          dados.contagem[estudo.idEstudo] ??
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
              onPressed: recarregar,
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
      onTap: () => _abrirEstudo(estudo, contagem),
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
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.secondaryTeal,
                ),
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
                  _rotuloStatus(contagem),
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

  String _rotuloStatus(ContagemPontos contagem) {
    if (contagem.completa) return 'Recomendar';
    if (contagem.interesse == 0 && contagem.candidato == 0) {
      return 'Sem pontos marcados';
    }
    if (contagem.interesse == 0) return 'Sem interesse marcado';
    return 'Sem candidato marcado';
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

  Future<void> _abrirEstudo(
    EstudoResumo estudo,
    ContagemPontos contagem,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NovoEstudoPage.detalhes(estudo: estudo, contagem: contagem),
      ),
    );
  }
}

class _DadosEstudos {
  const _DadosEstudos({required this.estudos, required this.contagem});

  final List<EstudoResumo> estudos;
  final Map<int, ContagemPontos> contagem;
}
