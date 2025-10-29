// lib/core/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';
import 'env.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String get baseUrl => Env.apiBaseUrl ?? '';

  Map<String, String> _headers([Map<String, String>? extra]) {
    final token = AuthStorage.instance.token;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  Map<String, String> _publicHeaders([Map<String, String>? extra]) {
    // Sin Authorization
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?extra,
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    if (path.startsWith('http')) return Uri.parse(path);
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    final qp = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) qp[k] = v.toString();
    });
    return Uri.parse('$base$p').replace(queryParameters: qp.isEmpty ? null : qp);
  }

  // === Públicos (sin token) → usados por WP listados ===
  Future<http.Response> getPublic(String urlOrPath, {Map<String, dynamic>? query, Map<String, String>? headers}) {
    final uri = urlOrPath.startsWith('http') ? Uri.parse(urlOrPath) : _uri(urlOrPath, query);
    return http.get(uri, headers: _publicHeaders(headers));
  }

  Future<http.Response> postPublic(String urlOrPath, {Object? body, Map<String, String>? headers}) {
    final uri = urlOrPath.startsWith('http') ? Uri.parse(urlOrPath) : _uri(urlOrPath);
    final payload = body is String ? body : jsonEncode(body ?? {});
    return http.post(uri, headers: _publicHeaders(headers), body: payload);
  }

  // === Privados (con token si existe) ===
  Future<http.Response> get(String path, {Map<String, dynamic>? query, Map<String, String>? headers}) {
    return http.get(_uri(path, query), headers: _headers(headers));
  }

  Future<http.Response> post(String path, {Object? body, Map<String, String>? headers}) {
    final payload = body is String ? body : jsonEncode(body ?? {});
    return http.post(_uri(path), headers: _headers(headers), body: payload);
  }

  Future<http.Response> put(String path, {Object? body, Map<String, String>? headers}) {
    final payload = body is String ? body : jsonEncode(body ?? {});
    return http.put(_uri(path), headers: _headers(headers), body: payload);
  }

  Future<http.Response> delete(String path, {Object? body, Map<String, String>? headers}) {
    final payload = body is String ? body : jsonEncode(body ?? {});
    return http.delete(_uri(path), headers: _headers(headers), body: payload);
  }
}
