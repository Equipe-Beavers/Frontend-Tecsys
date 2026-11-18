import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import '../utils/auth_validation.dart';
import '../widgets/auth/auth_form_components.dart';
import '../widgets/auth/auth_shell.dart';
import 'auth_page.dart';
import '../widgets/auth/auth_loading_screen.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    super.key,
    required this.controller,
    this.token,
    this.initialEmail = '',
  });
  final AuthController controller;
  final String? token;
  final String initialEmail;
  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false, _success = false, _requestAnother = false;
  String? _error;
  bool get _reset => widget.token != null && !_requestAnother;
  bool get _invalidToken =>
      _reset && !RegExp(r'^[a-f0-9]{64}$').hasMatch(widget.token!);

  @override
  void initState() {
    super.initState();
    if (_invalidToken) {
      _error = 'Este link é inválido. Solicite outro link de recuperação.';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AuthPage(controller: widget.controller),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_busy || _invalidToken || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_reset) {
        await widget.controller.resetPassword(
          token: widget.token!,
          password: _password.text,
        );
      } else {
        await widget.controller.requestPasswordReset(_email.text);
      }
      if (mounted) {
        setState(() {
          _success = true;
          _password.clear();
          _confirmation.clear();
        });
      }
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

  @override
  Widget build(BuildContext context) => AuthLoadingHost(
    controller: widget.controller,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => AuthShell(
    child: PopScope(
      canPop: !_busy,
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: _busy ? null : _back,
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(height: 20),
            Text(
              _reset ? 'Redefinir senha' : 'Recuperar senha',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_error != null) AuthNotice(message: _error!),
            if (_success) ...[
              AuthNotice(
                success: true,
                message: _reset
                    ? 'Senha alterada com sucesso. Entre novamente com sua nova senha.'
                    : 'Se houver uma conta com esse e-mail, enviaremos as instruções para redefinir a senha. Confira também a pasta de spam.',
              ),
              AuthSubmitButton(
                label: _reset ? 'Voltar para entrar' : 'Voltar',
                busy: false,
                onPressed: _back,
              ),
            ] else ...[
              Text(
                _reset ? 'Escolha uma nova senha com 8 a 128 caracteres.' : 'Informe o e-mail cadastrado para receber um link de recuperação.',
              ),
              const SizedBox(height: 24),
              if (_reset) ...[
                AuthField(
                  key: const Key('reset-password'),
                  label: 'Nova senha',
                  controller: _password,
                  password: true,
                  enabled: !_busy,
                  validator: AuthValidation.password,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 20),
                AuthField(
                  key: const Key('reset-confirmation'),
                  label: 'Confirmar senha',
                  controller: _confirmation,
                  password: true,
                  enabled: !_busy,
                  validator: (value) =>
                      AuthValidation.confirmation(value, _password.text),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                ),
              ] else
                AuthField(
                  key: const Key('recovery-email'),
                  label: 'E-mail',
                  controller: _email,
                  email: true,
                  enabled: !_busy,
                  validator: AuthValidation.email,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                ),
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: _reset ? 'Salvar nova senha' : 'Enviar link',
                busy: _busy,
                onPressed: _invalidToken ? null : _submit,
              ),
              if (_reset)
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _requestAnother = true;
                            _error = null;
                            _password.clear();
                            _confirmation.clear();
                          }),
                    child: const Text('Solicitar outro link'),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
