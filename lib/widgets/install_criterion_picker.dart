import 'package:flutter/material.dart';

import '../controllers/criteria_page_controller.dart';
import '../services/install_criterion_service.dart';
import '../theme/app_colors.dart';
import 'criteria_pagination.dart';

class InstallCriterionPicker extends StatefulWidget {
  const InstallCriterionPicker({
    super.key,
    required this.service,
    required this.userId,
    this.selectedId,
  });
  final InstallCriterionService service;
  final int userId;
  final int? selectedId;
  @override
  State<InstallCriterionPicker> createState() => _InstallCriterionPickerState();
}

class _InstallCriterionPickerState extends State<InstallCriterionPicker> {
  late final CriteriaPageController _controller;
  @override
  void initState() {
    super.initState();
    _controller = CriteriaPageController(
      service: widget.service,
      userId: widget.userId,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Selecionar critério de instalação',
                style: TextStyle(fontSize: 18),
              ),
            ),
            if (_controller.loading)
              const LinearProgressIndicator(color: AppColors.primaryLime),
            if (_controller.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_controller.error!),
                    TextButton(
                      onPressed: _controller.loading ? null : _controller.retry,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child:
                  !_controller.loading &&
                      _controller.error == null &&
                      _controller.items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum critério cadastrado. Crie um na Biblioteca.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _controller.items.length,
                      itemBuilder: (context, index) {
                        final item = _controller.items[index];
                        return ListTile(
                          title: Text(item.name),
                          selected: item.id == widget.selectedId,
                          trailing: item.id == widget.selectedId
                              ? const Icon(Icons.check)
                              : null,
                          onTap: _controller.loading
                              ? null
                              : () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
            CriteriaPagination(controller: _controller),
          ],
        ),
      ),
    ),
  );
}
