// lib/core/notification_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:signolia_app/firebase_options.dart';

// Pantallas reales de tu app
import 'package:signolia_app/presentation/noticias/widgets/noticia_detail_screen.dart';
import 'package:signolia_app/presentation/eventos/widgets/evento_detail_screen.dart';
import 'package:signolia_app/presentation/ofertas/widgets/oferta_detail_screen.dart';
import 'package:signolia_app/presentation/podcasts/widgets/podcast_detail_screen.dart';
import 'package:signolia_app/core/navigation_service.dart' as nav;

// Canal Android (v17+)
const AndroidNotificationChannel kSignoliaChannel = AndroidNotificationChannel(
  'signolia_channel',
  'Signolia Notifications',
  description: 'Contenido nuevo en Signolia',
  importance: Importance.high,
);

// Handler BG (top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // Caché simple para ofertas/eventos
  static final Map<String, dynamic> _contentCache = {};

  // 👉 Navegación pendiente cuando la app aún no está lista (arranque por push)
  static String? _pendingType;
  static String? _pendingPostId;
  static bool _appReady = false;

  /// Llama a esto en main() antes de runApp()
  static Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Init locales con icono propio
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@drawable/ic_stat_signolia');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Crear canal
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(kSignoliaChannel);

    // Topics
    await _subscribeToSignoliaTopics();
    _messaging.onTokenRefresh.listen((_) async => _subscribeToSignoliaTopics());

    // Foreground
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App abierta desde background
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromMessage);

    // BG handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 👇 App abierta desde TERMINADA por una notificación
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      final type = initial.data['type'];
      final postId = initial.data['post_id'];
      // Guarda como pendiente hasta que la app esté lista
      _pendingType = type;
      _pendingPostId = postId;
      _tryFlushPending(); // por si ya hay navigator
    }
  }

  /// Llama a esto cuando ya estés dentro de la app (p. ej. tras pasar AuthGate)
  static void markAppReady() {
    _appReady = true;
    _tryFlushPending();
  }

  // Intenta ejecutar la navegación pendiente si la app ya puede navegar
  static void _tryFlushPending() {
    if (!_appReady) return;
    if (_pendingType == null || _pendingPostId == null) return;
    if (nav.navigatorKey.currentState == null) return;

    final t = _pendingType!;
    final id = _pendingPostId!;
    _pendingType = null;
    _pendingPostId = null;

    // Asegura ejecutar después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToDetail(t, id);
    });
  }

  static Future<void> _subscribeToSignoliaTopics() async {
    try {
      await _messaging.subscribeToTopic('signolia_news');
      await _messaging.subscribeToTopic('signolia_events');
      await _messaging.subscribeToTopic('signolia_offers');
      await _messaging.subscribeToTopic('signolia_podcasts');
    } catch (_) {}
  }

  // Foreground → locales
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'signolia_channel',
          'Signolia Notifications',
          channelDescription: 'Contenido nuevo en Signolia',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'signolia_channel',
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = '${message.data['type']}|${message.data['post_id']}';

    await _local.show(n.hashCode, n.title, n.body, details, payload: payload);
  }

  // Tap en locales (app ya abierta)
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    if (parts.length != 2) return;

    final type = parts[0];
    final postId = parts[1];

    // Si aún no está lista la app, lo guardamos como pendiente
    if (nav.navigatorKey.currentState == null || !_appReady) {
      _pendingType = type;
      _pendingPostId = postId;
      _tryFlushPending();
      return;
    }
    _navigateToDetail(type, postId);
  }

  // Tap en push con app en background
  static void _onOpenedFromMessage(RemoteMessage message) {
    final type = message.data['type'];
    final postId = message.data['post_id'];

    if (nav.navigatorKey.currentState == null || !_appReady) {
      _pendingType = type;
      _pendingPostId = postId;
      _tryFlushPending();
      return;
    }
    _navigateToDetail(type, postId);
  }

  // Navegación + fetch/caché para eventos/ofertas
  static Future<void> _navigateToDetail(String? type, String? postId) async {
    if (type == null || postId == null || postId.isEmpty) return;
    if (nav.navigatorKey.currentState == null) return;

    try {
      final cacheKey = '$type-$postId';
      dynamic content = _contentCache[cacheKey];

      if (content == null && (type == 'ofertas' || type == 'eventos')) {
        content = await _fetchContent(type, postId);
        if (content != null) _contentCache[cacheKey] = content;
      }

      switch (type) {
        case 'noticias':
          nav.navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) =>
                  NoticiasDetailScreenV2(id: int.tryParse(postId) ?? 0),
            ),
          );
          break;

        case 'eventos':
          nav.navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => EventoDetailScreen(evento: content),
            ),
          );
          break;

        case 'ofertas':
          if (content is Map<String, dynamic>) {
            nav.navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (_) => OfertaDetailScreen.fromWp(post: content),
              ),
            );
          } else {
            nav.navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (_) => OfertaDetailScreen.fromWp(
                  post: {
                    'id': int.tryParse(postId) ?? 0,
                    'title': {'rendered': 'Oferta'},
                    'link': '',
                    'meta': {},
                  },
                ),
              ),
            );
          }
          break;

        case 'podcast':
          nav.navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) =>
                  PodcastDetailScreen(id: int.tryParse(postId) ?? 0),
            ),
          );
          break;

        // alias por si llegan en inglés
        case 'news':
          return _navigateToDetail('noticias', postId);
        case 'events':
          return _navigateToDetail('eventos', postId);
        case 'offers':
          return _navigateToDetail('ofertas', postId);
        case 'podcasts':
          return _navigateToDetail('podcast', postId);

        default:
          break;
      }
    } catch (_) {}
  }

  static Future<dynamic> _fetchContent(String type, String id) async {
    final base = 'https://signolia.com/wp-json/wp/v2/';
    final url = '$base$type/$id?_embed=1';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }
}
