import 'package:flutter/material.dart';

import '../controllers/rf_profile_page_controller.dart';
import '../models/rf_profile.dart';
import '../services/rf_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/library_record_card.dart';
import '../widgets/name_filter_field.dart';
import '../widgets/primary_button.dart';

class RFProfileLibrarySection extends StatefulWidget {
  const RFProfileLibrarySection({
    super.key,
    required this.service,
    required this.userId,
    required this.onCreate,
    required this.onOpen,
  });

  final RFProfileService service;
  final int userId;
  final VoidCallback onCreate;
  final ValueChanged<RFProfile> onOpen;

  @override
  State<RFProfileLibrarySection> createState() =>
      _RFProfileLibrarySectionState();
}

class _RFProfileLibrarySectionState extends State<RFProfileLibrarySection> {
  late final RFProfilePageController _controller;
  final _searchController = TextEditingController();
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _controller = RFProfilePageController(
      service: widget.service,
      userId: widget.userId,
    )..addListener(_pageChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller
      ..removeListener(_pageChanged)
      ..dispose();
    super.dispose();
  }

  void _pageChanged() {
    if (mounted) setState(() {});
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString().replaceAll('.', ',');

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _delete(RFProfile profile) async {
    if (_controller.loading || _deleting) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir perfil RF?'),
        content: Text('“${profile.name}” será excluído da biblioteca.'),
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
    setState(() => _deleting = true);
    try {
      await widget.service.delete(profile.id);
      if (!mounted) return;
      _message('Perfil RF excluído.');
      await _controller.load();
    } catch (error) {
      if (mounted) {
        _message(
          error is RFProfileApiException
              ? error.message
              : 'Não foi possível excluir. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _card(RFProfile profile, double width) => SizedBox(
    width: width,
    child: LibraryRecordCard(
      title: profile.name,
      onTap: _deleting ? null : () => widget.onOpen(profile),
      enabled: !_deleting,
      actions: const [
        LibraryRecordAction(value: 'edit', label: 'Editar'),
        LibraryRecordAction(value: 'delete', label: 'Excluir'),
      ],
      onAction: (action) {
        if (action == 'edit') {
          widget.onOpen(profile);
        } else {
          _delete(profile);
        }
      },
      parameters: [
        LibraryRecordParameter('${_format(profile.frequencyMhz)} MHz'),
        LibraryRecordParameter('TX ${_format(profile.transmitPowerDbm)} dBm'),
        LibraryRecordParameter(
          'RX ${_format(profile.receiveSensitivityDbm)} dBm',
        ),
        if (profile.gatewayHeightM != null)
          LibraryRecordParameter(
            'Gateway ${_format(profile.gatewayHeightM!)} m',
          ),
        if (profile.deviceHeightM != null)
          LibraryRecordParameter(
            'Dispositivo ${_format(profile.deviceHeightM!)} m',
          ),
        if (profile.maximumEquipment != null)
          LibraryRecordParameter(
            'Máx. ${profile.maximumEquipment} equipamentos',
          ),
      ],
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

  Widget _pagination() {
    if (_controller.page == 1 && !_controller.hasNext) {
      return const SizedBox.shrink();
    }
    final active = !_controller.loading;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Página anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: active && _controller.page > 1
                ? () => _controller.load(targetPage: _controller.page - 1)
                : null,
          ),
          Flexible(
            child: Text(
              'Página ${_controller.page}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          IconButton(
            tooltip: 'Próxima página',
            icon: const Icon(Icons.chevron_right),
            onPressed: active && _controller.hasNext
                ? () => _controller.load(targetPage: _controller.page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: NameFilterField(
          controller: _searchController,
          onChanged: _controller.search,
          hintText: 'Buscar perfil RF pelo nome',
        ),
      ),
      if (_deleting || (_controller.loading && _controller.items.isNotEmpty))
        const LinearProgressIndicator(
          color: AppColors.primaryLime,
          minHeight: 2,
        ),
      Expanded(
        child:
            _controller.loading &&
                (_controller.items.isEmpty ||
                    _searchController.text.trim().isNotEmpty)
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryLime),
              )
            : _controller.error != null &&
                  (_controller.items.isEmpty ||
                      _searchController.text.trim().isNotEmpty)
            ? _stateMessage(
                Icons.cloud_off_outlined,
                'Não foi possível carregar',
                _controller.error!,
                'Tentar novamente',
                _controller.retry,
              )
            : _controller.items.isEmpty
            ? _searchController.text.trim().isNotEmpty
                  ? const Center(child: Text('Nenhum perfil RF encontrado'))
                  : _stateMessage(
                      Icons.settings_input_antenna_outlined,
                      'Nenhum perfil RF cadastrado',
                      'Adicione um perfil para configurar as características de rádio.',
                      'Novo Perfil RF',
                      widget.onCreate,
                    )
            : RefreshIndicator(
                onRefresh: () => _controller.load(),
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
                        children: _controller.items
                            .map((profile) => _card(profile, width))
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
      ),
      if (_searchController.text.trim().isEmpty) _pagination(),
    ],
  );
}
