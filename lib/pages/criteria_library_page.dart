import 'package:flutter/material.dart';

import '../models/install_criterion.dart';
import '../controllers/criteria_page_controller.dart';
import '../widgets/criteria_pagination.dart';
import '../services/install_criterion_service.dart';
import '../theme/app_colors.dart';
import '../widgets/criterion_components.dart';
import 'install_criterion_form.dart';

class CriteriaLibraryPage extends StatefulWidget {
  const CriteriaLibraryPage({
    super.key,
    this.service,
    this.onEditingChanged,
    this.userId = const int.fromEnvironment('APP_USER_ID', defaultValue: 1),
  });
  final InstallCriterionService? service;
  final int userId;
  final ValueChanged<bool>? onEditingChanged;
  @override
  State<CriteriaLibraryPage> createState() => _CriteriaLibraryPageState();
}

class _CriteriaLibraryPageState extends State<CriteriaLibraryPage> {
  late final InstallCriterionService _service;
  late final CriteriaPageController _pagination;
  bool _editing = false;
  bool _busy = false;
  InstallCriterion? _selected;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? InstallCriterionService();
    _pagination = CriteriaPageController(
      service: _service,
      userId: widget.userId,
    );
    _pagination.addListener(_pageChanged);
    _pagination.load();
  }

  @override
  void dispose() {
    _pagination.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  void _pageChanged() {
    if (mounted) setState(() {});
  }

  void _closeEditor() {
    setState(() {
      _editing = false;
      _selected = null;
    });
    widget.onEditingChanged?.call(false);
  }

  Future<void> _open([InstallCriterion? criterion]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selected = criterion == null
          ? null
          : await _service.get(criterion.id);
      if (!mounted) return;
      setState(() {
        _selected = selected;
        _editing = true;
      });
      widget.onEditingChanged?.call(true);
    } catch (_) {
      if (mounted) {
        _message('Não foi possível abrir o critério. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _delete(InstallCriterion criterion) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir critério?'),
        content: Text('“${criterion.name}” será excluído da biblioteca.'),
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
      await _service.delete(criterion.id);
      if (!mounted) return;
      _message('Critério excluído.');
      await _pagination.load();
    } catch (error) {
      if (mounted) {
        _message(
          error is CriterionApiException
              ? error.message
              : 'Não foi possível excluir. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(InstallCriterion criterion, double width) {
    final tags = <Widget>[
      for (final type in criterion.labels(CriterionCollection.allowedTypes))
        CriterionTag(criterionAssetTypes[type] ?? type.replaceAll('_', ' ')),
      for (final type in criterion.labels(CriterionCollection.blockedTypes))
        CriterionTag(
          'Bloqueado: ${criterionAssetTypes[type] ?? type.replaceAll('_', ' ')}',
          warning: true,
        ),
      if (criterion.requiresPower == true)
        const CriterionTag('Requer alimentação'),
      if (criterion.requiresPower == false)
        const CriterionTag('Alimentação não obrigatória'),
      if (criterion.maxDistanceMeters != null)
        CriterionTag('Dist. máx. ${criterion.distanceMetersLabel} m'),
      if (criterion.gatewayLimit != null)
        CriterionTag('Máx. ${criterion.gatewayLimit} gateways', warning: true),
      for (final field in CriterionCollection.values.where(
        (field) => field.isLocation,
      ))
        if (criterion.selectionCount(field) > 0)
          CriterionTag('${field.label}: ${criterion.selectionCount(field)}'),
    ];
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.surfaceCardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : () => _open(criterion),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        criterion.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !_busy,
                      tooltip: 'Ações de ${criterion.name}',
                      onSelected: (action) {
                        if (action == 'edit') {
                          _open(criterion);
                        } else {
                          _delete(criterion);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (tags.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 7, children: tags)
                else
                  const Text(
                    'Nenhuma restrição adicional definida',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return InstallCriterionForm(
        criterion: _selected,
        userId: widget.userId,
        onClose: _closeEditor,
        onSave: (values) async {
          await _service.save(values, id: _selected?.id);
          if (!mounted) return;
          _closeEditor();
          _message('Critério salvo com sucesso.');
          await _pagination.load(targetPage: 1);
        },
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxWidth < 800;
              final title = const Text(
                'Biblioteca',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              );
              final create = CriterionPrimaryButton(
                label: compact ? 'Novo' : 'Novo critério',
                icon: Icons.add,
                onPressed: _busy ? null : () => _open(),
              );
              final tabs = Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCardLight,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLime,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'Critérios',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Tooltip(
                        message:
                            'Configuração de perfis de RF em uma próxima etapa',
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          child: Text(
                            'Perfis de RF',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (compact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 12),
                        create,
                      ],
                    ),
                    const SizedBox(height: 16),
                    tabs,
                  ],
                );
              }
              return Row(
                children: [
                  title,
                  const SizedBox(width: 24),
                  SizedBox(width: 280, child: tabs),
                  const Spacer(),
                  create,
                ],
              );
            },
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        if (_busy || (_pagination.loading && _pagination.items.isNotEmpty))
          const LinearProgressIndicator(
            color: AppColors.primaryLime,
            minHeight: 2,
          ),
        if (_pagination.error != null && _pagination.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_pagination.error!),
                TextButton(
                  onPressed: _pagination.loading ? null : _pagination.retry,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _pagination.loading && _pagination.items.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLime,
                  ),
                )
              : _pagination.error != null && _pagination.items.isEmpty
              ? _stateMessage(
                  Icons.cloud_off_outlined,
                  'Não foi possível carregar',
                  _pagination.error!,
                  'Tentar novamente',
                  _pagination.retry,
                )
              : _pagination.items.isEmpty
              ? _stateMessage(
                  Icons.library_books_outlined,
                  'Sua biblioteca começa aqui',
                  'Crie critérios de instalação para reutilizar nos seus estudos.',
                  'Criar primeiro critério',
                  () => _open(),
                )
              : RefreshIndicator(
                  onRefresh: () => _pagination.load(),
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
                          children: _pagination.items
                              .map((item) => _card(item, width))
                              .toList(),
                        ),
                      );
                    },
                  ),
                ),
        ),
        CriteriaPagination(controller: _pagination, enabled: !_busy),
      ],
    );
  }

  Widget _stateMessage(
    IconData icon,
    String title,
    String description,
    String action,
    VoidCallback onTap,
  ) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
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
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            CriterionPrimaryButton(label: action, onPressed: onTap),
          ],
        ),
      ),
    ),
  );
}
