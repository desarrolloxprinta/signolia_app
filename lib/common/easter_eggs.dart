// lib/common/easter_eggs.dart
import 'package:flutter/material.dart';

/// ——— Navegación con fade ———
Future<void> _pushFade(BuildContext context, Widget page, {bool opaque = true}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: opaque,
      barrierColor: opaque ? null : Colors.black.withValues(alpha: .8), // was withOpacity(.8)
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

/// —————————————————————————————————————————————————————
/// 1) RETRO EGG (secuencia de tabs en el footer)
/// —————————————————————————————————————————————————————
class RetroEggScreen extends StatelessWidget {
  const RetroEggScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Usa tu asset; si aún no lo tienes, deja un Icon bonito.
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Image.asset(
            'assets/images/story/egg_proo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.videogame_asset, size: 120, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// helper público para abrir el retro egg
Future<void> openRetroEgg(BuildContext context) => _pushFade(context, const RetroEggScreen());

/// Pequeño watcher de “secuencia de tabs” (tipo Konami touch)
class KonamiTabWatcher {
  KonamiTabWatcher({
    required this.sequence,
    this.window = const Duration(seconds: 6),
  });

  /// índices de tabs: ej. [0,1,2,3] = noticias→eventos→ofertas→podcast
  final List<int> sequence;
  final Duration window;

  final _buffer = <int>[];
  DateTime? _start;

  void onTap(int index, BuildContext context) {
    final now = DateTime.now();
    if (_start == null || now.difference(_start!) > window) {
      _start = now;
      _buffer.clear();
    }
    _buffer.add(index);

    if (_buffer.length > sequence.length) {
      _buffer.removeAt(0);
    }

    if (_buffer.length == sequence.length) {
      final ok = List.generate(sequence.length, (i) => _buffer[i] == sequence[i]).every((e) => e);
      if (ok) {
        _buffer.clear();
        _start = null;
        openRetroEgg(context);
      }
    }
  }
}

/// —————————————————————————————————————————————————————
/// 2) GLOW EGG (overlay luminoso para “shake” en el dashboard)
/// —————————————————————————————————————————————————————
class GlowEggOverlay extends StatefulWidget {
  const GlowEggOverlay({super.key});

  @override
  State<GlowEggOverlay> createState() => _GlowEggOverlayState();
}

class _GlowEggOverlayState extends State<GlowEggOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  )..repeat(reverse: true);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withValues(alpha: .85), // was withOpacity(.85)
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) {
            final v = ctrl.value;
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: .30 + .25 * v), // was withOpacity
                    blurRadius: 40 + 40 * v,
                    spreadRadius: 4 + 4 * v,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/story/egg_glow.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, size: 120, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> openGlowEgg(BuildContext context) => _pushFade(context, const GlowEggOverlay(), opaque: false);

/// —————————————————————————————————————————————————————
/// 3) PRO TEASER (long-press en el título de Signolia Pro)
/// —————————————————————————————————————————————————————
class ProTeaserEgg extends StatelessWidget {
  const ProTeaserEgg({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Image.asset(
                'assets/images/story/egg_proo.png', // <- nombre nuevo confirmado
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium, size: 120, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 32, left: 0, right: 0,
              child: Text(
                'Próximamente…',
                textAlign: TextAlign.center,
                style: (t.titleLarge ?? const TextStyle()).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openProTeaserEgg(BuildContext context) => _pushFade(context, const ProTeaserEgg());
