import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SignoliaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SignoliaAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backgroundColor = Colors.black,
    this.foregroundColor = Colors.white,
    this.elevation = 1.0,
    this.showBack = true,
    this.onLogoTap,
    this.onLogoLongPress,
  });

  final String title;
  final List<Widget>? actions;
  final Color backgroundColor;
  final Color foregroundColor;
  final double elevation;
  final bool showBack;

  /// Gestos del logo (útil si quieres conservar eggs del dashboard)
  final VoidCallback? onLogoTap;
  final VoidCallback? onLogoLongPress;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: backgroundColor,
        elevation: elevation,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                if (showBack && canPop)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: foregroundColor,
                    tooltip: 'Atrás',
                  )
                else
                  const SizedBox(width: 1),

                // Logo a la izquierda
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLogoTap,
                  onLongPress: onLogoLongPress,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Image.asset(
                      'assets/logo.png',
                      height: 35,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const Spacer(),

                // Título alineado a la derecha
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: Text(
                      title,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ) ??
                          TextStyle(
                            color: foregroundColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),

                if (actions != null) ...actions!,
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
