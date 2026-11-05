import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../controllers/auth_controller.dart';
import '../../services/authenticated_client.dart';
import '../../pages/auth_page.dart';

class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.controller, required super.child});
  final AuthController controller;
  static AuthScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AuthScope>();
  static http.Client? clientOf(BuildContext context) {
    final scope = maybeOf(context);
    return scope == null ? null : AuthenticatedClient(scope.controller);
  }

  static Future<bool> ensureSignedIn(BuildContext context) async {
    final controller = maybeOf(context)?.controller;
    if (controller == null) return false;
    if (controller.user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AuthPage(controller: controller)),
    );
    return controller.user != null;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) =>
      controller != oldWidget.controller;
}
