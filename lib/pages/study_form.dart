import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_tecsys/models/install_criterion.dart';
import 'package:frontend_tecsys/services/install_criterion_service.dart';
import 'package:frontend_tecsys/models/novo_estudo.dart';
import 'package:frontend_tecsys/models/rf_profile.dart';
import 'package:frontend_tecsys/services/rf_profile_service.dart';
import 'package:frontend_tecsys/services/estudos_service.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';
import 'package:frontend_tecsys/widgets/dist_bottom_sheet.dart';
import 'package:frontend_tecsys/widgets/primary_button.dart';
import 'package:frontend_tecsys/widgets/secondary_button.dart';
import 'package:latlong2/latlong.dart';

class NovoEstudoPage extends StatefulWidget {
  final String distribuidora;
  final String? municipio;
  final String? bairro;
  final String? uf;
  final double areaKm2;
  final List<LatLng> pontosArea;
  final List<double?> relevoPontos;
  final InstallCriterionService? criterionService;
  final RFProfileService? rfProfileService;
  final EstudosService? studyService;
  final int userId;
  final Map<String, dynamic>? study;

  const NovoEstudoPage({
    super.key,
    required this.distribuidora,
    required this.municipio,
    this.bairro,
    this.uf,
    required this.areaKm2,
    required this.pontosArea,
    this.relevoPontos = const [],
    this.criterionService,
    this.rfProfileService,
    this.studyService,
    this.study,
    this.userId = const int.fromEnvironment('APP_USER_ID', defaultValue: 1),
  });

  @override
  State<NovoEstudoPage> createState() => _NovoEstudoPageState();
}

class _NovoEstudoPageState extends State<NovoEstudoPage> {
  late final EstudosService _estudosService =
      widget.studyService ?? EstudosService();
  late final RFProfileService _rfProfileService =
      widget.rfProfileService ?? RFProfileService();
  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(
    text: widget.study?['nome']?.toString(),
  );
  late final _descricaoController = TextEditingController(
    text: widget.study?['descricao']?.toString(),
  );
  late final _cidadeController = TextEditingController(
    text: widget.study?['municipio']?.toString() ?? widget.municipio,
  );
  late final _estadoController = TextEditingController(
    text: widget.study?['uf']?.toString() ?? widget.uf,
  );
  late final _bairroController = TextEditingController(
    text: widget.study?['bairro']?.toString() ?? widget.bairro,
  );

  RFProfile? _selectedRfProfile;
  bool _loadingRfProfiles = false;
  bool _loadingCriteria = false;
  InstallCriterion? _criterioSelecionado;
  late final InstallCriterionService _criterionService =
      widget.criterionService ?? InstallCriterionService();
  bool _salvando = false;
  bool _loadingSelections = false;
  int? _idEstudoCriado;
  final Set<int> _pontosSalvos = {};

