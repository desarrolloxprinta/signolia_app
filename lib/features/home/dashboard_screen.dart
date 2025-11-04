// lib/features/home/dashboard_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

// RouteObserver global (ajusta import si tu ruta es distinta)
import '../../core/route_observer.dart';

// Listados/detalles
import '../../presentation/podcasts/widgets/podcasts_list_screen.dart';
import '../../presentation/podcasts/widgets/podcast_detail_screen.dart';
import '../../presentation/eventos/widgets/evento_detail_screen.dart';
import '../../presentation/ofertas/widgets/oferta_detail_screen.dart';
import '../../presentation/noticias/widgets/noticia_detail_screen.dart'
    show NoticiasDetailScreenV2;

// Pantalla Signolia Pro
import '../pro/signolia_pro_screen.dart';

// Endpoints (Env.cptNoticias, Env.cptEventos, Env.cptOfertas, Env.cptPodcasts)
import '../../core/env.dart';

Map<String, dynamic> _ofertaAdapterToWpMap(final dynamic a) {
  // `a` es tu _OfertaAdapter (ajusta nombres si alguno difiere)
  return {
    'title': {'rendered': (a.titulo ?? a.title ?? '').toString()},
    // permalink público de Signolia → el que contiene el formulario (elementor/jetengine)
    'link': (a.link ?? a.linkPublico ?? '').toString(),

    'excerpt': {'rendered': (a.excerptHtml ?? a.excerpt ?? '').toString()},

    'meta': {
      'descripcion_oferta':
          (a.descripcionOferta ?? a.descripcionHtml ?? a.descripcion ?? '')
              .toString(),
      'fecha_inicio_oferta': a.fechaInicioEpoch ?? 0,
      'fecha_fin_oferta': a.fechaFinEpoch ?? 0,
      'nombre_empresa_oferta': (a.nombreEmpresa ?? '').toString(),
      'direccion_de_la_empresa': (a.direccion ?? '').toString(),
      'email_empresa_oferta': (a.email ?? '').toString(),
      'telefono_empresa_oferta': (a.telefono ?? '').toString(),
      'web_oferta_empresa': (a.web ?? a.webEmpresa ?? '').toString(),
      'descuento_oferta': (a.descuento ?? '').toString(),
      // web externa de la promo (si existe)
      'link_oferta': (a.linkOferta ?? '').toString(),
    },

    '_embedded': {
      'author': [
        {'name': (a.autorNombre ?? '').toString()},
      ],
    },
  };
}

class BrandImages {
  static const podcast = 'assets/images/story/podcast.png';
  static const empleo = 'assets/images/story/empleo.png';
  static const ope = 'assets/images/story/ope.jpeg';
  static const pro = 'assets/images/story/pro.png';

  // Eggs
  static const eggTap = 'assets/images/story/egg.png';
  static const eggShake = 'assets/images/story/egg_retro.jpg';
  static const eggOrder = 'assets/images/story/egg_proo.png'; // <- ¡dos "o"!
  static const eggGlow = 'assets/images/story/egg_glow.png';
  static const brainrot = 'assets/images/story/kelvin-brainrot.mp4';
}

class BrandColors {
  static const primary = Color(0xFF347778);
  static const secondary = Color(0xFFEF7F1A);
  static const text = Color(0xFF0C0B0B);
  static const accent = Color(0xFF833766);
}

enum LatestType { podcast, noticia, evento, oferta }

class LatestItem {
  final LatestType type;
  final String title;
  final String excerpt;
  final String? imageUrl;
  final Map<String, dynamic> raw;

  /// Fecha usada para ordenar el feed combinado
  final DateTime? publishedAt;

  const LatestItem({
    required this.type,
    required this.title,
    required this.excerpt,
    required this.imageUrl,
    required this.raw,
    required this.publishedAt,
  });
}

class DashboardScreen extends StatefulWidget {
  final String noticiasUrl;
  final String eventosUrl;
  final String ofertasUrl;
  final String podcastsUrl;

  const DashboardScreen({
    super.key,
    String? noticiasUrl,
    String? eventosUrl,
    String? ofertasUrl,
    String? podcastsUrl,
  }) : noticiasUrl = noticiasUrl ?? Env.cptNoticias,
       eventosUrl = eventosUrl ?? Env.cptEventos,
       ofertasUrl = ofertasUrl ?? Env.cptOfertas,
       podcastsUrl = podcastsUrl ?? Env.cptPodcasts;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  late Future<List<LatestItem>> _latestFuture;

