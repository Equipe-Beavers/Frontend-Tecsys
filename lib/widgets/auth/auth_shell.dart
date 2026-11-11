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
  const AuthBackground({
    super.key,
    this.contourOpacity = .075,
    this.topographic = false,
  });
  final double contourOpacity;
  final bool topographic;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: CustomPaint(
        painter: topographic
            ? _TopographicPainter(contourOpacity)
            : _ContoursPainter(contourOpacity),
      ),
    ),
  );
}

/// Smooth contour lines for the US70 loading screen, painted once per viewport.
class _TopographicPainter extends CustomPainter {
  const _TopographicPainter(this.opacity);
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const cell = 20.0;
    final columns = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    final grid = List<double>.generate((columns + 1) * (rows + 1), (index) {
      final x = (index % (columns + 1)) * cell;
      final y = (index ~/ (columns + 1)) * cell;
      return math.sin(x / 130 + .8 * math.cos(y / 170)) +
          .8 * math.cos(y / 110 - .5 * math.sin(x / 230)) +
          .32 * math.sin((x + y) / 80);
    });
    final paint = Paint()
      ..color = AppColors.primaryLime.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var level = -2.1; level < 2.2; level += .18) {
      final path = Path();
      for (var row = 0; row < rows; row++) {
        for (var column = 0; column < columns; column++) {
          final index = row * (columns + 1) + column;
          final corners = [
            Offset(column * cell, row * cell),
            Offset((column + 1) * cell, row * cell),
            Offset((column + 1) * cell, (row + 1) * cell),
            Offset(column * cell, (row + 1) * cell),
          ];
          final values = [
            grid[index],
            grid[index + 1],
            grid[index + columns + 2],
            grid[index + columns + 1],
          ];
          final crossings = <Offset>[];
          for (var edge = 0; edge < 4; edge++) {
            final next = (edge + 1) % 4;
            if ((values[edge] < level) != (values[next] < level)) {
              crossings.add(
                Offset.lerp(
                  corners[edge],
                  corners[next],
                  (level - values[edge]) / (values[next] - values[edge]),
                )!,
              );
            }
          }
          for (var point = 0; point + 1 < crossings.length; point += 2) {
            path.moveTo(crossings[point].dx, crossings[point].dy);
            path.lineTo(crossings[point + 1].dx, crossings[point + 1].dy);
          }
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TopographicPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
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
