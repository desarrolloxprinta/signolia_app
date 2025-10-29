// lib/core/auth_storage.dart
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  AuthStorage._();
  static final AuthStorage instance = AuthStorage._();

  static const _kAuthToken = 'auth_token';
  static const _kUserJson  = 'user_json';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _token;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  final _authCtrl = StreamController<bool>.broadcast();
  Stream<bool> get authChanges => _authCtrl.stream;

  Future<void> init() async {
    _token = await _storage.read(key: _kAuthToken);
    _authCtrl.add(isLoggedIn);
  }

  Future<void> login({required String token, String? userJson}) async {
    _token = token;
    await _storage.write(key: _kAuthToken, value: token);
    if (userJson != null) {
      await _storage.write(key: _kUserJson, value: userJson);
    }
    _authCtrl.add(true);
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _kAuthToken);
    await _storage.delete(key: _kUserJson);
    _authCtrl.add(false);
  }
}
