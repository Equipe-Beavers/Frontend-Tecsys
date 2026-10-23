import 'package:flutter/material.dart';

import '../models/install_criterion.dart';
import '../models/rf_profile.dart';
import '../services/install_criterion_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import 'install_criterion_library_section.dart';
import 'install_criterion_form.dart';
import 'rf_profile_form.dart';
import 'rf_profile_library_section.dart';
import '../services/rf_profile_service.dart';

class CriteriaLibraryPage extends StatefulWidget {
  const CriteriaLibraryPage({
    super.key,
    this.service,
    this.rfProfileService,
    this.onEditingChanged,
    this.userId = const int.fromEnvironment('APP_USER_ID', defaultValue: 1),
  });
  final InstallCriterionService? service;
  final RFProfileService? rfProfileService;
  final int userId;
  final ValueChanged<bool>? onEditingChanged;
  @override
  State<CriteriaLibraryPage> createState() => _CriteriaLibraryPageState();
}

class _CriteriaLibraryPageState extends State<CriteriaLibraryPage> {
  late final InstallCriterionService _service;
  late final RFProfileService _rfProfileService;
  bool _editing = false;
  bool _editingRfProfile = false;
  bool _showRfProfiles = false;
  bool _busy = false;
  InstallCriterion? _selected;
  RFProfile? _selectedRfProfile;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? InstallCriterionService();
    _rfProfileService = widget.rfProfileService ?? RFProfileService();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    if (widget.rfProfileService == null) _rfProfileService.dispose();
    super.dispose();
  }

  void _closeEditor() {
    setState(() {
      _editing = false;
      _selected = null;
    });
    widget.onEditingChanged?.call(false);
  }

  Future<void> _openRfProfileForm([RFProfile? profile]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selected = profile == null
          ? null
          : await _rfProfileService.get(profile.id);
      if (!mounted) return;
      setState(() {
        _selectedRfProfile = selected;
        _editingRfProfile = true;
      });
      widget.onEditingChanged?.call(true);
    } catch (_) {
      if (mounted) {
        _message('Não foi possível abrir o perfil RF. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _closeRfProfileForm() {
    setState(() {
      _editingRfProfile = false;
      _selectedRfProfile = null;
    });
    widget.onEditingChanged?.call(false);
  }

  Widget _libraryTab(String label, bool selected, VoidCallback onTap) =>
      Expanded(
        child: Material(
          color: selected ? AppColors.primaryLime : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? AppColors.textDark : AppColors.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );

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
        },
      );
    }
    if (_editingRfProfile) {
      return RFProfileForm(
        profile: _selectedRfProfile,
        userId: widget.userId,
        onClose: _closeRfProfileForm,
        calculateRange: _rfProfileService.calculateRange,
        onSave: (values) async {
          final editing = _selectedRfProfile != null;
          await _rfProfileService.save(values, id: _selectedRfProfile?.id);
          if (!mounted) return;
          _closeRfProfileForm();
          _message(
            editing
                ? 'Perfil RF atualizado com sucesso.'
                : 'Perfil RF salvo com sucesso.',
          );
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
              final mobile = box.maxWidth < 600;
              final title = const Text(
                'Biblioteca',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              );
              final createCriterion = PrimaryButton(
                label: mobile ? 'Novo' : 'Novo critério',
                icon: Icons.add,
                onPressed: _busy ? null : () => _open(),
              );
              final createRfProfile = PrimaryButton(
                label: 'Novo Perfil RF',
                icon: Icons.add,
                onPressed: _busy ? null : () => _openRfProfileForm(),
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
                    _libraryTab(
                      'Critérios',
                      !_showRfProfiles,
                      () => setState(() => _showRfProfiles = false),
                    ),
                    _libraryTab(
                      'Perfis de RF',
                      _showRfProfiles,
                      () => setState(() => _showRfProfiles = true),
                    ),
                  ],
                ),
              );
              if (mobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 16),
                        _showRfProfiles ? createRfProfile : createCriterion,
                      ],
                    ),
                    const SizedBox(height: 16),
                    tabs,
                  ],
                );
              }
              if (compact) {
                return Column(
                  children: [
                    Row(children: [Expanded(child: title)]),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        _showRfProfiles ? createRfProfile : createCriterion,
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
                  _showRfProfiles ? createRfProfile : createCriterion,
                ],
              );
            },
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _showRfProfiles
              ? RFProfileLibrarySection(
                  service: _rfProfileService,
                  userId: widget.userId,
                  onCreate: () => _openRfProfileForm(),
                  onOpen: (profile) => _openRfProfileForm(profile),
                )
              : InstallCriterionLibrarySection(
                  service: _service,
                  userId: widget.userId,
                  busy: _busy,
                  onBusyChanged: (busy) {
                    if (mounted) setState(() => _busy = busy);
                  },
                  onCreate: () => _open(),
                  onOpen: (criterion) => _open(criterion),
                ),
        ),
      ],
    );
  }
}
