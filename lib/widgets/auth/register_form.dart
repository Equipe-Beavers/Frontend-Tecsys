import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/auth_validation.dart';
import 'auth_form_components.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({
    super.key,
    required this.service,
    required this.onRegistered,
    required this.onLogin,
    required this.onBack,
  });
  final AuthService service;
  final ValueChanged<String> onRegistered;
  final VoidCallback onLogin, onBack;
  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error, _emailError, _nameError;

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _emailError = null;
      _nameError = null;
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final user = await widget.service.register(
        username: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext(shouldSave: false);
      _password.clear();
      _confirmation.clear();
      widget.onRegistered(user.email);
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == 'EMAIL_ALREADY_EXISTS') {
          _emailError = error.message;
        } else if (error.code == 'USERNAME_ALREADY_EXISTS') {
          _nameError = error.message;
        } else {
          _error = error.message;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível criar sua conta. Tente novamente.',
        );
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
        onDisposeAction: AutofillContextAction.cancel,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : widget.onBack,
                    tooltip: 'Voltar',
                    icon: const Icon(Icons.arrow_back, size: 20),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Criar conta',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (mobile) const Spacer(flex: 2),
              SizedBox(height: mobile ? 48 : 28),
              if (_error != null) AuthNotice(message: _error!),
              AuthField(
                key: const Key('register-username'),
                label: 'Nome de usuário',
                controller: _name,
                validator: AuthValidation.username,
                enabled: !_busy,
                errorText: _nameError,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 20),
              AuthField(
                key: const Key('register-email'),
                label: 'E-mail',
                controller: _email,
                validator: AuthValidation.email,
                email: true,
                enabled: !_busy,
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  final password = AuthField(
                    key: const Key('register-password'),
                    label: 'Senha',
                    controller: _password,
                    validator: AuthValidation.password,
                    password: true,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.newPassword],
                  );
                  final confirmation = AuthField(
                    key: const Key('register-confirmation'),
                    label: 'Confirmar senha',
                    controller: _confirmation,
                    password: true,
                    enabled: !_busy,
                    validator: (value) =>
                        AuthValidation.confirmation(value, _password.text),
                    textInputAction: TextInputAction.done,
                    onSubmitted: _submit,
                    autofillHints: const [AutofillHints.newPassword],
                  );
                  // Preserve usable fields on narrow screens and at large text scales.
                  final screenWidth = MediaQuery.sizeOf(context).width;
                  if (screenWidth < 368 ||
                      (screenWidth >= 900 && screenWidth < 1040) ||
                      MediaQuery.textScalerOf(context).scale(14) > 18) {
                    return Column(
                      children: [
                        password,
                        const SizedBox(height: 20),
                        confirmation,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: password),
                      const SizedBox(width: 12),
                      Expanded(child: confirmation),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Use entre 8 e 128 caracteres na senha.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              if (mobile) const Spacer(flex: 3),
              SizedBox(height: mobile ? 36 : 24),
              AuthSubmitButton(
                label: 'Criar conta',
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Já tem conta?',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : widget.onLogin,
                      child: const Text('Entrar'),
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
