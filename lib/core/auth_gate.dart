// lib/core/auth_gate.dart
import 'package:flutter/material.dart';
import 'auth_storage.dart';

// Rutas reales según tu proyecto:
import '../ui/home_shell.dart';
import '../features/auth/login_screen.dart';

/// 🔧 Bandera temporal para desactivar el login al arrancar la app.
/// - true  -> entra directo a HomeShell (modo público)
/// - false -> usa el flujo de autenticación existente (LoginScreen si no logueado)
const bool kLoginTemporarilyDisabled = true;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<void> _initFut;

  @override
  void initState() {
    super.initState();
    _initFut = AuthStorage.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Modo público temporal: entra directo a la app sin exigir login
    if (kLoginTemporarilyDisabled) {
      // Opción A: ni siquiera esperamos init() si no lo necesitas
      // return const HomeShell();

      // Opción B (recomendada): mantenemos el init por si HomeShell necesita
      // datos del almacenamiento (tokens previos, preferencias, etc.)
      return FutureBuilder<void>(
        future: _initFut,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Material(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const HomeShell();
        },
      );
    }

    // 🔒 Flujo de autenticación ORIGINAL (cuando vuelvas a activar el login)
    return FutureBuilder<void>(
      future: _initFut,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Material(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return StreamBuilder<bool>(
          stream: AuthStorage.instance.authChanges,
          initialData: AuthStorage.instance.isLoggedIn,
          builder: (_, s) {
            final logged = s.data ?? false;
            return logged ? const HomeShell() : const LoginScreen();
          },
        );
      },
    );
  }
}
