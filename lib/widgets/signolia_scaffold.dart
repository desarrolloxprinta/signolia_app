import 'package:flutter/material.dart';
import '../core/route_titles.dart';
import 'signolia_app_bar.dart';
import '../core/section_title_scope.dart';

class SignoliaScaffold extends StatelessWidget {
  const SignoliaScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.showBack = false,
    this.onLogoTap,
    this.onLogoLongPress,
    this.backgroundColor = Colors.white,
    this.appBarBackgroundColor = Colors.black,
    this.appBarForegroundColor = Colors.white,
    this.appBarElevation = 1.0,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  /// Contenido de la pantalla
  final Widget body;

  /// Título explícito (si lo pasas, sobreescribe el autodetectado)
  final String? title;

  /// Acciones de AppBar
  final List<Widget>? actions;

  /// Control del botón back
  final bool showBack;

  /// Gestos del logo (útil en dashboard para eggs)
  final VoidCallback? onLogoTap;
  final VoidCallback? onLogoLongPress;

  /// Colores
  final Color backgroundColor;
  final Color appBarBackgroundColor;
  final Color appBarForegroundColor;
  final double appBarElevation;

  /// Extra opcional
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

    String _resolveTitle(BuildContext context) {
  // 1) Título explícito
  if (title != null && title!.trim().isNotEmpty) return title!.trim();

  // 2) Scope de sección (para tabs/IndexedStack)
  final scoped = SectionTitleScope.of(context)?.title;
  if (scoped != null && scoped.trim().isNotEmpty) return scoped.trim();

  // 3) Nombre de ruta (para rutas reales)
  final routeName = ModalRoute.of(context)?.settings.name;
  final fromMap = RouteTitles.forRouteName(routeName);
  if (fromMap != null && fromMap.trim().isNotEmpty) return fromMap.trim();

  // 4) Fallback
  return 'Signolia';
}
  @override
  Widget build(BuildContext context) {
    final resolvedTitle = _resolveTitle(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: SignoliaAppBar(
        title: resolvedTitle,
        actions: actions,
        showBack: showBack,
        onLogoTap: onLogoTap,
        onLogoLongPress: onLogoLongPress,
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarForegroundColor,
        elevation: appBarElevation,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
