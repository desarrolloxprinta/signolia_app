// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/auth_gate.dart';
import 'core/firebase_initializer.dart';
import 'core/navigation_service.dart' as nav;
import 'core/notification_service.dart';
import 'core/route_observer.dart';
import 'ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SignoliaFirebase.init(); // Inicializa Firebase y listeners comunes
  await NotificationService.initialize(); // Configura listeners de navegación desde notificaciones

  // Inicializa Intl para formateo de fechas en español
  Intl.defaultLocale = 'es_ES';
  await initializeDateFormatting('es_ES');

  runApp(const SignoliaApp());
}

class RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('Route pushed: ${route.settings.name} (${route.runtimeType})');
    super.didPush(route, previousRoute);
  }
}

class SignoliaApp extends StatelessWidget {
  const SignoliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signolia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
      navigatorKey: nav.navigatorKey,
      navigatorObservers: [routeObserver],
    );
  }
}
