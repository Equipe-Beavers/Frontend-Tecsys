import 'package:flutter/material.dart';

import '../controllers/criteria_page_controller.dart';
import '../models/install_criterion.dart';
import '../services/install_criterion_service.dart';
import '../theme/app_colors.dart';
import '../widgets/criteria_pagination.dart';
import '../widgets/library_record_card.dart';
import '../widgets/primary_button.dart';

class InstallCriterionLibrarySection extends StatefulWidget {
  const InstallCriterionLibrarySection({
    super.key,
    required this.service,
    required this.userId,
    required this.busy,
    required this.onBusyChanged,
    required this.onCreate,
    required this.onOpen,
  });

  final InstallCriterionService service;
  final int userId;
  final bool busy;
  final ValueChanged<bool> onBusyChanged;
  final VoidCallback onCreate;
  final ValueChanged<InstallCriterion?> onOpen;

  @override
  State<InstallCriterionLibrarySection> createState() =>
      _InstallCriterionLibrarySectionState();
}

class _InstallCriterionLibrarySectionState
    extends State<InstallCriterionLibrarySection> {
  late final CriteriaPageController _pagination;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _pagination = CriteriaPageController(
      service: widget.service,
      userId: widget.userId,
    )..addListener(_pageChanged);
    _pagination.load();
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_pageChanged)
      ..dispose();
    super.dispose();
  }

  void _pageChanged() {
    if (mounted) setState(() {});
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _delete(InstallCriterion criterion) async {
    if (widget.busy || _deleting) return;
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
    widget.onBusyChanged(true);
    setState(() => _deleting = true);
    try {
      await widget.service.delete(criterion.id);
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
      widget.onBusyChanged(false);
      if (mounted) setState(() => _deleting = false);
    }
  }

  List<LibraryRecordParameter> _parameters(InstallCriterion criterion) => [
    for (final type in criterion.labels(CriterionCollection.allowedTypes))
      LibraryRecordParameter(
        criterionAssetTypes[type] ?? type.replaceAll('_', ' '),
      ),
    if (criterion.requiresPower == true)
      const LibraryRecordParameter('Requer alimentação'),
    if (criterion.requiresPower == false)
      const LibraryRecordParameter('Alimentação não obrigatória'),
    if (criterion.minDistanceMeters != null)
      LibraryRecordParameter(
        criterion.maxDistanceMeters == null
            ? 'Dist. mín. ${criterion.minDistanceMeters} m'
            : 'Dist. ${criterion.minDistanceMeters}–${criterion.distanceMetersLabel} m',
      )
    else if (criterion.maxDistanceMeters != null)
      LibraryRecordParameter('Dist. máx. ${criterion.distanceMetersLabel} m'),
    if (criterion.gatewayLimit != null)
      LibraryRecordParameter(
        'Máx. ${criterion.gatewayLimit} gateways',
        warning: true,
      ),
  ];

  Widget _card(InstallCriterion criterion, double width) => SizedBox(
    width: width,
    child: LibraryRecordCard(
      title: criterion.name,
      parameters: _parameters(criterion),
      onTap: () => widget.onOpen(criterion),
      enabled: !widget.busy && !_deleting,
      actions: const [
        LibraryRecordAction(value: 'edit', label: 'Editar'),
        LibraryRecordAction(value: 'delete', label: 'Excluir'),
      ],
      onAction: (action) {
        if (action == 'edit') {
          widget.onOpen(criterion);
        } else {
          _delete(criterion);
        }
      },
      emptyMessage: 'Nenhuma restrição adicional definida',
    ),
  );

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
            PrimaryButton(label: action, onPressed: onTap),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.busy ||
          _deleting ||
          (_pagination.loading && _pagination.items.isNotEmpty))
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
                child: CircularProgressIndicator(color: AppColors.primaryLime),
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
                widget.onCreate,
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
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          spacing: 16,
                          runSpacing: 16,
                          children: _pagination.items
                              .map((item) => _card(item, width))
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      CriteriaPagination(
        controller: _pagination,
        enabled: !widget.busy && !_deleting,
      ),
    ],
  );
}