  // Eggs: taps en logo
  int _eggTapCount = 0;
  DateTime? _eggFirstTapAt;

  // Shake (solo activo cuando la ruta está visible)
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastX = 0, _lastY = 0, _lastZ = 0;

  // Alternar "modo legacy agrupado" (7 taps en el título)
  bool _orderAlt = false;

  // Datos "¿Qué prefieres...?"
  static const List<String> _wouldYouRatherPrompts = [
    '¿Qué prefieres?\n Reflexiona y conversa tu decisión con la persona que tienes a un lado \n -Perder un pedazo del labio de abajo -Perder un pedazo de nariz\n -La muerte instantánea de un niño de unos 3 o 2 años guatemalteco y quedar con buenos labios y una nariz perfecta',
    '¿Qué prefieres?\n Reflexiona y conversa tu decisión con la persona que tienes a un lado\n -Ganar un millón de euros y perder mitad del pene o de la vagina de forma que ninguna operación sea posible, te queda con mal olor también, mueres así\n -Ganar 60 millones de euros pero todos los lunes por 12 años a las 8:00 am tienes que llamar a Colombia, te presentan un perfil de varias personas al azar y tu decides cual desaparecen.\n -Ganar un millón de euros, pero sólo puedes usar ese dinero en "yibuti ciudad" se transfiere el dinero a esa zona no se puede sacar mediante ningún motivo, forma o traspaso.',
    '¿Qué prefieres?\n Reflexiona y conversa tu decisión con la persona que tienes a un lado\n -Un año sin besar a nadie y oler mal \n -Perder el tacto por un año y 4 muelas',
    '¿Qué prefieres?\n Reflexiona y conversa tu decisión con la persona que tienes a un lado\n -Matar un chimpancé una vez cada 3 años y recibir una isla como premio, luego de 2 chimpances eliminados\n -Revivir en el cuerpo de un chimpancé bebe en medio de la selva con todos los conocimientos que tienes actualmente',
    '¿A quien le ganas en una pelea a puños?\n Reflexiona y conversa tu decisión con la persona que tienes a un lado\n -Un Hombre del pasado (1850 - 1860)\n -Un hombre del futuro (2080 - 2090)',
    '¿Qué prefieres?\n Reflexiona y conversa tu decisión con la persona que tienes a un lado\n -Tener una cara perfecta pero estar sin piernas los fines de semana y festivos \n -Mejorar un solo aspecto de tu físico que desees pero siempre a las 00:00 te llama una señora de unos 85 años llorando y te cuenta algo triste o terrorífico por 30 años, no puedes colgar, el cuento suele durar unos 45 min',
    '¿Qué prefieres?\n Reflexiona y conversa tu decisión con la persona que tienes a un lado\n -Una lengua grande  \n -Un brazo 5cm más que el otro\n -Una pierna peluda la otra sin pelo por siempre, no se vale depilar con nada', 
    'Posees buena espiritualidad, buena suerte, hoy tienes mucha energía positiva',  
  ];
  final Random _eggRandom = Random();

  // Kelvin brainrot video (dos dedos en appbar)
  final Set<int> _appBarPointers = <int>{};
  Timer? _wouldYouRatherHoldTimer;
  bool _wouldYouRatherCooldown = false;
  Timer? _brainrotHoldTimer;

