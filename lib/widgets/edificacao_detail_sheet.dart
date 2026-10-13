import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/edificacao.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class EdificacaoDetailSheet extends StatelessWidget {
  final Edificacao edificacao;

  const EdificacaoDetailSheet({
    super.key,
    required this.edificacao,
  });

  static Future<void> exibir(
    BuildContext context, {
    required Edificacao edificacao,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (ctx) => EdificacaoDetailSheet(edificacao: edificacao),
    );
  }

  static String _origem(String origem) {
    switch (origem) {
      case 'INFORMADA':
      case 'INFORMADO':
        return 'informado pela fonte';
      case 'PAVIMENTOS':
        return 'estimado pelos pavimentos';
      default:
        return 'padrão do projeto';
    }
  }

  static String _metros(double? valor) =>
      valor == null ? 'Não informado' : '${valor.toStringAsFixed(1)} m';

  @override
  Widget build(BuildContext context) {
    final linhas = <MapEntry<String, String>>[
      MapEntry('Altura', '${_metros(edificacao.alturaM)} (${_origem(edificacao.origemAltura)})'),
      MapEntry('Largura', _metros(edificacao.larguraM)),
      MapEntry('Profundidade', _metros(edificacao.profundidadeM)),
      if (edificacao.areaM2 != null)
        MapEntry('Área', '${edificacao.areaM2!.toStringAsFixed(0)} m²'),
      if (edificacao.pavimentos != null)
        MapEntry('Pavimentos', '${edificacao.pavimentos}'),
      MapEntry('Material', '${edificacao.nomeMaterial} (${_origem(edificacao.origemMaterial)})'),
      MapEntry('Perda por parede', '${edificacao.perdaMaterialDb.toStringAsFixed(1)} dB (915 MHz)'),
      if (edificacao.fonteOriginal != null && edificacao.fonteOriginal!.isNotEmpty)
        MapEntry('Fonte', edificacao.fonteOriginal!),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
          left: BorderSide(color: AppColors.border, width: 1.0),
          right: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.apartment, color: edificacao.cor, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Edificação',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var i = 0; i < linhas.length; i++)
                    _buildLinha(linhas[i].key, linhas[i].value, i != linhas.length - 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinha(String rotulo, String valor, bool mostrarDivisor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rotulo,
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  valor,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (mostrarDivisor) const Divider(color: AppColors.borderSubtle, height: 1),
      ],
    );
  }
}
