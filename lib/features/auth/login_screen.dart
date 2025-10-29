// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import './auth_service.dart'; // ✅ importa el servicio real

/// Colores de marca
class BrandColors {
  static const primary   = Color(0xFF347778);
  static const secondary = Color(0xFFEF7F1A);
  static const text      = Color(0xFF0C0B0B);
  static const accent    = Color(0xFF347778);
  static const cardBg    = Color(0xFFFFFFFF);
  static const pageBg    = Color(0xFFF6F7F8);
}

class LoginScreen extends StatefulWidget {
  /// callback opcional
  final VoidCallback? onLogged;

  const LoginScreen({super.key, this.onLogged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  static final Uri _forgotUri = Uri.parse(
    'https://signolia.com/wp-login.php?action=lostpassword&redirect_to=https%3A%2F%2Fsignolia.com%2Farea-de-usuario',
  );
  static final Uri _registerUri = Uri.parse(
    'https://signolia.com/registro-usuario/?redirect_to=https://signolia.com/area-de-usuario/',
  );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    // ✅ usa _formKey (antes usabas _form)
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.loginWithEmailPassword(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión iniciada')),
      );

      // Si quieres ejecutar un callback opcional
      widget.onLogged?.call();

      // No navegamos manualmente: tu AuthGate redibuja a HomeShell
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExternal(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  InputDecoration _inputDecor(String label, String hint, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BrandColors.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: BrandColors.pageBg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 24),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 32),

                        // Logo
                        Image.asset(
                          'assets/logo.png',
                          height: 44,
                          fit: BoxFit.contain,
                        ),

                        const SizedBox(height: 36),

                        // Title + subtitle
                        Text(
                          'Iniciar Sesión',
                          textAlign: TextAlign.center,
                          style: t.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: BrandColors.text,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Accede a tu cuenta de Signolia',
                          textAlign: TextAlign.center,
                          style: t.titleMedium?.copyWith(color: Colors.grey.shade600, height: 1.3),
                        ),
                        const SizedBox(height: 24),

                        // Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                          decoration: BoxDecoration(
                            color: BrandColors.cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey, // ✅ key correcta
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Usuario / Email',
                                    style: t.labelLarge?.copyWith(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecor('Usuario / Email', 'tu@email.com'),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Escribe tu email o usuario';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text('Contraseña',
                                    style: t.labelLarge?.copyWith(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  decoration: _inputDecor(
                                    'Contraseña',
                                    '••••••••',
                                    suffix: IconButton(
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').isEmpty) return 'Escribe tu contraseña';
                                    if ((v ?? '').length < 6) return 'Mínimo 6 caracteres';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 54,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: BrandColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    // ✅ usa el handler correcto
                                    onPressed: _loading ? null : _doLogin,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text(
                                            'Iniciar Sesión',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Forgot password
                        TextButton(
                          onPressed: () => _openExternal(_forgotUri),
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BrandColors.primary,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Register
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('¿No tienes una cuenta?  ',
                                  style: t.bodyLarge?.copyWith(color: Colors.grey.shade700)),
                              GestureDetector(
                                onTap: () => _openExternal(_registerUri),
                                child: const Text(
                                  'Regístrate',
                                  style: TextStyle(
                                    color: BrandColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
