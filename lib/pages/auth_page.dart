import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../widgets/auth/auth_shell.dart';
import '../widgets/auth/login_form.dart';
import '../widgets/auth/register_form.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.controller, this.register = false});
  final AuthController controller;
  final bool register;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool _register = widget.register;
  String _email = '';
  bool _registered = false;

  @override
  Widget build(BuildContext context) => AuthShell(
    child: _register
        ? RegisterForm(
            service: widget.controller.service,
            onBack: () => Navigator.of(context).pop(),
            onLogin: () => setState(() {
              _register = false;
              _registered = false;
            }),
            onRegistered: (email) => setState(() {
              _email = email;
              _registered = true;
              _register = false;
            }),
          )
        : LoginForm(
            controller: widget.controller,
            initialEmail: _email,
            registered: _registered,
            onBack: () => Navigator.of(context).pop(),
            onRegister: () => setState(() {
              _register = true;
              _registered = false;
            }),
            onAuthenticated: () => Navigator.of(context).pop(),
          ),
  );
}
