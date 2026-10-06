import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/estudo.dart';
import 'package:frontend_tecsys/pages/novo_estudo_page.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class EstudosPage extends StatefulWidget {
  const EstudosPage({super.key});

  @override
  State<EstudosPage> createState() => _EstudosPageState();
}

class _EstudosPageState extends State<EstudosPage> {
  final EstudosService _estudosService = EstudosService();
  late Future<List<EstudoResumo>> _estudosFuture;

  @override
  void initState() {
    super.initState();
    _estudosFuture = _estudosService.listarEstudos();
  }

  @override
  void dispose() {
    _estudosService.dispose();
    super.dispose();
  }

  void _recarregar() {
    setState(() {
      _estudosFuture = _estudosService.listarEstudos();
    });
  }

  Future<void> _confirmarExclusao(EstudoResumo estudo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Excluir estudo?',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          'O estudo "${estudo.nome}" será excluído permanentemente.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textWhite),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      await _estudosService.excluirEstudo(estudo.id);
      if (!mounted) return;
      _recarregar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estudo excluído com sucesso.')),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir o estudo: $erro')),
      );
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
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar estudos',
            onPressed: _recarregar,
            icon: const Icon(Icons.refresh, color: AppColors.primaryLime),
          ),
        ],
      ),
      body: FutureBuilder<List<EstudoResumo>>(
        future: _estudosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLime),
            );
          }

          if (snapshot.hasError) {
            return _MensagemEstado(
              icone: Icons.cloud_off,
              titulo: 'Não foi possível carregar os estudos',
              detalhe: snapshot.error.toString(),
              acao: _recarregar,
            );
          }

          final estudos = snapshot.data ?? const <EstudoResumo>[];
          if (estudos.isEmpty) {
            return const _MensagemEstado(
              icone: Icons.layers_clear,
              titulo: 'Nenhum estudo encontrado',
              detalhe: 'Os estudos criados no sistema aparecerão aqui.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryLime,
            backgroundColor: AppColors.surfaceCard,
            onRefresh: () async {
              _recarregar();
              await _estudosFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: estudos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _EstudoCard(
                estudo: estudos[index],
                onExcluir: () => _confirmarExclusao(estudos[index]),
                onAtualizado: _recarregar,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EstudoCard extends StatelessWidget {
  const _EstudoCard({
    required this.estudo,
    required this.onExcluir,
    required this.onAtualizado,
  });

  final EstudoResumo estudo;
  final VoidCallback onExcluir;
  final VoidCallback onAtualizado;

  @override
  Widget build(BuildContext context) {
    final local = [
      if (estudo.municipio != null) estudo.municipio!,
      if (estudo.uf != null) estudo.uf!,
    ].join(' - ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final atualizado = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => NovoEstudoPage.edicao(estudo: estudo),
              ),
            );
            if (atualizado == true) onAtualizado();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        estudo.nome,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Excluir estudo',
                      onPressed: onExcluir,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                    _StatusBadge(status: estudo.status),
                  ],
                ),
                if (estudo.descricao != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    estudo.descricao!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (estudo.distribuidora != null)
                      _InfoItem(
                        Icons.electrical_services,
                        estudo.distribuidora!,
                      ),
                    if (local.isNotEmpty) _InfoItem(Icons.location_on, local),
                    if (estudo.bairro != null)
                      _InfoItem(Icons.home_work_outlined, estudo.bairro!),
                    _InfoItem(
                      Icons.map_outlined,
                      _tipoDelimitacao(estudo.tipoDelimitacao),
                    ),
                    if (estudo.criadoEm != null)
                      _InfoItem(
                        Icons.schedule,
                        _formatarData(estudo.criadoEm!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _tipoDelimitacao(String tipo) {
    switch (tipo) {
      case 'desenho':
        return 'Área desenhada';
      case 'selecao':
        return 'Seleção';
      case 'mancha':
        return 'Mancha';
      default:
        return tipo;
    }
  }

  static String _formatarData(DateTime data) {
    final local = data.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    return '$dia/$mes/${local.year}';
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem(this.icone, this.texto);

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 15, color: AppColors.secondaryTeal),
        const SizedBox(width: 5),
        Text(
          texto,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final texto = status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.badgeSuccessBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.badgeSuccessText,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MensagemEstado extends StatelessWidget {
  const _MensagemEstado({
    required this.icone,
    required this.titulo,
    required this.detalhe,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String detalhe;
  final VoidCallback? acao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: AppColors.secondaryTeal, size: 42),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detalhe,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (acao != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: acao,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLime,
                  foregroundColor: AppColors.textDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
