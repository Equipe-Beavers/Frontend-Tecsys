import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class SelectionItem<T> {
  final String title;
  final T value;

  const SelectionItem({
    required this.title,
    required this.value,
  });
}

class SelectionBottomSheet<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<SelectionItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T> onSelected;

  const SelectionBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  static Future<void> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<SelectionItem<T>> items,
    required T? selectedValue,
    required ValueChanged<T> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SelectionBottomSheet<T>(
        title: title,
        subtitle: subtitle,
        items: items,
        selectedValue: selectedValue,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: subtitle != null
                  ? Text(
                      subtitle!,
                      style: const TextStyle(color: AppColors.textMuted),
                    )
                  : null,
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item.value == selectedValue;

                  return ListTile(
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.textWhite
                            : AppColors.textMuted,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: AppColors.primaryLime,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(item.value);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}