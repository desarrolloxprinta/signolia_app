import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// AppBar minimalista con:
/// - fondo negro
/// - logo centrado
/// - (opcional) botón "Atrás" a la izquierda
/// - gestos opcionales en el logo (tap / long-press)
class CenterLogoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CenterLogoAppBar({
    super.key,
    this.showBack = true,
    this.onLogoTap,
    this.onLogoLongPress,
    this.elevation = 1.0,
  });

  final bool showBack;
  final VoidCallback? onLogoTap;
  final VoidCallback? onLogoLongPress;
  final double elevation;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black,
        elevation: elevation,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Botón atrás (si procede)
                if (showBack && canPop)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: Colors.white,
                      tooltip: 'Atrás',
                    ),
                  ),

                // Logo centrado con gestos opcionales
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLogoTap,
                  onLongPress: onLogoLongPress,
                  child: Image.asset(
                    'assets/logo.png',
                    height: 35,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
