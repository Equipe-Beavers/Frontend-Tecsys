import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/auth_validation.dart';
import 'auth_form_components.dart';
import 'auth_shell.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.controller,
    required this.onRegister,
    required this.onAuthenticated,
    required this.onBack,
    this.initialEmail = '',
    this.registered = false,
  });
  final AuthController controller;
  final VoidCallback onRegister, onAuthenticated, onBack;
  final String initialEmail;
  final bool registered;
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.login(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      _password.clear();
      widget.onAuthenticated();
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível entrar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    return PopScope(
      canPop: !_busy,
      child: AutofillGroup(
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Voltar ao perfil',
                  onPressed: _busy ? null : widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              if (mobile) ...[
                const SizedBox(height: 30),
                const AuthBrand(),
                const SizedBox(height: 16),
                const Text(
                  'Planejamento e otimização de cobertura de RF para redes de distribuição.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
              ] else ...[
                const SizedBox(height: 16),
                const Text(
                  'Entrar',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Acesse sua conta para continuar os estudos.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 30),
              if (widget.registered)
                const AuthNotice(
                  message:
                      'Conta criada com sucesso! Entre com seu e-mail e senha.',
                  success: true,
                ),
              if (_error != null) AuthNotice(message: _error!),
              AuthField(
                key: const Key('login-email'),
                label: 'E-mail',
                controller: _email,
                email: true,
                validator: AuthValidation.email,
                enabled: !_busy,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
              ),
              const SizedBox(height: 20),
              AuthField(
                key: const Key('login-password'),
                label: 'Senha',
                controller: _password,
                password: true,
                enabled: !_busy,
                validator: (value) => value == null || value.isEmpty
                    ? 'Informe sua senha.'
                    : null,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Entrar',
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 10),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Não tem conta ainda?',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : widget.onRegister,
                      child: const Text('Cadastre-se'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
