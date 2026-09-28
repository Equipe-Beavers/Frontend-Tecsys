import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/models/criterio_instalacao.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';
import 'package:frontend_tecsys/models/perfil_rf.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:latlong2/latlong.dart';

class NovoEstudoPage extends StatefulWidget {
  final String distribuidora;
  final String? municipio;
  final double areaKm2;
  final List<LatLng> pontosArea;

  const NovoEstudoPage({
    super.key,
    required this.distribuidora,
    required this.municipio,
    required this.areaKm2,
    required this.pontosArea,
  });

  @override
  State<NovoEstudoPage> createState() => _NovoEstudoPageState();
}

class _NovoEstudoPageState extends State<NovoEstudoPage> {
  final EstudosService _estudosService = EstudosService();
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  late final _cidadeController = TextEditingController(text: widget.municipio);
  final _estadoController = TextEditingController();
  final _bairroController = TextEditingController();

  PerfilRf _perfilSelecionado = PerfilRf.padrao;
  CriterioInstalacao _criterioSelecionado = CriterioInstalacao.padrao;
  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _bairroController.dispose();
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

  void _selecionarPerfil() {
    SelectionBottomSheet.show<PerfilRf>(
      context: context,
      title: 'Selecionar perfil RF e gateway',
      items: PerfilRf.disponiveis
          .map(
            (perfil) => SelectionItem(
              title: '${perfil.nome} · ${perfil.modeloGateway}',
              value: perfil,
            ),
          )
          .toList(),
      selectedValue: _perfilSelecionado,
      onSelected: (perfil) => setState(() => _perfilSelecionado = perfil),
    );
  }

  void _selecionarCriterio() {
    SelectionBottomSheet.show<CriterioInstalacao>(
      context: context,
      title: 'Selecionar critério de instalação',
      items: CriterioInstalacao.disponiveis
          .map(
            (criterio) => SelectionItem(title: criterio.nome, value: criterio),
          )
          .toList(),
      selectedValue: _criterioSelecionado,
      onSelected: (criterio) => setState(() => _criterioSelecionado = criterio),
    );
  }

  String? _textoOuNulo(TextEditingController controller) {
    final texto = controller.text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _criarEstudo() async {
    if (_salvando || !_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      await _estudosService.criarEstudo(
        NovoEstudo(
          nome: _nomeController.text.trim(),
          descricao: _textoOuNulo(_descricaoController),
          uf: _textoOuNulo(_estadoController)?.toUpperCase(),
          municipio: _textoOuNulo(_cidadeController),
          bairro: _textoOuNulo(_bairroController),
          distribuidora: widget.distribuidora.isEmpty
              ? null
              : widget.distribuidora,
          pontosArea: widget.pontosArea,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
                    _buildRotulo('BAIRRO'),
                    _buildCampoTexto(
                      controller: _bairroController,
                      dica: 'Ex.: Zona Oeste',
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
          const Expanded(
            child: Text(
              'Novo estudo',
              style: TextStyle(
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
            child: const Text(
              'PASSO 4 DE 4',
              style: TextStyle(
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
  }) {
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextFormField(
      controller: controller,
      maxLines: linhas,
      validator: validador,
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
          onPressed: _salvando ? null : _criarEstudo,
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
              : const Text(
                  'Criar estudo e simular',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
