import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Punto unico para inicializar Firebase antes de arrancar la app.
class SignoliaFirebase {
  /// Debe llamarse en `main()` antes de `runApp`.
  static Future<void> init() async {
    await Firebase.initializeApp();

    // Garantiza que FCM arranque y pueda gestionar pushes en background.
    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
  }
}
