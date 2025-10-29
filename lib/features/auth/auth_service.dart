// lib/features/auth/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/env.dart';
import '../../core/auth_storage.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Login contra WP JWT (soporta form-urlencoded y JSON).
  /// Lanza excepción con mensaje claro si falla.
  Future<void> loginWithEmailPassword(String email, String password) async {
    final uri = Uri.parse(Env.jwtLogin);

    // 1) Intento FORM (muchos plugins esperan esto)
    http.Response resp = await http.post(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'username': email,
        'password': password,
      },
    );

    // Si no es 200, probamos 2) JSON
    if (resp.statusCode != 200) {
      resp = await http.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': email,
          'password': password,
        }),
      );
    }

    // Si sigue sin ser 200 -> error con mensaje útil
    if (resp.statusCode != 200) {
      final msg = _extractError(resp);
      throw Exception(msg);
    }

    // Parse token en varias formas posibles
    final token = _extractToken(resp);
    if (token == null || token.isEmpty) {
      throw Exception('Login OK, pero la respuesta no incluye token.');
    }

    await AuthStorage.instance.login(token: token, userJson: resp.body);
  }

  Future<void> logout() => AuthStorage.instance.logout();

  // ===== Helpers =====
  String _extractError(http.Response resp) {
    try {
      final data = json.decode(resp.body);
      // Mensaje directo
      if (data is Map && data['message'] is String) {
        final code = (data['code'] ?? '').toString();
        final status = (data['data']?['status'] ?? '').toString();
        final base = data['message'] as String;
        // Añade detalles si existen
        final det = <String>[];
        if (code.isNotEmpty) det.add('code: $code');
        if (status.isNotEmpty) det.add('status: $status');
        return det.isEmpty ? base : '$base (${det.join(', ')})';
      }
      // Otros formatos
      return 'Error ${resp.statusCode} en autenticación.';
    } catch (_) {
      return 'Error ${resp.statusCode} en autenticación.';
    }
  }

  String? _extractToken(http.Response resp) {
    try {
      final data = json.decode(resp.body);

      // Casos comunes:
      // { "token": "..." }
      if (data is Map && data['token'] is String) return data['token'] as String;

      // { "jwt": "..." }
      if (data is Map && data['jwt'] is String) return data['jwt'] as String;

      // { "data": { "jwt": "..." } }
      final jwtInData = (data is Map) ? (data['data']?['jwt']) : null;
      if (jwtInData is String) return jwtInData;

      // { "success": true, "data": { "token": "..." } }
      final tokenInData = (data is Map) ? (data['data']?['token']) : null;
      if (tokenInData is String) return tokenInData;

      // Algunos plugins devuelven { "access_token": "..."}
      if (data is Map && data['access_token'] is String) return data['access_token'] as String;

      return null;
    } catch (_) {
      return null;
    }
  }
}
