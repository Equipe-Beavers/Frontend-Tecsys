import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BrandedLoadingScreen extends StatelessWidget {
  const BrandedLoadingScreen({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceBackground,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/auth_loading_background.png',
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
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
                                    Image(
                                      image: AssetImage(
                                        'assets/images/logo_geomash.png',
                                      ),
                                      width: 42,
                                      height: 42,
                                      excludeFromSemantics: true,
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
                              semanticsLabel: message,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
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
