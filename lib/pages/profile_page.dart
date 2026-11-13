import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth/auth_form_components.dart';
import 'auth_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.controller});
  final AuthController controller;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;
  String? _error;

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível concluir a operação. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAuth({bool register = false}) async {
    setState(() => _error = null);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AuthPage(controller: widget.controller, register: register),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final user = widget.controller.user;
      return ColoredBox(
        color: AppColors.surfaceBackground,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: const Text(
                'Perfil',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight > 48
                          ? constraints.maxHeight - 48
                          : 0,
                    ),
                    child: Align(
                      alignment: user == null
                          ? Alignment.center
                          : Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: user == null ? 480 : 520,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: user == null
                              ? EdgeInsets.all(
                                  constraints.maxWidth < 480 ? 20 : 28,
                                )
                              : EdgeInsets.zero,
                          decoration: user == null
                              ? BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .18,
                                      ),
                                      blurRadius: 32,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                )
                              : null,
                          child: Column(
                            crossAxisAlignment: user == null
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              if (_error != null) AuthNotice(message: _error!),
                              if (widget.controller.restoreError != null) ...[
                                AuthNotice(
                                  message: widget.controller.restoreError!,
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                            _perform(widget.controller.restore),
                                  child: const Text('Tentar restaurar sessão'),
                                ),
                              ],
                              if (user == null) ...[
                                const Icon(
                                  Icons.person_outline,
                                  size: 48,
                                  color: AppColors.secondaryTeal,
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Sua conta Geomash',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Crie sua conta ou entre para acessar seu perfil.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 160,
                                        ),
                                        child: SizedBox(
                                          width: 160,
                                          height: 48,
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryLime,
                                              foregroundColor:
                                                  AppColors.textDark,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () =>
                                                _openAuth(register: true),
                                            child: const Text(
                                              'Criar conta',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 160,
                                        ),
                                        child: SizedBox(
                                          width: 160,
                                          height: 48,
                                          child: OutlinedButton(
                                            onPressed: () => _openAuth(),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(140, 48),
                                              side: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text('Entrar'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 62,
                                      height: 62,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLime.withValues(
                                          alpha: .12,
                                        ),
                                        border: Border.all(
                                          color: AppColors.primaryLime
                                              .withValues(alpha: .35),
                                        ),
                                        borderRadius: BorderRadius.circular(19),
                                      ),
                                      child: Text(
                                        user.initials,
                                        style: const TextStyle(
                                          color: AppColors.primaryLime,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.username,
                                            textAlign: TextAlign.left,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            user.email,
                                            textAlign: TextAlign.left,
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
                                _ReadOnlyProfileField(
                                  label: 'Nome de usuário',
                                  value: user.username,
                                ),
                                const SizedBox(height: 24),
                                _ReadOnlyProfileField(
                                  label: 'E-mail',
                                  value: user.email,
                                ),
                                const SizedBox(height: 24),
                                Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _perform(
                                                widget.controller.logout,
                                              ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                          side: BorderSide(
                                            color: Colors.orange.withValues(
                                              alpha: .4,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.logout,
                                          size: 18,
                                        ),
                                        label: const Text('Sair'),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_busy)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: LinearProgressIndicator(
                                      semanticsLabel: 'Aguarde',
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ReadOnlyProfileField extends StatelessWidget {
  const _ReadOnlyProfileField({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          letterSpacing: 1.5,
          fontSize: 10,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(11),
        ),
        child: SelectableText(
          value,
          textAlign: TextAlign.left,
          semanticsLabel: '$label: $value',
        ),
      ),
    ],
  );
}