  bool get _isEditing => widget.study != null;
  bool get _saveDisabled =>
      _salvando || _loadingRfProfiles || _loadingCriteria || _loadingSelections;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadSelections();
  }

  Future<void> _loadSelections() async {
    setState(() => _loadingSelections = true);
    try {
      final profile = await _rfProfileService.get(
        widget.study!['id_perfil_rf'] as int,
      );
      final criterion = await _criterionService.get(
        widget.study!['id_criterio_instalacao'] as int,
      );
      if (!mounted) return;
      setState(() {
        _selectedRfProfile = profile;
        _criterioSelecionado = criterion;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível carregar as seleções do estudo. Selecione o perfil RF e o critério novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSelections = false);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _bairroController.dispose();
    if (widget.criterionService == null) _criterionService.dispose();
    if (widget.rfProfileService == null) _rfProfileService.dispose();
    if (widget.studyService == null) _estudosService.dispose();
    super.dispose();
  }

  String _formatarNumero(double valor) {
    final texto = valor == valor.roundToDouble()
        ? valor.toStringAsFixed(0)
        : valor.toStringAsFixed(1);
    return texto.replaceAll('.', ',');
  }

  String get _descricaoArea {
    if (_isEditing && widget.study!['geom'] != null) {
      return 'Área do estudo preservada';
    }
    if (widget.pontosArea.isEmpty) return 'Área não definida';
    final local = widget.municipio ?? widget.distribuidora;
    return '$local · ${_formatarNumero(widget.areaKm2)} km²';
  }

  Future<void> _selectRfProfile() async {
    if (_salvando ||
        _loadingRfProfiles ||
        _loadingCriteria ||
        _loadingSelections) {
      return;
    }
    setState(() => _loadingRfProfiles = true);
    try {
      final profiles = <RFProfile>[];
      int page = 1;
      while (mounted) {
        final result = await _rfProfileService.list(
          userId: widget.userId,
          page: page,
          limit: 100,
        );
        profiles.addAll(result.items);
        if (!result.hasNext) break;
        page++;
      }
      if (!mounted) return;
      setState(() => _loadingRfProfiles = false);
      if (profiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nenhum perfil RF cadastrado. Crie um na Biblioteca.',
            ),
          ),
        );
        return;
      }
      await SelectionBottomSheet.show<int>(
        context: context,
        title: 'Selecionar perfil RF e gateway',
        searchHint: 'Buscar perfil RF pelo nome',
        notFoundMessage: 'Nenhum perfil RF encontrado',
        items: profiles
            .map(
              (profile) => SelectionItem(
                title: profile.name,
                subtitle: '${_formatarNumero(profile.frequencyMhz)} MHz',
                value: profile.id,
              ),
            )
            .toList(),
        selectedValue: _selectedRfProfile?.id,
        onSelected: (id) {
          if (id != null && mounted) {
            setState(
              () => _selectedRfProfile = profiles.firstWhere(
                (profile) => profile.id == id,
              ),
            );
          }
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível carregar os perfis RF. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRfProfiles = false);
    }
  }

  Future<void> _selectCriterion() async {
    if (_salvando ||
        _loadingRfProfiles ||
        _loadingCriteria ||
        _loadingSelections) {
      return;
    }
    setState(() => _loadingCriteria = true);
    try {
      final criteria = <InstallCriterion>[];
      int page = 1;
      while (mounted) {
        final result = await _criterionService.list(
          userId: widget.userId,
          page: page,
        );
        criteria.addAll(result.items);
        if (!result.hasNext) break;
        page++;
      }
      if (!mounted) return;
      setState(() => _loadingCriteria = false);
      if (criteria.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum critério cadastrado. Crie um na Biblioteca.'),
          ),
        );
        return;
      }
      await SelectionBottomSheet.show<int>(
        context: context,
        title: 'Selecionar critério de instalação',
        searchHint: 'Buscar critério pelo nome',
        notFoundMessage: 'Nenhum critério encontrado',
        items: criteria
            .map(
              (criterion) =>
                  SelectionItem(title: criterion.name, value: criterion.id),
            )
            .toList(),
        selectedValue: _criterioSelecionado?.id,
        onSelected: (id) {
          if (id != null && mounted) {
            setState(
              () => _criterioSelecionado = criteria.firstWhere(
                (criterion) => criterion.id == id,
              ),
            );
          }
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível carregar os critérios. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCriteria = false);
    }
  }

  String? _textoOuNulo(TextEditingController controller) {
    final texto = controller.text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _criarEstudo() async {
    if (_salvando ||
        _loadingRfProfiles ||
        _loadingCriteria ||
        _loadingSelections ||
        !_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRfProfile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um perfil RF.')));
      return;
    }

    if (_criterioSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um critério de instalação.')),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      if (_isEditing) {
        await _estudosService.update(widget.study!['id_estudo'] as int, {
          'id_perfil_rf': _selectedRfProfile!.id,
          'id_criterio_instalacao': _criterioSelecionado!.id,
          'nome': _nomeController.text.trim(),
          'descricao': _textoOuNulo(_descricaoController),
          'uf': _textoOuNulo(_estadoController)?.toUpperCase(),
          'municipio': _textoOuNulo(_cidadeController),
          'bairro': _textoOuNulo(_bairroController),
        });
      } else {
        var idEstudo = _idEstudoCriado;
        if (idEstudo == null) {
          final estudo = await _estudosService.criarEstudo(
            NovoEstudo(
              idUsuario: widget.userId,
              idRfProfile: _selectedRfProfile!.id,
              idCriterioInstalacao: _criterioSelecionado!.id,
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
          final id = estudo['id_estudo'];
          if (id is! num) {
            throw const FormatException(
              'A resposta da API não contém um id_estudo válido.',
            );
          }
          idEstudo = id.toInt();
          _idEstudoCriado = idEstudo;
        }
        for (var indice = 0; indice < widget.pontosArea.length; indice++) {
          if (_pontosSalvos.contains(indice)) continue;
          final ponto = widget.pontosArea[indice];
          await _estudosService.criarPontoEstudo(
            NovoEstudoPonto(
              idEstudo: idEstudo,
              latitude: ponto.latitude,
              longitude: ponto.longitude,
              relevoM: indice < widget.relevoPontos.length
                  ? widget.relevoPontos[indice]
                  : null,
              rotulo: 'Vértice ${indice + 1}',
              indice: indice,
            ),
          );
          _pontosSalvos.add(indice);
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _salvando = false);
      final mensagemErro = _idEstudoCriado == null
          ? 'Não foi possível ${_isEditing ? 'salvar' : 'criar'} o estudo: $erro'
          : 'Estudo criado. Não foi possível salvar todos os pontos: $erro';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagemErro),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCabecalho(desktop),
              if (_loadingSelections)
                const LinearProgressIndicator(color: AppColors.primaryLime),
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
                      titulo: _loadingRfProfiles
                          ? 'Carregando perfis RF...'
                          : _selectedRfProfile?.name ?? 'Selecionar perfil RF',
                      onTap: _selectRfProfile,
                      conteudo: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (_selectedRfProfile == null)
                            _buildDetalhe(
                              'Escolha um perfil cadastrado na Biblioteca.',
                            ),
                          if (_selectedRfProfile != null) ...[
                            _buildDetalhe(
                              '${_formatarNumero(_selectedRfProfile!.frequencyMhz)} MHz',
                            ),
                            _buildDetalhe(
                              '${_formatarNumero(_selectedRfProfile!.transmitPowerDbm)} dBm TX',
                            ),
                            _buildDetalhe(
                              '${_formatarNumero(_selectedRfProfile!.receiveSensitivityDbm)} dBm RX',
                            ),
                            if (_selectedRfProfile!.gatewayHeightM != null)
                              _buildDetalhe(
                                'Gateway ${_formatarNumero(_selectedRfProfile!.gatewayHeightM!)} m',
                                destaque: true,
                              ),
                            if (_selectedRfProfile!.deviceHeightM != null)
                              _buildDetalhe(
                                'Dispositivo ${_formatarNumero(_selectedRfProfile!.deviceHeightM!)} m',
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRotulo('CRITÉRIOS DE INSTALAÇÃO'),
                    _buildCardSelecao(
                      titulo: _loadingCriteria
                          ? 'Carregando critérios...'
                          : _criterioSelecionado?.name ?? 'Selecionar critério',
                      onTap: _selectCriterion,
                      conteudo: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_criterioSelecionado == null)
                            _buildDetalhe(
                              'Escolha um critério cadastrado na Biblioteca.',
                            ),
                          if (_criterioSelecionado?.maxDistanceMeters != null)
                            _buildEtiqueta(
                              'Dist. máx. ${_formatarNumero(_criterioSelecionado!.maxDistanceMeters!)} m',
                            ),
                          if (_criterioSelecionado?.gatewayLimit != null)
                            _buildEtiqueta(
                              'Máx. ${_criterioSelecionado!.gatewayLimit} gateways',
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
              if (!desktop) _buildRodape(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCabecalho(bool desktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _salvando ? null : () => Navigator.pop(context),
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
          Expanded(
            child: Text(
              _isEditing ? 'Editar estudo' : 'Novo estudo',
              style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!_isEditing && widget.pontosArea.isNotEmpty)
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
          if (desktop) ...[const SizedBox(width: 12), _buildAcoes()],
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
          if (!_isEditing)
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(child: _buildCancelar()),
            const SizedBox(width: 8),
            Expanded(child: _buildSalvar()),
          ],
        ),
      ),
    );
  }

  Widget _buildAcoes() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 8,
    children: [_buildCancelar(), const SizedBox(width: 12), _buildSalvar()],
  );

  Widget _buildCancelar() => SecondaryButton(
    label: 'Cancelar',
    onPressed: _salvando ? null : () => Navigator.pop(context),
  );

  Widget _buildSalvar() => PrimaryButton(
    label: _salvando
        ? 'Salvando...'
        : _isEditing
        ? 'Salvar alterações'
        : _idEstudoCriado == null
        ? 'Criar estudo e simular'
        : 'Continuar salvamento',
    onPressed: _saveDisabled ? null : _criarEstudo,
  );
}