  @override
  void initState() {
    super.initState();
    _latestFuture = _fetchLatestAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    for (final path in const [
      BrandImages.eggTap,
      BrandImages.eggShake,
      BrandImages.eggOrder,
      BrandImages.eggGlow,
    ]) {
      precacheImage(AssetImage(path), context).catchError((e) {
        debugPrint('❗No se pudo precachear $path: $e');
      });
    }

    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _stopShakeListener();
    _cancelBrainrotHoldTimer();
    _cancelWouldYouRatherHoldTimer();
    _appBarPointers.clear();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // ----- RouteAware: activar/desactivar shake según visibilidad -----
  @override
  void didPush() => _startShakeListener();
  @override
  void didPopNext() => _startShakeListener();
  @override
  void didPushNext() => _stopShakeListener();
  @override
  void didPop() => _stopShakeListener();

  // -----------------------------------------
  // EASTER EGGS
  // -----------------------------------------
  void _onAppBarPointerDown(PointerDownEvent event) {
    _appBarPointers.add(event.pointer);
    if (_appBarPointers.length == 1) {
      _cancelBrainrotHoldTimer();
      if (!_wouldYouRatherCooldown) {
        _startWouldYouRatherHoldTimer();
      }
    } else if (_appBarPointers.length == 2) {
      _cancelWouldYouRatherHoldTimer();
      _startBrainrotHoldTimer();
    } else {
      _cancelWouldYouRatherHoldTimer();
      _cancelBrainrotHoldTimer();
    }
  }

  void _onAppBarPointerUp(PointerEvent event) {
    _appBarPointers.remove(event.pointer);
    if (_appBarPointers.isEmpty) {
      _cancelWouldYouRatherHoldTimer();
      _cancelBrainrotHoldTimer();
      _wouldYouRatherCooldown = false;
    } else if (_appBarPointers.length == 1) {
      _cancelBrainrotHoldTimer();
      if (!_wouldYouRatherCooldown) {
        _startWouldYouRatherHoldTimer();
      }
    } else if (_appBarPointers.length == 2) {
      _cancelWouldYouRatherHoldTimer();
      if (_brainrotHoldTimer == null) {
        _startBrainrotHoldTimer();
      }
    } else {
      _cancelWouldYouRatherHoldTimer();
      _cancelBrainrotHoldTimer();
    }
  }

  void _onAppBarPointerCancel(PointerEvent event) {
    _appBarPointers.remove(event.pointer);
    if (_appBarPointers.isEmpty) {
      _cancelWouldYouRatherHoldTimer();
      _cancelBrainrotHoldTimer();
      _wouldYouRatherCooldown = false;
    } else if (_appBarPointers.length == 1) {
      _cancelBrainrotHoldTimer();
      if (!_wouldYouRatherCooldown) {
        _startWouldYouRatherHoldTimer();
      }
    } else if (_appBarPointers.length == 2) {
      _cancelWouldYouRatherHoldTimer();
      if (_brainrotHoldTimer == null) {
        _startBrainrotHoldTimer();
      }
    } else {
      _cancelWouldYouRatherHoldTimer();
      _cancelBrainrotHoldTimer();
    }
  }

  void _startWouldYouRatherHoldTimer() {
    _wouldYouRatherHoldTimer ??= Timer(const Duration(seconds: 20), () {
      if (!mounted) {
        _cancelWouldYouRatherHoldTimer();
        return;
      }
      if (_appBarPointers.length == 1 && !_wouldYouRatherCooldown) {
        _wouldYouRatherHoldTimer = null;
        _showWouldYouRather();
      } else {
        _cancelWouldYouRatherHoldTimer();
      }
    });
  }

  void _cancelWouldYouRatherHoldTimer() {
    _wouldYouRatherHoldTimer?.cancel();
    _wouldYouRatherHoldTimer = null;
  }

  void _showWouldYouRather() {
    _cancelWouldYouRatherHoldTimer();
    _wouldYouRatherCooldown = true;
    HapticFeedback.mediumImpact();
    _openWouldYouRather();
  }

  void _startBrainrotHoldTimer() {
    _brainrotHoldTimer ??= Timer(const Duration(seconds: 15), () {
      if (!mounted) {
        _cancelBrainrotHoldTimer();
        return;
      }
      if (_appBarPointers.length == 2) {
        _brainrotHoldTimer = null;
        _showBrainrotVideo();
      } else {
        _cancelBrainrotHoldTimer();
      }
    });
  }

  void _cancelBrainrotHoldTimer() {
    _brainrotHoldTimer?.cancel();
    _brainrotHoldTimer = null;
  }

  void _showBrainrotVideo() {
    _cancelBrainrotHoldTimer();
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            const _EggVideoScreen(assetPath: BrandImages.brainrot),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _openEggChecked(
    String asset, {
    bool forceLandscape = true,
  }) async {
    String pathToOpen = BrandImages.eggShake; // fallback
    try {
      await rootBundle.load(asset);
      pathToOpen = asset;
    } catch (e) {
      debugPrint(
        '⚠️ Asset no encontrado ($asset). Fallback a ${BrandImages.eggShake}',
      );
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo egg: $pathToOpen'),
        duration: const Duration(seconds: 12),
      ),
    );

    _openEggFullScreen(pathToOpen, forceLandscape: forceLandscape);
  }

  void _openEggFullScreen(String asset, {bool forceLandscape = true}) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            _EggScreen(assetPath: asset, forceLandscape: forceLandscape),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _openWouldYouRather() {
    final prompt =
        _wouldYouRatherPrompts[_eggRandom.nextInt(
          _wouldYouRatherPrompts.length,
        )];
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .75),
      builder: (_) => _WouldYouRatherEgg(prompt: prompt),
    );
  }

  void _startShakeListener() {
    if (_accelSub != null) return;
    const threshold = 60.0; // cuanto más alto, menos sensible
    const minDelay = Duration(milliseconds: 900);

    _accelSub = accelerometerEvents.listen((e) {
      final dx = e.x - _lastX, dy = e.y - _lastY, dz = e.z - _lastZ;
      _lastX = e.x;
      _lastY = e.y;
      _lastZ = e.z;

      final g = sqrt(dx * dx + dy * dy + dz * dz);
      if (g > threshold) {
        final now = DateTime.now();
        if (now.difference(_lastShakeAt) > minDelay) {
          _lastShakeAt = now;
          HapticFeedback.mediumImpact();
          _openEggChecked(BrandImages.eggShake, forceLandscape: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🐣: ¡Tu equipo de confianza!')),
            );
          }
        }
      }
    });
  }

  void _stopShakeListener() {
    _accelSub?.cancel();
    _accelSub = null;
  }

  void _onTapLogoEgg() {
    final now = DateTime.now();
    if (_eggFirstTapAt == null ||
        now.difference(_eggFirstTapAt!) > const Duration(seconds: 15)) {
      _eggFirstTapAt = now;
      _eggTapCount = 0;
    }
    _eggTapCount++;
    if (_eggTapCount >= 20) {
      _eggTapCount = 0;
      _eggFirstTapAt = null;
      HapticFeedback.lightImpact();
      _openEggChecked(BrandImages.eggTap, forceLandscape: true);
    }
  }

  int _titleTapCount = 0;
  DateTime? _titleFirstTap;
  void _onTitleTap() {
    final now = DateTime.now();
    if (_titleFirstTap == null ||
        now.difference(_titleFirstTap!) > const Duration(seconds: 4)) {
      _titleFirstTap = now;
      _titleTapCount = 0;
    }
    _titleTapCount++;
    if (_titleTapCount >= 7) {
      _titleTapCount = 0;
      _titleFirstTap = null;
      HapticFeedback.selectionClick();
      setState(() => _orderAlt = !_orderAlt);

      _latestFuture = _fetchLatestAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _orderAlt
                  ? 'Modo agrupado por tipo (legado) activado'
                  : 'Modo por fecha (meta publicación) activado',
            ),
            duration: const Duration(seconds: 15),
          ),
        );
      }
      _openEggChecked(BrandImages.eggOrder, forceLandscape: false);
    }
  }

  // -----------------------------------------
  // HELPERS DE FECHA (WordPress + meta)
  // -----------------------------------------
  DateTime? _tryParseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      // epoch: si parece ms, respétalo; si no, segundos
      final isMs = v > 100000000000; // heurística
      return DateTime.fromMillisecondsSinceEpoch(isMs ? v : v * 1000);
    }
    if (v is String) {
      // ¿numérico? => epoch
      final numVal = int.tryParse(v);
      if (numVal != null) return _tryParseDate(numVal);
      // si no, intenta ISO
      return DateTime.tryParse(v);
    }
    return null;
  }

  /// Intenta leer una "fecha de publicación" para ordenar:
  /// - evento: meta.fecha (epoch) -> fallback date
  /// - oferta: meta.fecha_inicio_oferta (epoch) -> fallback date
  /// - noticia/podcast: meta.fecha_publicacion (ISO o epoch) -> fallback date
  DateTime? _wpPublishedAt(Map<String, dynamic> item, LatestType type) {
    final meta = (item['meta'] is Map)
        ? Map<String, dynamic>.from(item['meta'])
        : const <String, dynamic>{};

    DateTime? pickFromMeta() {
      switch (type) {
        case LatestType.evento:
          return _tryParseDate(meta['fecha']);
        case LatestType.oferta:
          return _tryParseDate(meta['fecha_inicio_oferta']);
        case LatestType.noticia:
        case LatestType.podcast:
          return _tryParseDate(meta['fecha_publicacion']);
      }
    }

    return pickFromMeta() ?? _tryParseDate(item['date']);
  }

  // -----------------------------------------
  // DATA (WP para todos los tipos, incl. podcasts)
  // -----------------------------------------
  Future<List<LatestItem>> _fetchWpItems(
    String baseUrl,
    LatestType type, {
    int perPage = 3,
  }) async {
    final hasQuery = baseUrl.contains('?');
    final url = hasQuery
        ? '$baseUrl&_embed&per_page=$perPage&status=publish'
        : '$baseUrl?_embed&per_page=$perPage&status=publish';

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) return [];

    final data = json.decode(resp.body);
    if (data is! List) return [];

    final stripHtml = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);

    return data.map<LatestItem>((rawItem) {
      final item = Map<String, dynamic>.from(rawItem);

      final title = (item['title']?['rendered'] ?? '').toString();
      final metaDesc =
          (item['meta'] is Map && (item['meta']['descripcion'] is String))
          ? item['meta']['descripcion'] as String
          : null;

      final bool hasMetaDesc = metaDesc != null && metaDesc.trim().isNotEmpty;

      final String excerptHtml = (type == LatestType.noticia && hasMetaDesc)
          ? metaDesc
          : (item['descripcion'] ??
                    item['excerpt']?['rendered'] ??
                    item['content']?['rendered'] ??
                    '')
                .toString();

      final excerpt = excerptHtml
          .replaceAll(stripHtml, ' ')
          .replaceAll('&nbsp;', ' ')
          .trim();

      String? image;
      try {
        image = item['_embedded']?['wp:featuredmedia']?[0]?['source_url']
            ?.toString();
      } catch (_) {
        image = null;
      }

      final publishedAt = _wpPublishedAt(item, type);

      return LatestItem(
        type: type,
        title: _decodeHtml(title),
        excerpt: _decodeHtml(excerpt),
        imageUrl: image,
        raw: item,
        publishedAt: publishedAt,
      );
    }).toList();
  }

  String _decodeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&#038;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', '’')
        .replaceAll('&#8211;', '–')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  /// => NUEVO: mezcla 3 de cada tipo y ordena por 'publishedAt' desc
  Future<List<LatestItem>> _fetchLatestAll() async {
    // Traemos 3 por tipo
    final podcastsF = _fetchWpItems(
      widget.podcastsUrl,
      LatestType.podcast,
      perPage: 3,
    );
    final noticiasF = _fetchWpItems(
      widget.noticiasUrl,
      LatestType.noticia,
      perPage: 3,
    );
    final eventosF = _fetchWpItems(
      widget.eventosUrl,
      LatestType.evento,
      perPage: 3,
    );
    final ofertasF = _fetchWpItems(
      widget.ofertasUrl,
      LatestType.oferta,
      perPage: 3,
    );

    final podcasts = await podcastsF;
    final noticias = await noticiasF;
    final eventos = await eventosF;
    final ofertas = await ofertasF;

    if (_orderAlt) {
      // Modo legacy agrupado (por si quieres comparar)
      return [...podcasts, ...noticias, ...eventos, ...ofertas];
    }

    // Mezcla y ordena por publishedAt desc
    final merged = <LatestItem>[
      ...podcasts,
      ...noticias,
      ...eventos,
      ...ofertas,
    ];

    final minDt = DateTime.fromMillisecondsSinceEpoch(0);
    merged.sort((a, b) {
      final ad = a.publishedAt ?? minDt;
      final bd = b.publishedAt ?? minDt;
      return bd.compareTo(ad); // desc
    });

    // Nos quedamos con los mismos 12 (3 por tipo, intercalados por fecha)
    return merged.take(12).toList();
  }

  // -----------------------------------------
  // NAV
  // -----------------------------------------
  void _openDetail(LatestItem item) {
    switch (item.type) {
      case LatestType.podcast:
        final int id = item.raw['id'] is int
            ? item.raw['id'] as int
            : int.tryParse('${item.raw['id']}') ?? -1;
        if (id <= -1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID de podcast inválido')),
          );
          return;
        }
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PodcastDetailScreen(id: id)));
        break;

      case LatestType.noticia:
        final int id = item.raw['id'] is int
            ? item.raw['id'] as int
            : int.tryParse('${item.raw['id']}') ?? -1;
        if (id <= -1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID de noticia inválido')),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(
              name: 'noticias_detail_v2_from_dashboard',
            ),
            builder: (_) => NoticiasDetailScreenV2(id: id),
          ),
        );
        break;

      case LatestType.evento:
        final adapter = _EventoAdapter.fromWp(item.raw);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventoDetailScreen(evento: adapter),
          ),
        );
        break;

      case LatestType.oferta:
        final Map<String, dynamic> post =
            // ignore: dead_code, unnecessary_type_check
            (item.raw is Map<String, dynamic>)
            ? item.raw
            : Map<String, dynamic>.from(item.raw as Map);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OfertaDetailScreen.fromWp(post: post),
          ),
        );
        break;
    }
  }

  // -----------------------------------------
  // UI
  // -----------------------------------------
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onAppBarPointerDown,
          onPointerUp: _onAppBarPointerUp,
          onPointerCancel: _onAppBarPointerCancel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTapLogoEgg, // 20 taps
            child: SizedBox(
              height: kToolbarHeight,
              width: double.infinity,
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          GestureDetector(
            onTap: _onTitleTap, // 7 taps para cambiar modo
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Últimas Novedades',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<LatestItem>>(
            future: _latestFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingSlider();
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return const _EmptyState(message: 'No hay novedades todavía.');
              }
              return SizedBox(
                height: 300,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) => _LatestCard(
                    item: items[i],
                    onTap: () => _openDetail(items[i]),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Destacados',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            children: [
              _StoryTile(
                label: 'Podcast',
                icon: Icons.mic_rounded,
                background: const AssetImage(BrandImages.podcast),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PodcastsListScreen(),
                    ),
                  );
                },
              ),

              _StoryTile(
                label: 'Signolia Pro',
                icon: Icons.workspace_premium_rounded,
                background: const AssetImage(BrandImages.pro),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SignoliaProScreen(),
                    ),
                  );
                },
              ),
              _StoryTile(
                label: 'Plataforma de Empleo',
                icon: Icons.work_outline_rounded,
                background: const AssetImage(BrandImages.empleo),
                onTap: () => _openUrl('https://empleo.signolia.com/'),
              ),
              _StoryTile(
                label: 'Ordenanzas OPE',
                icon: Icons.gavel_rounded,
                background: const AssetImage(BrandImages.ope),
                onTap: () =>
                    _openUrl('https://ordenanzapublicidadexterior.com/'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }
}

