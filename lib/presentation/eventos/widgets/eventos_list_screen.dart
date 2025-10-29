// lib/presentation/eventos/widgets/eventos_list_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/env.dart';
import 'evento_detail_screen.dart';



class BrandColors {
  static const primary   = Color(0xFF347778);
  static const secondary = Color(0xFFEF7F1A);
  static const text      = Color(0xFF0C0B0B);
  static const accent    = Color(0xFF347778);
}

/// === Reemplazo mínimo del servicio original ===
/// Mantiene la misma firma para no tocar tu lógica.
class PageData {
  final List<Map<String, dynamic>> items;
  final int totalPages;
  PageData({required this.items, required this.totalPages});
}

class WpService {
  Future<PageData> fetchPage(
    String baseUrl, {
    required int page,
    int perPage = 10,
    bool embed = true,
  }) async {
    final hasQuery = baseUrl.contains('?');
    final params = <String>[
      if (embed) '_embed=1',
      'status=publish',          // ✅ solo publicados
      'per_page=$perPage',
      'page=$page',
    ].join('&');

    final url = hasQuery ? '$baseUrl&$params' : '$baseUrl?$params';
    final res = await http.get(Uri.parse(url));

    // WP envía número de páginas en X-WP-TotalPages (o minúsculas según server)
    int totalPages = 1;
    final hdr = res.headers;
    final tp = hdr['x-wp-totalpages'] ?? hdr['X-WP-TotalPages'] ?? hdr['x-wp-total-pages'];
    if (tp != null) {
      final parsed = int.tryParse(tp);
      if (parsed != null && parsed > 0) totalPages = parsed;
    }

    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      final list = (body is List) ? body : <dynamic>[];
      final items = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return PageData(items: items, totalPages: totalPages);
    }

    // WP suele devolver 400/404 cuando la página no existe (fin de lista)
    if (res.statusCode == 400 || res.statusCode == 404) {
      return PageData(items: const [], totalPages: totalPages);
    }

    throw Exception('HTTP ${res.statusCode}');
  }
}

class EventosListScreen extends StatefulWidget {
  const EventosListScreen({super.key});

  @override
  State<EventosListScreen> createState() => _EventosListScreenState();
}

class _EventosListScreenState extends State<EventosListScreen> {
  final _svc   = WpService();
  final _items = <Map<String, dynamic>>[];

  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _error   = false;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (refresh) {
        _error = false;
        _page = 1;
        _items.clear();
      }
    });

    try {
      final pageData = await _svc.fetchPage(
        Env.cptEventos,
        page: _page,
        perPage: 10,
        embed: true,
      );
      _totalPages = pageData.totalPages;
      _items.addAll(pageData.items);
      _page++;
    } catch (_) {
      _error = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ——— Helpers ———

  String _plain(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  String? _image(Map<String, dynamic> item) {
    try {
      final media = item['_embedded']?['wp:featuredmedia'];
      if (media is List && media.isNotEmpty) {
        final src = media[0]?['source_url'];
        if (src is String && src.isNotEmpty) return src;
      }
    } catch (_) {}
    return null;
  }

  /// Lee fecha en epoch (segundos) o ISO8601. Devuelve dd/mm/yyyy o ''.
  String _fmtDate(dynamic v) {
    if (v == null) return '';
    // Epoch en string/num
    if (v is num) {
      try {
        final d = DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000, isUtc: true).toLocal();
        return '${d.day}/${d.month}/${d.year}';
      } catch (_) {}
    }
    if (v is String) {
      // ¿epoch en string?
      final asInt = int.tryParse(v);
      if (asInt != null) {
        try {
          final d = DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true).toLocal();
          return '${d.day}/${d.month}/${d.year}';
        } catch (_) {}
      }
      // ¿ISO?
      try {
        final d = DateTime.parse(v).toLocal();
        return '${d.day}/${d.month}/${d.year}';
      } catch (_) {}
    }
    return '';
  }

  /// Construye el rango de fechas 'ini - fin' si procede.
  String _dateRange(Map<String, dynamic> item) {
    // tus campos: fecha (inicio) y fecha_fin (fin) pueden venir como epoch (string)
    final ini = _fmtDate(item['fecha'] ?? item['fecha_inicio'] ?? item['date']);
    final fin = _fmtDate(item['fecha_fin']);
    if (ini.isNotEmpty && fin.isNotEmpty) return '$ini - $fin';
    if (ini.isNotEmpty) return ini;
    if (fin.isNotEmpty) return fin;
    return '';
  }

  String _ubicacion(Map<String, dynamic> item) {
    // tus eventos usan 'ubicacion' como string
    final u = item['ubicacion'];
    return (u is String) ? u.trim() : '';
  }

  String _excerpt(Map<String, dynamic> item) {
    // prioriza `descripcion` (campo largo), luego excerpt.rendered, luego content.rendered
    final raw = (item['descripcion'] ??
            item['excerpt']?['rendered'] ??
            item['content']?['rendered'] ??
            '')
        .toString();
    return _plain(raw);
  }

  bool get _canLoadMore => _page <= _totalPages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: _error
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  const Center(child: Text('Error al cargar eventos')),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (sn) {
                  if (!_loading &&
                      _canLoadMore &&
                      sn.metrics.pixels >= sn.metrics.maxScrollExtent - 300) {
                    _load();
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _items.length) {
                      if (_loading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (_canLoadMore) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: _load,
                              child: const Text('Cargar más'),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }

                    final item   = _items[i];
                    final title  = _plain(item['title']?['rendered'] ?? '');
                    final img    = _image(item);
                    final rango  = _dateRange(item);
                    final ubic   = _ubicacion(item);
                    final resume = _excerpt(item);

                    return _EventoTile(
                      title: title,
                      subtitle: resume,
                      imageUrl: img,
                      dateText: rango,
                      location: ubic,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventoDetailScreen.fromWp(post: item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _EventoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String dateText;
  final String location;
  final VoidCallback onTap;

  const _EventoTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.dateText,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      color: const Color(0xFFF5F5F5),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: Image.network(
                  imageUrl!,
                  width: 116,
                  height: 176,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 116,
                height: 116,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAEAEA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chip EVENTO
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BrandColors.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'EVENTO',
                        style: t.labelSmall?.copyWith(
                          color: BrandColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Título
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),

                    // Rango de fechas + ubicación en una línea (si existen)
                    if (dateText.isNotEmpty || location.isNotEmpty) ...[
                      Row(
                        children: [
                          if (dateText.isNotEmpty) ...[
                            const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.black54),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                dateText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 16, color: Colors.black54),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                    ],

                    // Resumen (2 líneas)
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
