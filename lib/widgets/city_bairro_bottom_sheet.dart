import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class CidadeBairroBottomSheet extends StatefulWidget {
  final List<String> cidades;
  final Map<String, List<String>> bairrosPorCidade;
  final Map<String, String?> ufPorCidade;
  final String? cidadeSelecionada;
  final String? bairroSelecionado;
  final String? stepLabel;
  final String? breadcrumb;
  final String notFoundMessage;

  final Function(String? cidade, String? bairro) onProsseguir;

  const CidadeBairroBottomSheet({
    super.key,
    required this.cidades,
    required this.bairrosPorCidade,
    this.ufPorCidade = const {},
    this.cidadeSelecionada,
    this.bairroSelecionado,
    this.stepLabel,
    this.breadcrumb,
    this.notFoundMessage = 'Não encontrada',
    required this.onProsseguir,
  });

  @override
  State<CidadeBairroBottomSheet> createState() =>
      _CidadeBairroBottomSheetState();
}

class _CidadeBairroBottomSheetState extends State<CidadeBairroBottomSheet> {
  String? _cidadeSelecionada;
  String? _bairroSelecionado;
  final TextEditingController _buscaController = TextEditingController();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _cidadeSelecionada = widget.cidadeSelecionada;
    _bairroSelecionado = widget.bairroSelecionado;
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<String> get _cidadesFiltradas {
    if (_busca.trim().isEmpty) return widget.cidades;
    final termo = _busca.trim().toLowerCase();

    return widget.cidades.where((cidade) {
      if (cidade.toLowerCase().contains(termo)) return true;
      if (widget.ufPorCidade[cidade]?.toLowerCase().contains(termo) ?? false) {
        return true;
      }
      final bairros = widget.bairrosPorCidade[cidade] ?? [];
      return bairros.any((bairro) => bairro.toLowerCase().contains(termo));
    }).toList();
  }

  // IMPORTANTE:
  // Se não houver cidades carregadas, libera o Prosseguir mesmo
  // sem seleção, para não travar o fluxo.
  bool get _podeProsseguir =>
      _cidadeSelecionada != null || widget.cidades.isEmpty;

  @override
  Widget build(BuildContext context) {
    final cidades = _cidadesFiltradas;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cidade / bairro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                  if (widget.stepLabel != null)
                    Text(
                      widget.stepLabel!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),

            if (widget.breadcrumb != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.breadcrumb!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 4),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selecione a cidade e o bairro para o estudo.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _buscaController,
                onChanged: (valor) => setState(() => _busca = valor),
                style: const TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(
                  hintText: 'Buscar cidade ou bairro',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceInput,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSubtle, height: 1),

            Flexible(
              child: cidades.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 20,
                      ),
                      child: Center(
                        child: Text(
                          widget.notFoundMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final cidade in cidades) _buildCidade(cidade),
                      ],
                    ),
            ),

            if (widget.cidades.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Você pode prosseguir mesmo sem selecionar uma cidade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),

            const Divider(color: AppColors.borderSubtle, height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _cidadeSelecionada = null;
                        _bairroSelecionado = null;
                        _buscaController.clear();
                        _busca = '';
                      });
                    },
                    child: const Text(
                      'Limpar',
                      style: TextStyle(color: AppColors.textWhite),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _podeProsseguir
                          ? () {
                              widget.onProsseguir(
                                _cidadeSelecionada,
                                _bairroSelecionado,
                              );
                              Navigator.of(context).pop();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLime,
                        foregroundColor: AppColors.textDark,
                        disabledBackgroundColor: AppColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Prosseguir',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildCidade(String cidade) {
    final selecionada = cidade == _cidadeSelecionada;
    final bairros = widget.bairrosPorCidade[cidade] ?? [];
    final uf = widget.ufPorCidade[cidade];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selecionada
            ? AppColors.surfaceCardLight
            : AppColors.surfaceBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selecionada
              ? AppColors.primaryLime.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _cidadeSelecionada = cidade;
                _bairroSelecionado = null;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    selecionada
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: AppColors.primaryLime,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      uf == null || uf.isEmpty ? cidade : '$cidade - $uf',
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: selecionada
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '${bairros.length} bairros',
                    style: const TextStyle(
                      color: AppColors.primaryLime,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selecionada && bairros.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final bairro in bairros) _buildBairro(bairro)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBairro(String bairro) {
    final selecionado = bairro == _bairroSelecionado;

    return GestureDetector(
      onTap: () {
        setState(() {
          _bairroSelecionado = bairro;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.primaryLime : AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          bairro,
          style: TextStyle(
            color: selecionado ? AppColors.textDark : AppColors.textWhite,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
