import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:signolia_app/widgets/center_logo_app_bar.dart';


// AJUSTA esta ruta si tu archivo route_observer.dart está en otro lugar.
// Crea lib/core/route_observer.dart con:
//   import 'package:flutter/widgets.dart';
//   final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
import '../../../core/route_observer.dart';

class SignoliaProScreen extends StatefulWidget {
  const SignoliaProScreen({super.key});

  @override
  State<SignoliaProScreen> createState() => _SignoliaProScreenState();
}

class _SignoliaProScreenState extends State<SignoliaProScreen> with RouteAware {
  // Shake
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _lx = 0, _ly = 0, _lz = 0;

  // (Opcional) Contador de taps por si quieres mantenerlo como respaldo
  int _tapCount = 0;
  DateTime? _tapFirstAt;

  // -------------------- Lifecycle + RouteAware --------------------
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precarga del asset del huevo Pro
    precacheImage(const AssetImage('assets/images/story/egg_glow.png'), context);

    final route = ModalRoute.of(context);
    if (route != null) {
      // Suscribir esta pantalla para enterarnos cuando está visible/oculta
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _stopShake();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Esta ruta se acaba de mostrar
  @override
  void didPush() => _startShake();

  // Otra ruta se cerró y volvemos a estar arriba
  @override
  void didPopNext() => _startShake();

  // Navegamos a otra ruta: esta queda detrás → parar shake
  @override
  void didPushNext() => _stopShake();

  // Esta ruta se cierra
  @override
  void didPop() => _stopShake();

  // -------------------- Shake --------------------
  void _startShake() {
    if (_accelSub != null) return; // ya arrancado
    const threshold = 20.0; // sensibilidad (baja si quieres más sensible)
    const minDelay = Duration(milliseconds: 900);

    _accelSub = accelerometerEvents.listen((e) {
      final dx = e.x - _lx, dy = e.y - _ly, dz = e.z - _lz;
      _lx = e.x; _ly = e.y; _lz = e.z;

      final g = sqrt(dx * dx + dy * dy + dz * dz);
      if (g > threshold) {
        final now = DateTime.now();
        if (now.difference(_lastShakeAt) > minDelay) {
          _lastShakeAt = now;
          _showProEgg(); // 👈 huevo propio de Signolia Pro
        }
      }
    });
  }

  void _stopShake() {
    _accelSub?.cancel();
    _accelSub = null;
  }

  // -------------------- Tap (respaldo opcional) --------------------
  void _countTwentyTaps() {
    final now = DateTime.now();
    if (_tapFirstAt == null || now.difference(_tapFirstAt!) > const Duration(seconds: 6)) {
      _tapFirstAt = now;
      _tapCount = 0;
    }
    _tapCount++;
    if (_tapCount >= 20) {
      _tapCount = 0;
      _tapFirstAt = null;
      _showProEgg();
    }
  }

  // -------------------- Mostrar huevo Pro --------------------
  Future<void> _showProEgg() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => const _ProEggScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
       appBar: const CenterLogoAppBar(showBack: true),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _countTwentyTaps,   // opcional (20 taps)
              onLongPress: _showProEgg,  // acceso alternativo FIABLE
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/story/pro.png', fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: .45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const _SoonPill(),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              '¿Qué es Signolia Pro?',
              style: (t.titleLarge ?? const TextStyle()).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'Una experiencia avanzada para profesionales del sector: acceso anticipado a contenidos, herramientas exclusivas, promociones para partners y formación especializada, todo en un mismo lugar.',
              style: (t.bodyMedium ?? const TextStyle()).copyWith(height: 1.5, color: Colors.grey.shade800),
            ),
          ),

          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _FeatureCard(
              icon: Icons.workspace_premium_rounded,
              title: 'Ventajas para profesionales',
              text: 'Acceso prioritario a episodios, itinerarios de formación, materiales descargables y oportunidades de networking.',
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _FeatureCard(
              icon: Icons.handshake_rounded,
              title: 'Alianzas y partners',
              text: 'Condiciones exclusivas con marcas del sector, pruebas de producto y eventos privados.',
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _FeatureCard(
              icon: Icons.campaign_rounded,
              title: 'Lanzamiento',
              text: 'Estamos ultimando los detalles. Muy pronto compartiremos fecha y cómo solicitar acceso.',
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ComingSoonBanner(),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _SoonPill extends StatelessWidget {
  const _SoonPill();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Positioned(
      left: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .35)),
        ),
        child: Text(
          'PRÓXIMAMENTE',
          style: (t.labelSmall ?? const TextStyle()).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: Colors.black87),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: (t.titleMedium ?? const TextStyle()).copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(text, style: (t.bodyMedium ?? const TextStyle()).copyWith(color: Colors.grey.shade800, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Estamos preparando algo grande.\nSignolia Pro llegará muy pronto.',
              style: (t.bodyMedium ?? const TextStyle()).copyWith(color: Colors.white, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla del EGG: fondo negro + imagen horizontal 16:9 (tap para cerrar)
class _ProEggScreen extends StatelessWidget {
  const _ProEggScreen();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                'assets/images/story/egg_glow.png', // Imagen propia de Signolia Pro
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