class _LatestCard extends StatelessWidget {
  final LatestItem item;
  final VoidCallback onTap;
  const _LatestCard({required this.item, required this.onTap});

  Color get _badgeColor {
    switch (item.type) {
      case LatestType.podcast:
        return BrandColors.primary;
      case LatestType.noticia:
        return BrandColors.secondary;
      case LatestType.evento:
        return BrandColors.primary;
      case LatestType.oferta:
        return BrandColors.accent;
    }
  }

  String get _badgeText {
    switch (item.type) {
      case LatestType.podcast:
        return 'PODCAST';
      case LatestType.noticia:
        return 'NOTICIAS';
      case LatestType.evento:
        return 'EVENTOS';
      case LatestType.oferta:
        return 'OFERTAS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasImage = (item.imageUrl ?? '').isNotEmpty;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.82,
      child: Material(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: hasImage
                      ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                      : const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.black38,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeColor.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _badgeColor.withValues(alpha: .35),
                          ),
                        ),
                        child: Text(
                          _badgeText,
                          style: t.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _badgeColor,
                            letterSpacing: .3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BrandColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.excerpt.isEmpty ? ' ' : item.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
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

class _LoadingSlider extends StatelessWidget {
  const _LoadingSlider();

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: MediaQuery.of(context).size.width * 0.82,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(height: 120, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(height: 16, color: Colors.black12),
                const SizedBox(height: 10),
                Container(height: 12, color: Colors.black12),
              ],
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (_, __) => card,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemCount: 3,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      height: 120,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        message,
        style: t.bodyMedium?.copyWith(color: Colors.grey.shade700),
      ),
    );
  }
}

