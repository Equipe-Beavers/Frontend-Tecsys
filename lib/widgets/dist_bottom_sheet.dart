import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class SelectionItem<T> {
  final String title;
  final String? subtitle;
  final T value;

  const SelectionItem({
    required this.title,
    this.subtitle,
    required this.value,
  });
}

class SelectionBottomSheet<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? stepLabel;
  final String searchHint;
  final String notFoundMessage;
  final List<SelectionItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T?> onSelected;

  const SelectionBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.stepLabel,
    this.searchHint = 'Buscar',
    this.notFoundMessage = 'Não encontrada',
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  static Future<void> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    String? stepLabel,
    String searchHint = 'Buscar',
    String notFoundMessage = 'Não encontrada',
    required List<SelectionItem<T>> items,
    required T? selectedValue,
    required ValueChanged<T?> onSelected,
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
        stepLabel: stepLabel,
        searchHint: searchHint,
        notFoundMessage: notFoundMessage,
        items: items,
        selectedValue: selectedValue,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<SelectionBottomSheet<T>> createState() =>
      _SelectionBottomSheetState<T>();
}

class _SelectionBottomSheetState<T> extends State<SelectionBottomSheet<T>> {
  final TextEditingController _buscaController = TextEditingController();
  String _busca = '';
  T? _selecionado;

  @override
  void initState() {
    super.initState();
    _selecionado = widget.selectedValue;
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<SelectionItem<T>> get _itensFiltrados {
    if (_busca.trim().isEmpty) return widget.items;
    final termo = _busca.trim().toLowerCase();
    return widget.items
        .where((item) => item.title.toLowerCase().contains(termo))
        .toList();
  }

  // IMPORTANTE:
  // Quando não há itens carregados (falha na API, por exemplo),
  // o botão "Prosseguir" continua habilitado, permitindo avançar
  // no fluxo mesmo sem selecionar nada.
  bool get _podeProsseguir =>
      _selecionado != null || widget.items.isEmpty;

  @override
  Widget build(BuildContext context) {
    final itens = _itensFiltrados;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.stepLabel != null)
                    Text(
                      widget.stepLabel!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _buscaController,
                onChanged: (valor) => setState(() => _busca = valor),
                style: const TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceInput,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Flexible(
              child: itens.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 20,
                      ),
                      child: Center(
                        child: Text(
                          widget.notFoundMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: itens.length,
                      itemBuilder: (context, index) {
                        final item = itens[index];
                        final isSelected = item.value == _selecionado;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.surfaceCardLight
                                : AppColors.surfaceBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryLime.withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: item.subtitle != null
                                ? Text(
                                    item.subtitle!,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: AppColors.primaryLime,
                            ),
                            onTap: () {
                              setState(() => _selecionado = item.value);
                            },
                          ),
                        );
                      },
                    ),
            ),

            if (widget.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Você pode prosseguir mesmo sem selecionar — os dados serão carregados assim que a conexão for restabelecida.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),

            const Divider(color: AppColors.borderSubtle, height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _podeProsseguir
                      ? () {
                          Navigator.pop(context);
                          widget.onSelected(_selecionado);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLime,
                    foregroundColor: AppColors.textDark,
                    disabledBackgroundColor: AppColors.border,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Prosseguir',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}