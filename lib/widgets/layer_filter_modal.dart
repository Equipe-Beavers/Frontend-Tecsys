import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/models/layer_filter.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class LayerFilterModal extends StatefulWidget {
  final Map<TipoAtivo, bool> camadasAtivasAtuais;
  final ValueChanged<Map<TipoAtivo, bool>> onSalvarFiltro;

  const LayerFilterModal({
    super.key,
    required this.camadasAtivasAtuais,
    required this.onSalvarFiltro,
  });

  static Future<void> exibir(
    BuildContext context, {
    required Map<TipoAtivo, bool> camadasAtivas,
    required ValueChanged<Map<TipoAtivo, bool>> onSalvarFiltro,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LayerFilterModal(
        camadasAtivasAtuais: camadasAtivas,
        onSalvarFiltro: onSalvarFiltro,
      ),
    );
  }

  @override
  State<LayerFilterModal> createState() => _LayerFilterModalState();
}

class _LayerFilterModalState extends State<LayerFilterModal> {
  late Map<TipoAtivo, bool> _estadoRascunho;
  final List<GrupoCamadasFiltro> _grupos = CatalogoCamadas.obterGrupos();

  @override
  void initState() {
    super.initState();
    // Clona o mapa de camadas ativas para o rascunho temporário
    _estadoRascunho = Map<TipoAtivo, bool>.from(widget.camadasAtivasAtuais);
  }

  int get _quantidadeAtivas =>
      _estadoRascunho.values.where((ativa) => ativa).length;

  int get _totalCamadas => _estadoRascunho.length;

  void _limparTodas() {
    setState(() {
      for (final key in _estadoRascunho.keys) {
        _estadoRascunho[key] = false;
      }
    });
  }

  void _alternarCamada(TipoAtivo tipo, bool? valor) {
    setState(() {
      _estadoRascunho[tipo] = valor ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final alturaMaxima = mediaQuery.size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: alturaMaxima),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
          left: BorderSide(color: AppColors.border, width: 1.0),
          right: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Puxador visual (drag handle)
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabeçalho com Título, Ícone e Botão Fechar (X)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    color: AppColors.primaryLime,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Camadas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fechar',
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderSubtle, height: 1),

            // Lista Rolável com os Grupos e Camadas
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shrinkWrap: true,
                children: [
                  for (int i = 0; i < _grupos.length; i++) ...[
                    _buildSecaoGrupo(_grupos[i]),
                    if (i < _grupos.length - 1)
                      const Divider(color: AppColors.borderSubtle, height: 24),
                  ],
                ],
              ),
            ),

            const Divider(color: AppColors.borderSubtle, height: 1),

            // Rodapé Fixo com Contador e Botão "Salvar filtro"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppColors.surfaceBackground,
              child: Row(
                children: [
                  // Contador: "7 de 12 camadas ativas"
                  Expanded(
                    child: Text(
                      '$_quantidadeAtivas de $_totalCamadas camadas ativas',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Botão "Salvar filtro"
                  ElevatedButton(
                    onPressed: () {
                      widget.onSalvarFiltro(_estadoRascunho);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLime,
                      foregroundColor: AppColors.textDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Salvar filtro',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecaoGrupo(GrupoCamadasFiltro grupo) {
    final isRede = grupo.categoria == CategoriaAtivo.rede;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da Seção com Título e Ação "Limpar" (se for o primeiro grupo como no Figma)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                grupo.titulo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              if (isRede)
                GestureDetector(
                  onTap: _limparTodas,
                  child: const Text(
                    'Limpar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryTeal,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Itens de Camada
        for (final item in grupo.itens)
          _buildLinhaCamada(item),
      ],
    );
  }

  Widget _buildLinhaCamada(ItemCamadaFiltro item) {
    final isAtiva = _estadoRascunho[item.tipo] ?? false;

    return InkWell(
      onTap: () => _alternarCamada(item.tipo, !isAtiva),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            // Checkbox Estilizado
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isAtiva,
                activeColor: AppColors.primaryLime,
                checkColor: AppColors.textDark,
                side: const BorderSide(color: AppColors.textMuted, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (val) => _alternarCamada(item.tipo, val),
              ),
            ),
            const SizedBox(width: 12),

            // Título da Camada
            Expanded(
              child: Text(
                item.titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isAtiva ? FontWeight.w600 : FontWeight.normal,
                  color: isAtiva ? AppColors.textWhite : AppColors.textMuted,
                ),
              ),
            ),

            // Indicador Visual à direita (traço, ponto, anel ou quadrado)
            _buildIndicadorVisual(item),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicadorVisual(ItemCamadaFiltro item) {
    switch (item.indicadorVisual) {
      case TipoIndicadorVisual.linha:
        return Container(
          width: 20,
          height: 3.5,
          decoration: BoxDecoration(
            color: item.corIndicador,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case TipoIndicadorVisual.ponto:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: item.corIndicador,
            shape: BoxShape.circle,
          ),
        );
      case TipoIndicadorVisual.anel:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: item.corIndicador, width: 2),
          ),
        );
      case TipoIndicadorVisual.quadrado:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: item.corIndicador,
            borderRadius: BorderRadius.circular(2),
          ),
        );
    }
  }
}

