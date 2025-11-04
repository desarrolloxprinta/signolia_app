import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Utilidad mínima para guardar respuestas en caché con TTL.
class SimpleCache {
  SimpleCache._();

  static final SimpleCache instance = SimpleCache._();

  final Future<SharedPreferences> _prefsFuture = SharedPreferences.getInstance();

  /// Lee un payload almacenado bajo [key] si no ha caducado.
  Future<dynamic> read(String key, Duration ttl) async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.tryParse(wrapper['fetchedAt'] as String? ?? '');
      if (fetchedAt == null || DateTime.now().difference(fetchedAt) > ttl) {
        return null;
      }
      return wrapper['data'];
    } catch (_) {
      return null;
    }
  }

  /// Persiste un payload arbitrario (Map/List/primitive) bajo [key].
  Future<void> write(String key, dynamic data) async {
    final prefs = await _prefsFuture;
    final wrapper = {
      'fetchedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
    await prefs.setString(key, jsonEncode(wrapper));
  }

  Future<void> clear(String key) async {
    final prefs = await _prefsFuture;
    await prefs.remove(key);
  }
}
