// lib/presentation/noticias/widgets/noticias_list_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../features/noticias/noticias_repository.dart';
import 'noticia_detail_screen.dart'; // -> NoticiasDetailScreenV2
// ajusta el import real

class NoticiasListScreenV2 extends StatefulWidget {
  const NoticiasListScreenV2({super.key});

  @override
  State<NoticiasListScreenV2> createState() => _NoticiasListScreenV2State();
}

class _NoticiasListScreenV2State extends State<NoticiasListScreenV2> {
  final NoticiasRepository _repository = NoticiasRepository();
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = false;
  bool _error = false;
  int _page = 1;
  int _totalPages = 1;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[Noticias] init list');
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
    } catch (e) {
      if (kDebugMode) debugPrint('[Noticias] error: $e');
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

  // helpers
  String _plain(String? html) => (html ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();

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

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugPrint('[Noticias] build list');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _error
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  const Center(child: Text('Error al cargar noticias')),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : (_items.isEmpty && _loading)
            ? const Center(child: CircularProgressIndicator())
            : (_items.isEmpty)
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No hay noticias por ahora')),
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
                              child: const Text('Cargar m??s'),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }

                    final it = _items[i];
                    final title = _plain(it['title']?['rendered'] as String?);
                    final excerpt =
                        _plain(
                          (it['descripcion'] as String?) ??
                              (it['excerpt']?['rendered'] as String?) ??
                              (it['content']?['rendered'] as String?),
                        ) ??
                        '';
                    final img = _image(it);
                    final id = (it['id'] as int?) ?? 0;

                    return _NoticiaTile(
                      title: title,
                      excerpt: excerpt,
                      imageUrl: img,
                      onTap: () {
                        if (kDebugMode) {
                          debugPrint('[Noticias] push detalle id=$id');
                        }
                        NoticiasDetailScreenV2.push(context, id: id);
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _NoticiaTile extends StatelessWidget {
  final String title;
  final String excerpt;
  final String? imageUrl;
  final VoidCallback onTap;

  const _NoticiaTile({
    required this.title,
    required this.excerpt,
    required this.imageUrl,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                child: Image.network(
                  imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAEAEA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chip NOTICIA
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'NOTICIA',
                      style: t.labelSmall?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (excerpt.isNotEmpty)
                    Text(
                      excerpt,
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
          ],
        ),
      ),
    );
  }
}
