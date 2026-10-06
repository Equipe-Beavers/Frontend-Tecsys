import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/recomendacao_resultado.dart';
import 'package:frontend_tecsys/services/recomendacao_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';

class RecomendacaoResultadoPage extends StatefulWidget {
  final int idEstudo;
  final int idPerfilRf;
  final int? idCriterioInstalacao;

  final String? titulo;
  final String? subtitulo;

  final ResultadoRecomendacao? resultadoInicial;

  const RecomendacaoResultadoPage({
    super.key,
    required this.idEstudo,
    required this.idPerfilRf,
    this.idCriterioInstalacao,
    this.titulo,
    this.subtitulo,

    this.resultadoInicial,
  });

  @override
  State<RecomendacaoResultadoPage> createState() =>
      _RecomendacaoResultadoPageState();
}

class _RecomendacaoResultadoPageState extends State<RecomendacaoResultadoPage> {
  final _service = RecomendacaoService();
  late Future<ResultadoRecomendacao> _futureResultado;

  @override
  void initState() {
    super.initState();

    if (widget.resultadoInicial != null) {
      _futureResultado = Future.value(widget.resultadoInicial);
    } else {
      _futureResultado = _service.gerarRecomendacao(
        idEstudo: widget.idEstudo,
        idPerfilRf: widget.idPerfilRf,
        idCriterioInstalacao: widget.idCriterioInstalacao,
      );
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBackground,
        elevation: 0,
        leading: const BackButton(color: AppColors.textWhite),
        title: Text(
          widget.titulo ?? 'Resultado da recomendação',
          style: const TextStyle(color: AppColors.textWhite, fontSize: 16),
        ),
      ),
      body: FutureBuilder<ResultadoRecomendacao>(
        future: _futureResultado,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildCarregando();
          }
          if (snapshot.hasError) {
            return _buildErro(snapshot.error.toString());
          }
          return _buildConteudo(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryLime),
          SizedBox(height: 16),
          Text(
            'Calculando a recomendação de cobertura...',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
            const Icon(
              Icons.error_outline,
              color: AppColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'Não foi possível gerar a recomendação.\n$mensagem',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo(ResultadoRecomendacao r) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (widget.subtitulo != null) ...[
          Text(
            widget.subtitulo!.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildKpis(r),
        const SizedBox(height: 20),
        _buildCoberturaGeral(r),
        if (r.porCategoria.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildPorCategoria(r),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gateways propostos',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${r.gateways.length} de ${r.quantidadeGateways}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...r.gateways.map(_buildGatewayCard),
      ],
    );
  }

  Widget _buildKpis(ResultadoRecomendacao r) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            'Cobertura',
            '${r.percentualCobertura}%',
            AppColors.primaryLime,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            'Gateways',
            '${r.quantidadeGateways}',
            AppColors.secondaryTeal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            'Custo Total',
            'R\$ ${_formatarValor(r.custoTotalEstimado)}',
            AppColors.layerChaveFusivel,
          ),
        ),
      ],
    );
  }

  String _formatarValor(double valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(1)}K';
    return valor.toStringAsFixed(0);
  }

  Widget _kpiCard(String label, String valor, Color corValor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              color: corValor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoberturaGeral(ResultadoRecomendacao r) {
    final progresso = r.pontosInteresse > 0
        ? r.pontosCobertos / r.pontosInteresse
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ativos elétricos cobertos',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${r.pontosCobertos} de ${r.pontosInteresse}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresso.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryLime),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPorCategoria(ResultadoRecomendacao r) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < r.porCategoria.length; i++)
            _buildLinhaCategoria(
              r.porCategoria[i],
              i != r.porCategoria.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildLinhaCategoria(CategoriaCobertura c, bool mostrarDivisor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(c.tipo.icone, color: c.tipo.cor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    c.tipo.label,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${c.cobertos}',
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (c.naoCobertos > 0)
                    Text(
                      ' / ${c.naoCobertos} sem cobertura',
                      style: const TextStyle(
                        color: AppColors.layerChaveFusivel,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (mostrarDivisor)
          const Divider(color: AppColors.borderSubtle, height: 1),
      ],
    );
  }

  Widget _buildGatewayCard(GatewayProposto g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                g.rotulo ?? 'Gateway ${g.idEstudoPonto}',
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (g.idAtivoBdgd != null)
                Text(
                  g.idAtivoBdgd!,
                  style: const TextStyle(
                    color: AppColors.secondaryTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _linhaAtributo(
            'Coordenadas',
            '${g.latitude.toStringAsFixed(4)}, ${g.longitude.toStringAsFixed(4)}',
          ),
          if (g.descricaoAtivo != null)
            _linhaAtributo('Ativo elétrico', g.descricaoAtivo!),
          if (g.alimentador != null)
            _linhaAtributo('Alimentador', g.alimentador!),
          _linhaAtributo('Atende', '${g.quantidadeAtendidos} ativo(s)'),
        ],
      ),
    );
  }

  Widget _linhaAtributo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rotulo,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
