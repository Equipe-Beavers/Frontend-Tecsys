import 'package:flutter/material.dart';

class CriterionTypeDialog extends StatefulWidget {
  const CriterionTypeDialog({super.key, required this.blocked});
  final bool blocked;
  @override
  State<CriterionTypeDialog> createState() => _CriterionTypeDialogState();
}

class _CriterionTypeDialogState extends State<CriterionTypeDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      Navigator.pop(
        context,
        value.toUpperCase().replaceAll(RegExp(r'\s+'), '_'),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.blocked ? 'Adicionar tipo bloqueado' : 'Adicionar tipo permitido',
    ),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 60,
      onSubmitted: (_) => _submit(),
      decoration: const InputDecoration(
        labelText: 'Tipo de estrutura',
        hintText: 'Ex.: Estruturas provisórias',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(onPressed: _submit, child: const Text('Adicionar')),
    ],
  );
}
