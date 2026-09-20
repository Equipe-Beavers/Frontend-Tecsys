import 'package:flutter/material.dart';
import 'package:frontend_tecsys/models/ativo_bdgd.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class AssetDetailSheet extends StatelessWidget {
  final AtivoBdgd ativo;
  final VoidCallback? onFechar;

  const AssetDetailSheet({
    super.key,
    required this.ativo,
    this.onFechar,
  });

  static Future<void> exibir(
    BuildContext context, {
    required AtivoBdgd ativo,
    VoidCallback? onFechar,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (ctx) => AssetDetailSheet(
        ativo: ativo,
        onFechar: onFechar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 12),

            // Cabeçalho: Título, ID, Badge de Status e Botão Fechar (X)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título do Ativo e ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ativo.tipo.label,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${ativo.id}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge de Status "Em operação"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.badgeSuccessBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryLime.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      ativo.statusOperacional,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.badgeSuccessText,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Botão Fechar (X)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () {
                      if (onFechar != null) {
                        onFechar!();
                      }
                      Navigator.of(context).pop();
                    },
                    tooltip: 'Fechar',
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 12),

            // Tabela de Atributos Chave / Valor fiéis à Tela 2 do Figma
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildLinhaAtributo(
                    rotulo: 'Lat / Long',
                    valor:
                        '${ativo.latitude.toStringAsFixed(4)} / ${ativo.longitude.toStringAsFixed(4)}',
                  ),
                  _buildLinhaAtributo(
                    rotulo: 'Material',
                    valor: ativo.material,
                  ),
                  _buildLinhaAtributo(
                    rotulo: 'Esforço / tração',
                    valor: ativo.esforcoTracao,
                  ),
                  _buildLinhaAtributo(
                    rotulo: 'Ordem de imobilização',
                    valor: ativo.ordemImobilizacao,
                  ),
                  _buildLinhaAtributo(
                    rotulo: 'Situação do ativo',
                    valor: ativo.situacaoAtivo,
                    valorColor: AppColors.primaryLime,
                  ),
                  _buildLinhaAtributo(
                    rotulo: 'Subestação conectada',
                    valor: ativo.subestacaoConectada,
                  ),
                  _buildLinhaAtributo(
                    rotulo: 'Ponto de acesso',
                    valor: ativo.pontoAcesso,
                    mostrarDivisor: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaAtributo({
    required String rotulo,
    required String valor,
    Color valorColor = AppColors.textWhite,
    bool mostrarDivisor = true,
  }) {
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
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  valor,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valorColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (mostrarDivisor)
          const Divider(color: AppColors.borderSubtle, height: 1),
      ],
    );
  }
}

