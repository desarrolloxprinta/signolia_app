import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Usa tu navigatorKey global (ajusta la import si tu archivo se llama distinto)
import 'package:signolia_app/core/navigation_service.dart'; // debe exponer: GlobalKey<NavigatorState> navigatorKey

// ─────────────────────────────────────────────────────────
// Background handler (mensaje recibido con app terminada)
// ─────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 [BG] ${message.notification?.title} | data=${message.data}');
}

class SignoliaFirebase {
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'signolia_channel',
    'Signolia Notifications',
    description: 'Notificaciones de contenido nuevo en Signolia',
    importance: Importance.high,
  );

  // Llama a esto en main() ANTES de runApp()
  static Future<void> init() async {
    await Firebase.initializeApp();

    // Permisos (Android 13+ y iOS)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
    );

    // Canal y init de locales
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapFromLocal,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Suscripciones iniciales
    await _subscribeAllTopics();

    // Re-suscribir en cambio de token
    _messaging.onTokenRefresh.listen((t) async {
      debugPrint('♻️ Nuevo token FCM, re-suscribiendo topics…');
      await _subscribeAllTopics();
    });

    // Listeners
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromMessage);

    // Background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Debug token
    final token = await _messaging.getToken();
    debugPrint('🔑 FCM Token: $token');
  }

  // ─────────────────────────────────────────────────────────
  // Suscripciones a topics
  // ─────────────────────────────────────────────────────────
  static Future<void> _subscribeAllTopics() async {
    try {
      await _messaging.subscribeToTopic('signolia_news');
      debugPrint('🗞️ Subscrito a signolia_news');

      await _messaging.subscribeToTopic('signolia_events');
      debugPrint('📅 Subscrito a signolia_events');

      await _messaging.subscribeToTopic('signolia_offers');
      debugPrint('🎫 Subscrito a signolia_offers');

      await _messaging.subscribeToTopic('signolia_podcasts');
      debugPrint('🎙️ Subscrito a signolia_podcasts');
    } catch (e) {
      debugPrint('⚠️ Error al suscribir topics: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Mensajes en foreground → notificación local
  // ─────────────────────────────────────────────────────────
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    final type = message.data['type'] ?? 'general';
    final icons = {
      'noticias': '🗞️',
      'eventos': '📅',
      'ofertas': '🎫',
      'podcast': '🎙️',
      // alias por si llegaran en inglés
      'news': '🗞️',
      'events': '📅',
      'offers': '🎫',
      'podcasts': '🎙️',
    };
    final emoji = icons[type] ?? '✨';

    const androidDetails = AndroidNotificationDetails(
      'signolia_channel',
      'Signolia Notifications',
      channelDescription: 'Contenido nuevo en Signolia',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    // Guardamos en payload type|post_id para usar en el tap
    final payload = '${message.data['type']}|${message.data['post_id']}';

    await _local.show(
      n.hashCode,
      '$emoji ${n.title}',
      n.body,
      details,
      payload: payload,
    );
  }

  // Tap a notificación local (foreground)
  static void _onNotificationTapFromLocal(NotificationResponse r) {
    final p = r.payload;
    if (p == null || p.isEmpty) return;
    final parts = p.split('|');
    if (parts.length != 2) return;
    final type = parts[0];
    final postId = parts[1];
    _navigate(type, postId);
  }

  // Tap a push recibido con app en background/terminada
  static void _onOpenedFromMessage(RemoteMessage message) {
    final type = message.data['type'] ?? '';
    final postId = message.data['post_id'] ?? '';
    _navigate(type, postId);
  }

  // ─────────────────────────────────────────────────────────
  // Navegación centralizada por tipo
  // (usa rutas con argumentos; no acoplamos a clases concretas aquí)
  // ─────────────────────────────────────────────────────────
  static void _navigate(String type, String postId) {
    final nav = navigatorKey.currentState;
    if (nav == null || postId.isEmpty) return;

    // normalizamos alias en inglés → español
    switch (type) {
      case 'news':      type = 'noticias'; break;
      case 'events':    type = 'eventos'; break;
      case 'offers':    type = 'ofertas'; break;
      case 'podcasts':  type = 'podcast'; break;
    }

    debugPrint('➡️ Navegar: type=$type id=$postId');

    switch (type) {
      case 'noticias':
        nav.pushNamed('/noticia_detail', arguments: {'id': int.tryParse(postId) ?? 0});
        break;
      case 'eventos':
        nav.pushNamed('/evento_detail', arguments: {'id': postId});
        break;
      case 'ofertas':
        nav.pushNamed('/oferta_detail', arguments: {'id': postId});
        break;
      case 'podcast':
        nav.pushNamed('/podcast_detail', arguments: {'id': int.tryParse(postId) ?? 0});
        break;
      default:
        debugPrint('⚠️ Tipo desconocido: $type');
    }
  }
}
