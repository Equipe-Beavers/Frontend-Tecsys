import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../theme/app_colors.dart';

enum ChipColorVariant { primary, secondary }

class EditableChipField extends StatefulWidget {
  const EditableChipField({
    super.key,
    required this.defaultItems,
    required this.availableItems,
    this.excludedItems = const {},
    this.colorVariant = ChipColorVariant.primary,
    this.enabled = true,
    this.showAddButton = true,
    this.onRemove,
    this.onAdd,
    this.onItemsChanged,
    this.itemLabels = const {},
    this.allowCustom = false,
  });

  final bool allowCustom;
  final List<String> defaultItems;
  final List<String> availableItems;
  final Set<String> excludedItems;
  final ChipColorVariant colorVariant;
  final bool enabled;
  final bool showAddButton;
  final void Function(String)? onRemove;
  final Future<List<String>?> Function(
    List<String> availableItems,
    Set<String> existingItems,
  )?
  onAdd;
  final ValueChanged<List<String>>? onItemsChanged;
  final Map<String, String> itemLabels;

  @override
  State<EditableChipField> createState() => _EditableChipFieldState();
}

class _EditableChipFieldState extends State<EditableChipField> {
  late final List<String> _items;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _items = LinkedHashSet<String>.of(widget.defaultItems).toList();
  }

  @override
  void didUpdateWidget(covariant EditableChipField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.defaultItems, widget.defaultItems)) {
      _items
        ..clear()
        ..addAll(LinkedHashSet<String>.of(widget.defaultItems));
    }
  }

  void _removeItem(String item) {
    if (!widget.enabled) return;
    setState(() => _items.remove(item));
    widget.onRemove?.call(item);
    widget.onItemsChanged?.call(List.unmodifiable(_items));
  }

  Future<void> _addItem() async {
    if (!widget.enabled || _adding || widget.onAdd == null) return;
    if (widget.availableItems.isEmpty && !widget.allowCustom) return;
    setState(() => _adding = true);
    try {
      final selectedItems = await widget.onAdd!(
        List.unmodifiable(widget.availableItems),
        Set.unmodifiable({..._items, ...widget.excludedItems}),
      );
      if (!mounted || selectedItems == null) return;
      final newItems = LinkedHashSet<String>.of(selectedItems)
          .where(
            (item) =>
                item.trim().isNotEmpty &&
                (widget.allowCustom || widget.availableItems.contains(item)) &&
                !widget.excludedItems.contains(item) &&
                !_items.contains(item),
          )
          .toList();
      if (newItems.isEmpty) return;
      setState(() => _items.addAll(newItems));
      widget.onItemsChanged?.call(List.unmodifiable(_items));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCatalogItems =
        widget.availableItems.isNotEmpty || widget.allowCustom;
    final secondary = widget.colorVariant == ChipColorVariant.secondary;
    final chipBackground = secondary
        ? Colors.orange.withValues(alpha: .12)
        : AppColors.secondaryTeal;
    final chipBorder = secondary
        ? Colors.orange.withValues(alpha: .55)
        : AppColors.border;
    final chipForeground = secondary
        ? Colors.orange.shade300
        : AppColors.textDark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in _items)
          Chip(
            label: Text(
              widget.itemLabels[item] ?? item.replaceAll('_', ' '),
              style: TextStyle(color: chipForeground, fontSize: 12),
            ),
            backgroundColor: chipBackground,
            side: BorderSide(color: chipBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            deleteIcon: Icon(Icons.close, size: 15, color: chipForeground),
            onDeleted: widget.enabled ? () => _removeItem(item) : null,
          ),
        if (widget.showAddButton)
          ActionChip(
            avatar: const Icon(Icons.add, size: 15),
            label: const Text('Adicionar'),
            onPressed:
                widget.enabled &&
                    !_adding &&
                    widget.onAdd != null &&
                    hasCatalogItems
                ? _addItem
                : null,
          ),
      ],
    );
  }
}
