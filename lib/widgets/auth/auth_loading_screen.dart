import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../models/auth_operation.dart';
import '../../theme/app_colors.dart';
import 'auth_shell.dart';

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
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceBackground,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const AuthBackground(contourOpacity: .13, topographic: true),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.2, -.1),
              radius: 1.1,
              colors: [Color(0x0013352E), Color(0x99081C18)],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              final compact = constraints.maxHeight < 360;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: compact ? 16 : 32,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (desktop)
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ImageIcon(
                                      AssetImage(
                                        'assets/images/logo_geomash.png',
                                      ),
                                      size: 42,
                                      color: AppColors.primaryLime,
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      'GEOMASH',
                                      style: TextStyle(
                                        color: AppColors.textWhite,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 5,
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                Image.asset(
                                  'assets/images/logo_geomash.png',
                                  width: compact ? 64 : 104,
                                  height: compact ? 64 : 104,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(height: 24),
                                const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'GEOMASH',
                                    style: TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                              ],
                              if (desktop) ...[
                                const SizedBox(height: 18),
                                const Text(
                                  'Planejamento e otimização de cobertura de RF para redes de distribuição.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: desktop ? 264 : 180,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: AppColors.primaryLime,
                              backgroundColor: AppColors.border,
                              semanticsLabel: operation.message,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              operation.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: compact
                          ? 0
                          : math.min(24, constraints.maxHeight * .025),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
