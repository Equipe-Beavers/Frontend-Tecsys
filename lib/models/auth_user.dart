import 'package:flutter/widgets.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
  });

  final int id;
  final String username;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse('${json['id_usuario']}');
    if (id == null ||
        id <= 0 ||
        json['username'] is! String ||
        json['email'] is! String) {
      throw const FormatException('Dados do usuário inválidos.');
    }
    return AuthUser(id: id, username: json['username'], email: json['email']);
  }

  String get initials {
    final words = username.trim().split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
  }
}
