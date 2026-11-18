import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/images/logo_geomash.png',
        width: 34,
        height: 34,
        semanticLabel: 'Símbolo da Geomash',
      ),
      const SizedBox(width: 12),
      const Flexible(
        child: Text(
          'GEOMASH',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.5,
          ),
        ),
      ),
    ],
  );
}

/// Shared desktop/mobile composition for registration and login.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surfaceBackground,
    body: Stack(
      children: [
        const Positioned.fill(child: AuthBackground()),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              if (!desktop) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 440,
                        minHeight: math.max(0, constraints.maxHeight - 40),
                      ),
                      child: IntrinsicHeight(child: child),
                    ),
                  ),
                );
              }
              return Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AuthBrand(),
                          const Spacer(),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 410),
                            child: const Text(
                              'Planejamento e otimização de cobertura de RF para redes de distribuição.',
                              style: TextStyle(
                                fontSize: 25,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: ColoredBox(
                      color: AppColors.surfaceBackground.withValues(alpha: .86),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 40,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(0, constraints.maxHeight - 80),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, this.contourOpacity = .075});
  final double contourOpacity;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: CustomPaint(painter: _ContoursPainter(contourOpacity)),
    ),
  );
}

class _ContoursPainter extends CustomPainter {
  const _ContoursPainter(this.opacity);
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLime.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var line = -7; line < 21; line++) {
      final path = Path();
      for (var step = 0; step <= 100; step++) {
        final y = size.height * step / 100;
        final x =
            line * 82.0 +
            math.sin(y / 125 + line * .55) * 75 +
            math.cos(y / 61 + line * .4) * 24;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ContoursPainter oldDelegate) =>
      opacity != oldDelegate.opacity;
}
