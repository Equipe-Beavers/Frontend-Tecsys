import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../models/auth_operation.dart';
import '../branded_loading_screen.dart';

/// A single presentation boundary for US70; never used for map or study requests.
class AuthLoadingHost extends StatelessWidget {
  const AuthLoadingHost({
    super.key,
    required this.controller,
    required this.child,
  });
  final AuthController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context
            .dependOnInheritedWidgetOfExactType<_LoadingBoundary>()
            ?.controller ==
        controller) {
      return child;
    }
    return _LoadingBoundary(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final operation = controller.operation;
          return Stack(
            fit: StackFit.expand,
            children: [
              ExcludeFocus(
                excluding: operation != null,
                child: TickerMode(
                  enabled: operation == null,
                  child: Offstage(offstage: operation != null, child: child!),
                ),
              ),
              if (operation != null)
                Positioned.fill(
                  child: BlockSemantics(
                    child: AuthLoadingScreen(operation: operation),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingBoundary extends InheritedWidget {
  const _LoadingBoundary({required this.controller, required super.child});
  final AuthController controller;
  @override
  bool updateShouldNotify(_LoadingBoundary oldWidget) =>
      oldWidget.controller != controller;
}

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key, required this.operation});
  final AuthOperation operation;

  @override
  Widget build(BuildContext context) =>
      BrandedLoadingScreen(message: operation.message);
}
