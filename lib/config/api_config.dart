import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolve a URL base da API conforme a plataforma de execução.
///
/// Ordem de prioridade:
/// 1. `API_BASE_URL` definido via `--dart-define` (compile-time)
/// 2. `API_BASE_URL` no `.env` (runtime)
/// 3. Fallback por plataforma:
///    - Web/desktop → `http://localhost:3000`
///    - Emulador Android → `http://10.0.2.2:3000` (loopback do host)
///    - Dispositivo físico (Android/iOS) → `API_HOST_LAN` (IP da máquina)
///
/// Em dispositivo físico, `localhost` e `10.0.2.2` apontam para o próprio
/// aparelho; por isso o padrão é o IP da máquina que roda o backend.
abstract final class ApiConfig {
  /// IP da máquina que roda o backend na rede local.
  /// Ajuste aqui se o IP da sua máquina mudar.
  static const String _lanHost = 'http://192.168.12.83:3000';

  static const String _localhost = 'http://localhost:3000';
  static const String _androidEmulator = 'http://10.0.2.2:3000';

  /// URL base final, sem barra(s) no final.
  static String get baseUrl {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return _strip(defined);

    // dotenv só é inicializado no main(); em testes ele permanece vazio.
    if (dotenv.isInitialized) {
      final fromDotenv = dotenv.maybeGet('API_BASE_URL');
      if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
        return _strip(fromDotenv.trim());
      }
    }

    return _platformDefault();
  }

  static String _strip(String url) => url.replaceFirst(RegExp(r'/+$'), '');

  static String _platformDefault() {
    if (kIsWeb) return _localhost;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Emulador Android: 10.0.2.2 é o loopback da máquina host.
        // Dispositivo físico: usa o IP da máquina na rede.
        const emulator = bool.fromEnvironment('API_ANDROID_EMULATOR');
        return emulator ? _androidEmulator : _lanHost;
      case TargetPlatform.iOS:
        // Simulador iOS compartilha o loopback do host; dispositivo físico não.
        const simulator = bool.fromEnvironment('API_IOS_SIMULATOR');
        return simulator ? _localhost : _lanHost;
      default:
        // Desktop (Linux/Windows/macOS) roda na mesma máquina.
        return _localhost;
    }
  }
}
