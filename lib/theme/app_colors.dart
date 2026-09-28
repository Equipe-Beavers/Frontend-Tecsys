import 'package:flutter/material.dart';

abstract class AppColors {
  // Cores existentes mantidas
  static const Color navBarBackground = Color(0xFF10312C);
  static final Color searchBarFieldsBackground = const Color(0xFF10312C).withValues(alpha: 0.95);
  static const Color backgroundColor = Color(0xFF0A2A25);
  static const Color textPrimaryColor = Color(0xFFC8F135);
  static const Color unselectedItemColor = Color(0xFFBDBDBD);
  static const Color widgetColor = Color(0xFF35D6C0);

  // Paleta expandida baseada no Figma e SCRUM-36
  static const Color surfaceBackground = Color(0xFF081C18);
  static const Color surfaceCard = Color(0xFF0E2621);
  static const Color surfaceCardLight = Color(0xFF13352E);
  static const Color surfaceInput = Color(0xFF143831);
  static const Color border = Color(0xFF1D473E);
  static const Color borderSubtle = Color(0xFF173D35);

  // Destaques e Ações
  static const Color primaryLime = Color(0xFFC8F135);
  static const Color textDark = Color(0xFF0A2A25);
  static const Color secondaryTeal = Color(0xFF35D6C0);
  static const Color textMuted = Color(0xFF7E9A94);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status Badge
  static const Color badgeSuccessBg = Color(0xFF183B33);
  static const Color badgeSuccessText = Color(0xFFC8F135);

  // Cores de camadas dos ativos BDGD
  static const Color layerPoste = Color(0xFF35D6C0);
  static const Color layerTransformador = Color(0xFF26C6DA);
  static const Color layerSubestacao = Color(0xFFC8F135);

  static const Color layerChaveFusivel = Color(0xFFFF9800);
  static const Color layerChaveSeccionadora = Color(0xFF80CBC4);
  static const Color layerReligador = Color(0xFFFFD54F);
  static const Color layerSeccionador = Color(0xFFB0BEC5);

  static const Color layerRegulador = Color(0xFF4FC3F7);
  static const Color layerBancoCapacitores = Color(0xFF81C784);
}