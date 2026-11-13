import 'package:http/http.dart' as http;

import '../controllers/auth_controller.dart';
import '../config/api_config.dart';

class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient(this.auth, {http.Client? client, String? baseUrl})
    : _inner = client ?? http.Client(),
      _base = Uri.parse(ApiConfig.resolve(baseUrl));
  final AuthController auth;
  final http.Client _inner;
  final Uri _base;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Never forward the bearer token to map tiles or external services.
    final trusted =
        request.url.origin == _base.origin &&
        request.url.path.startsWith(
          '${_base.path.replaceFirst(RegExp(r'/+$'), '')}/',
        );
    final token = auth.accessToken;
    if (trusted && token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await _inner.send(request);
    if (trusted && token != null) {
      if (response.statusCode == 401) {
        try {
          await auth.invalidate(token);
        } catch (_) {
          /* Access is already cleared in memory. */
        }
      }
      // A response from a previous account must never be displayed after a switch.
      if (auth.accessToken != token) {
        await response.stream.drain<void>();
        return http.StreamedResponse(Stream.value([]), 401, request: request);
      }
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