// ======================================================================
// ADAPTERS
// ======================================================================
String? _epochToIsoStr(dynamic v) {
  if (v == null) return null;
  try {
    final s = v.toString();
    final sec = int.parse(s);
    return DateTime.fromMillisecondsSinceEpoch(sec * 1000).toIso8601String();
  } catch (_) {
    return null;
  }
}

class _EventoAdapter {
  final Map<String, dynamic> _post;
  _EventoAdapter._(this._post);
  factory _EventoAdapter.fromWp(Map<String, dynamic> post) {
    return _EventoAdapter._(Map<String, dynamic>.from(post));
  }
  String? _embeddedImage() {
    try {
      return _post['_embedded']?['wp:featuredmedia']?[0]?['source_url']
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  String get titulo => (_post['title']?['rendered'] ?? '').toString();
  String get descripcionHtml =>
      (_post['descripcion'] ??
              _post['content']?['rendered'] ??
              _post['excerpt']?['rendered'] ??
              '')
          .toString();
  String? get imagenDestacada => _embeddedImage();
  String? get fechaInicio =>
      _epochToIsoStr(_post['fecha']) ?? _post['date']?.toString();
  String? get fechaFin => _epochToIsoStr(_post['fecha_fin']);
  String? get ubicacion =>
      _post['ubicacion']?.toString() ?? _post['localizacion']?.toString();
  String? get linkRegistro => _post['link_registro']?.toString();
  String? get emailOrganizador => _post['email_organizador']?.toString();
  String? get webOrganizador => _post['web_del_organizador_']?.toString();
  String? get facebook => _post['facebook']?.toString();
  String? get instagram => _post['instagram']?.toString();
  String? get twitter => _post['twitter']?.toString();
  String? get youtube => _post['youtube']?.toString();
}

class _OfertaAdapter {
  final Map<String, dynamic> _post;
  _OfertaAdapter._(this._post);
  factory _OfertaAdapter.fromWp(Map<String, dynamic> post) {
    return _OfertaAdapter._(Map<String, dynamic>.from(post));
  }
  String? _embeddedImage() {
    try {
      return _post['_embedded']?['wp:featuredmedia']?[0]?['source_url']
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  String get titulo => (_post['title']?['rendered'] ?? '').toString();
  String get descripcionHtml =>
      (_post['descripcion_oferta'] ??
              _post['informacion_basica'] ??
              _post['content']?['rendered'] ??
              _post['excerpt']?['rendered'] ??
              '')
          .toString();
  String? get imagenDestacada => _embeddedImage();
  String? get empresa => _post['nombre_empresa_oferta']?.toString();
  String? get direccion => _post['direccion_de_la_empresa']?.toString();
  String? get email => _post['email_empresa_oferta']?.toString();
  String? get telefono => _post['telefono_empresa_oferta']?.toString();
  String? get web => _post['web_oferta_empresa']?.toString();
  String? get fechaPublicacion =>
      _epochToIsoStr(_post['fecha_inicio_oferta']) ?? _post['date']?.toString();
  String? get fechaCierre => _epochToIsoStr(_post['fecha_fin_oferta']);
  String? get ubicacion => _post['direccion_de_la_empresa']?.toString();
  String? get descuento => _post['descuento_oferta']?.toString();
  String? get linkOferta => _post['link_oferta']?.toString();
  String get estaActiva => 'true';
}

class _StoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final ImageProvider background;
  final VoidCallback onTap;

  const _StoryTile({
    required this.label,
    required this.icon,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFF5F5F5),
            image: DecorationImage(
              image: background,
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.35),
                BlendMode.darken,
              ),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  icon,
                  size: 72,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== Egg Screen common ======================
class _EggScreen extends StatefulWidget {
  const _EggScreen({required this.assetPath, this.forceLandscape = true});
  final String assetPath;
  final bool forceLandscape;

  @override
  State<_EggScreen> createState() => _EggScreenState();
}

class _EggScreenState extends State<_EggScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.forceLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    if (widget.forceLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset(widget.assetPath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _EggVideoScreen extends StatefulWidget {
  const _EggVideoScreen({required this.assetPath});

  final String assetPath;

  @override
  State<_EggVideoScreen> createState() => _EggVideoScreenState();
}

class _EggVideoScreenState extends State<_EggVideoScreen> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Center(
          child: isReady
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio == 0
                      ? 16 / 9
                      : _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(),
                ),
        ),
      ),
    );
  }
}

// ====================== Nuevo egg: Que prefieres...? (seguro) ======================
class _WouldYouRatherEgg extends StatelessWidget {
  const _WouldYouRatherEgg({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Que prefieres...?',
              style: (t.titleLarge ?? const TextStyle()).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                prompt,
                style: (t.bodyLarge ?? const TextStyle()).copyWith(
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
