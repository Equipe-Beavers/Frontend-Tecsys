import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth/auth_form_components.dart';
import '../widgets/primary_button.dart';
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) AuthNotice(message: _error!),
                        if (user == null) ...[
                          const Icon(
                            Icons.person_outline,
                            size: 48,
                            color: AppColors.secondaryTeal,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Sua conta Geomash',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Crie sua conta ou entre para acessar seu perfil.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              label: 'Criar conta',
                              onPressed: () => _openAuth(register: true),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _openAuth(),
                              child: const Text('Entrar'),
                            ),
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
                                    color: AppColors.primaryLime.withValues(
                                      alpha: .35,
                                    ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.username,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      user.email,
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
                          const Text(
                            'Dados da sua conta. A edição de perfil ainda não está disponível.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () =>
                                        _perform(widget.controller.refreshUser),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Atualizar dados'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _perform(widget.controller.logout),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: BorderSide(
                                  color: Colors.orange.withValues(alpha: .4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                              icon: const Icon(Icons.logout, size: 18),
                              label: const Text('Sair'),
                            ),
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
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(11),
        ),
        child: SelectableText(value, semanticsLabel: '$label: $value'),
      ),
    ],
  );
}
