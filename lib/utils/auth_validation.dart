abstract final class AuthValidation {
  static String? username(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Informe seu nome de usuário.';
    if (name.length < 3 ||
        name.length > 100 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      return 'Use entre 3 e 100 caracteres.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu e-mail.';
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe sua senha.';
    if (value.length < 8 || value.length > 128) {
      return 'Use entre 8 e 128 caracteres.';
    }
    return null;
  }

  static String? confirmation(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirme sua senha.';
    if (value != password) return 'As senhas não coincidem.';
    return null;
  }
}
