import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const String _baseUrlDefinida = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlDefinida.isNotEmpty) {
      return _baseUrlDefinida.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }
}
