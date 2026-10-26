import 'package:flutter/material.dart';

import 'primary_button.dart';

class CriterionTypeDialog extends StatefulWidget {
  const CriterionTypeDialog({
    super.key,
    required this.availableItems,
    required this.existingItems,
    this.itemLabels = const {},
    this.existingItemLabels = const {},
    this.existingItemColors = const {},
    this.title = 'Adicionar tipo de ativo',
  });

  final List<String> availableItems;
  final Set<String> existingItems;
  final Map<String, String> itemLabels;
  final Map<String, String> existingItemLabels;
  final Map<String, Color> existingItemColors;
  final String title;

  @override
  State<CriterionTypeDialog> createState() => _CriterionTypeDialogState();
}

class _CriterionTypeDialogState extends State<CriterionTypeDialog> {
  final Set<String> _selectedItems = {};

  void _submit() {
    if (_selectedItems.isNotEmpty) {
      Navigator.pop(context, _selectedItems.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: widget.availableItems.isEmpty
                  ? const Text(
                      'Todos os tipos permitidos já foram adicionados.',
                    )
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.availableItems.length,
                        itemBuilder: (context, index) {
                          final option = widget.availableItems[index];
                          final alreadyAdded = widget.existingItems.contains(
                            option,
                          );
                          if (alreadyAdded) {
                            return ListTile(
                              enabled: false,
                              leading: const Icon(Icons.check_circle_outline),
                              title: Text(
                                widget.itemLabels[option] ??
                                    option.replaceAll('_', ' '),
                              ),
                              trailing: Text(
                                widget.existingItemLabels[option] ??
                                    'Já adicionado',
                                style: widget.existingItemColors[option] == null
                                    ? null
                                    : TextStyle(
                                        color:
                                            widget.existingItemColors[option],
                                      ),
                              ),
                            );
                          }
                          return ListTile(
                            leading: Checkbox(
                              value: _selectedItems.contains(option),
                              onChanged: (selected) => setState(() {
                                selected == true
                                    ? _selectedItems.add(option)
                                    : _selectedItems.remove(option);
                              }),
                            ),
                            title: Text(
                              widget.itemLabels[option] ??
                                  option.replaceAll('_', ' '),
                            ),
                            onTap: () => setState(() {
                              _selectedItems.contains(option)
                                  ? _selectedItems.remove(option)
                                  : _selectedItems.add(option);
                            }),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        PrimaryButton(
          label: 'Adicionar',
          onPressed: _selectedItems.isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
