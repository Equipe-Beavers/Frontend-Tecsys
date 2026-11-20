import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// URL da API: --dart-define, .env e, por último, backend local.
/// No Android por USB, npm run dev configura adb reverse automaticamente.
/// Para Wi-Fi, iPhone físico ou produção, informe API_BASE_URL explicitamente.
abstract final class ApiConfig {
  static const String _localhost = 'http://127.0.0.1:3000';
  static const String _androidEmulator = 'http://10.0.2.2:3000';

  /// URL base final, sem barra(s) no final.
  static String get baseUrl {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.trim().isNotEmpty) return _strip(defined.trim());

    // dotenv só é inicializado no main(); em testes ele permanece vazio.
    if (dotenv.isInitialized) {
      final fromDotenv = dotenv.maybeGet('API_BASE_URL');
      if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
        return _strip(fromDotenv.trim());
      }
    }

    return _platformDefault();
  }

  /// Explicit constructor URLs are useful for tests and take precedence locally.
  static String resolve(String? override) =>
      _strip((override ?? baseUrl).trim());

  static String _strip(String url) => url.replaceFirst(RegExp(r'/+$'), '');

  static String _platformDefault() {
    if (kIsWeb) return _localhost;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // O backend prepara o loopback por USB, inclusive para emuladores.
        const emulator = bool.fromEnvironment('API_ANDROID_EMULATOR');
        return emulator ? _androidEmulator : _localhost;
      case TargetPlatform.iOS:
        // Simulador iOS usa loopback; aparelho físico exige API_BASE_URL.
        return _localhost;
      default:
        // Desktop (Linux/Windows/macOS) roda na mesma máquina.
        return _localhost;
    }
  }
}
