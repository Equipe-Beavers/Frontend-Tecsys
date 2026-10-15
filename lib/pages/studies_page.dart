import 'package:flutter/material.dart';

import '../services/estudos_service.dart';
import '../services/install_criterion_service.dart';
import '../services/rf_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/name_filter.dart';
import '../widgets/library_record_card.dart';
import '../widgets/name_filter_field.dart';
import '../widgets/primary_button.dart';
import 'study_form.dart';

class StudiesPage extends StatefulWidget {
  const StudiesPage({
    super.key,
    this.service,
    this.criterionService,
    this.rfProfileService,
    this.isActive = true,
    this.userId = const int.fromEnvironment('APP_USER_ID', defaultValue: 1),
  });

  final EstudosService? service;
  final InstallCriterionService? criterionService;
  final RFProfileService? rfProfileService;
  final bool isActive;
  final int userId;

  @override
  State<StudiesPage> createState() => _StudiesPageState();
}

class _StudiesPageState extends State<StudiesPage> {
  late final EstudosService _service;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _studies = [];
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  static const _statusLabels = {
    'AGUARDANDO_SELECAO': 'Aguardando seleção',
    'DEFINITIVO': 'Definitivo',
    'CRIANDO_CENARIO': 'Criando cenário',
    'CENARIO_EM_RASCUNHO': 'Cenário em rascunho',
    'EM_COMPARACAO': 'Em comparação',
  };

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EstudosService();
    _load();
  }

  @override
  void didUpdateWidget(covariant StudiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && !_loading) _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final studies = await _service.list(userId: widget.userId);
      if (!mounted) return;
      setState(() => _studies = studies);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openStudy([Map<String, dynamic>? study]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selected = study == null
          ? null
          : await _service.get(study['id_estudo'] as int);
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => NovoEstudoPage(
            distribuidora: selected?['distribuidora']?.toString() ?? '',
            municipio: selected?['municipio']?.toString(),
            areaKm2: 0,
            pontosArea: const [],
            study: selected,
            studyService: _service,
            criterionService: widget.criterionService,
            rfProfileService: widget.rfProfileService,
            userId: selected?['id_usuario'] as int? ?? widget.userId,
          ),
        ),
      );
      if (saved == true && mounted) {
        _showMessage(
          study == null
              ? 'Estudo criado com sucesso.'
              : 'Estudo atualizado com sucesso.',
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is StudyApiException
              ? error.message
              : 'Não foi possível abrir o estudo. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteStudy(Map<String, dynamic> study) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir estudo?'),
        content: Text('“${study['nome']}” será excluído da lista de estudos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.delete(study['id_estudo'] as int);
      if (!mounted) return;
      _showMessage('Estudo excluído.');
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is StudyApiException
              ? error.message
              : 'Não foi possível excluir. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _message(IconData icon, String title, {bool retry = false}) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.secondaryTeal),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
          if (retry) ...[
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Tentar novamente',
              icon: Icons.refresh,
              onPressed: _load,
            ),
          ],
        ],
      ),
    ),
  );

  List<LibraryRecordParameter> _parameters(Map<String, dynamic> study) => [
    if (study['nome_criterio_instalacao']?.toString().trim().isNotEmpty == true)
      LibraryRecordParameter('Critério: ${study['nome_criterio_instalacao']}'),
    if (study['nome_perfil_rf']?.toString().trim().isNotEmpty == true)
      LibraryRecordParameter('Perfil RF: ${study['nome_perfil_rf']}'),
    for (final field in ['municipio', 'uf', 'bairro', 'distribuidora'])
      if (study[field] != null && study[field].toString().trim().isNotEmpty)
        LibraryRecordParameter(study[field].toString()),
    if (study['status'] != null)
      LibraryRecordParameter(
        _statusLabels[study['status']] ?? study['status'].toString(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final studies = _studies.where((study) {
      return matchesName(study['nome']?.toString() ?? '', query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Estudos',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
              PrimaryButton(
                label: 'Novo estudo',
                onPressed: _busy ? null : () => _openStudy(),
                icon: Icons.add,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: NameFilterField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            hintText: 'Buscar estudos',
          ),
        ),
        const SizedBox(height: 12),
        if (_busy)
          const LinearProgressIndicator(
            color: AppColors.primaryLime,
            minHeight: 2,
          ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLime,
                  ),
                )
              : _failed
              ? _message(
                  Icons.cloud_off_outlined,
                  'Não foi possível carregar os estudos',
                  retry: true,
                )
              : studies.isEmpty
              ? _message(
                  Icons.layers_outlined,
                  query.isEmpty
                      ? 'Nenhum estudo cadastrado'
                      : 'Nenhum estudo encontrado',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final columns = box.maxWidth >= 1300
                          ? 3
                          : box.maxWidth >= 700
                          ? 2
                          : 1;
                      final width =
                          (box.maxWidth - 44 - (columns - 1) * 16) / columns;
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(22),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final study in studies)
                              SizedBox(
                                width: width,
                                child: LibraryRecordCard(
                                  enabled: !_busy,
                                  onTap: () => _openStudy(study),
                                  actions: const [
                                    LibraryRecordAction(
                                      value: 'edit',
                                      label: 'Editar',
                                    ),
                                    LibraryRecordAction(
                                      value: 'delete',
                                      label: 'Excluir',
                                    ),
                                  ],
                                  onAction: (action) {
                                    if (action == 'edit') {
                                      _openStudy(study);
                                    } else {
                                      _deleteStudy(study);
                                    }
                                  },
                                  title:
                                      study['nome']?.toString() ?? 'Sem nome',
                                  parameters: _parameters(study),
                                  emptyMessage:
                                      study['descricao']?.toString() ??
                                      'Nenhuma informação adicional definida',
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
