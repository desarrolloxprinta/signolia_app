// lib/presentation/eventos/widgets/eventos_list_screen.dart
import 'package:flutter/material.dart';

import '../../../features/eventos/eventos_repository.dart';
import 'evento_detail_screen.dart';

class BrandColors {
  static const primary = Color(0xFF347778);
  static const secondary = Color(0xFFEF7F1A);
  static const text = Color(0xFF0C0B0B);
  static const accent = Color(0xFF347778);
}

class EventosListScreen extends StatefulWidget {
  const EventosListScreen({super.key});

  @override
  State<EventosListScreen> createState() => _EventosListScreenState();
}

class _EventosListScreenState extends State<EventosListScreen> {
  final EventosRepository _repository = EventosRepository();
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _error = false;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _primeFromCache();
  }

  Future<void> _primeFromCache() async {
    final cached = await _repository.getCachedFirstPage();
    if (!mounted) return;

    if (cached != null && cached.items.isNotEmpty) {
      setState(() {
        _items
          ..clear()
          ..addAll(cached.items);
        _totalPages = cached.totalPages;
        _page = 2;
      });
    }

    _bootstrapped = true;
    await _load(
      refresh: true,
      keepExisting: cached != null && cached.items.isNotEmpty,
    );
  }

  Future<void> _load({bool refresh = false, bool keepExisting = false}) async {
    if (_loading || (!_bootstrapped && !refresh)) return;
    setState(() {
      _loading = true;
      if (refresh) {
        _error = false;
        _page = 1;
        if (!keepExisting) {
          _items.clear();
        }
      }
    });

    try {
      final targetPage = refresh ? 1 : _page;
      final pageData = await _repository.fetchPage(
        targetPage,
        perPage: 10,
        forceRefresh: refresh,
      );

      if (refresh) {
        _items
          ..clear()
          ..addAll(pageData.items);
        _page = 2;
      } else {
        _items.addAll(pageData.items);
        _page++;
      }
      _totalPages = pageData.totalPages;
    } catch (_) {
      _error = true;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      } else {
        _loading = false;
      }
    }
  }

  Future<void> _onRefresh() async {
    await _load(refresh: true, keepExisting: true);
  }

  bool get _canLoadMore => _page <= _totalPages;

  String _plain(String? html) => (html ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();

  String? _image(Map<String, dynamic> item) {
    try {
      final embedded = item['_embedded'];
      if (embedded is Map) {
        final media = embedded['wp:featuredmedia'];
        if (media is List && media.isNotEmpty) {
          final src = media[0]?['source_url'];
          if (src is String && src.isNotEmpty) return src;
        }
      }
    } catch (_) {}
    return null;
  }

  String _dateRange(Map<String, dynamic> item) {
    DateTime? parseTs(dynamic value) {
      if (value == null) return null;
      final str = value.toString();
      if (str.isEmpty) return null;
      final ts = int.tryParse(str);
      if (ts == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    }

    final meta = item['meta'];
    final start = parseTs(
      item['fecha'] ?? (meta is Map ? meta['fecha'] : null),
    );
    final end = parseTs(
      item['fecha_fin'] ?? (meta is Map ? meta['fecha_fin'] : null),
    );

    String fmt(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    if (start == null && end == null) return '';
    if (start != null && end != null) {
      if (start.isAtSameMomentAs(end)) return fmt(start);
      return '${fmt(start)} - ${fmt(end)}';
    }
    return fmt(start ?? end!);
  }

  String _ubicacion(Map<String, dynamic> item) {
    final meta = item['meta'];
    final raw =
        item['ubicacion'] ??
        (meta is Map ? meta['ubicacion'] : null) ??
        item['direccion'] ??
        (meta is Map ? meta['direccion'] : null);
    return (raw ?? '').toString().trim();
  }

  String _excerpt(Map<String, dynamic> item) {
    final excerpt = item['excerpt'];
    if (excerpt is Map) {
      return _plain(excerpt['rendered']?.toString());
    }
    final content = item['content'];
    if (content is Map) {
      return _plain(content['rendered']?.toString());
    }
    final meta = item['meta'];
    final resumen =
        (meta is Map ? meta['resumen'] : null) ?? item['descripcion'];
    return _plain(resumen?.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
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
                              onPressed: () => _load(),
                              child: const Text('Cargar mas'),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }

                    final item = _items[i];
                    final title = _plain(item['title']?['rendered'] ?? '');
                    final img = _image(item);
                    final rango = _dateRange(item);
                    final ubic = _ubicacion(item);
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
                            builder: (_) =>
                                EventoDetailScreen.fromWp(post: item),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                    // T??tulo
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Rango de fechas + ubicaci??n en una l??nea (si existen)
                    if (dateText.isNotEmpty || location.isNotEmpty) ...[
                      Row(
                        children: [
                          if (dateText.isNotEmpty) ...[
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                dateText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                    ],

                    // Resumen (2 l??neas)
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
