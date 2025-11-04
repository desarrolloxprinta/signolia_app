import '../../core/cache/simple_cache.dart';

import 'podcast_model.dart';
import 'podcast_service.dart';

/// Gestor de cache y fetch para la lista de podcasts.
class PodcastRepository {
  PodcastRepository({PodcastService? service, SimpleCache? cache})
    : _service = service ?? PodcastService(),
      _cache = cache ?? SimpleCache.instance;

  final PodcastService _service;
  final SimpleCache _cache;

  static const _cacheKeyFirstPage = 'podcasts_page_1_v1';
  static const _ttl = Duration(minutes: 30);
  static String _detailKey(int id) => 'podcast_detail_${id}_v1';

  /// Obtiene una pagina de podcasts, usando cache si aplica.
  Future<List<PodcastItem>> fetchPage(
    int page, {
    int perPage = 8,
    bool forceRefresh = false,
  }) async {
    if (page == 1 && !forceRefresh) {
      final cached = await getCachedPage(page);
      if (cached != null) return cached;
    }

    final fresh = await _service.fetchList(page: page, perPage: perPage);
    if (page == 1 && fresh.isNotEmpty) {
      await _saveFirstPage(fresh);
    }
    return fresh;
  }

  /// Devuelve la pagina cacheada si esta vigente (solo primera pagina).
  Future<List<PodcastItem>?> getCachedPage(int page) async {
    if (page != 1) return null;
    final payload = await _cache.read(_cacheKeyFirstPage, _ttl);
    if (payload is! Map) return null;

    try {
      final items = (payload['items'] as List<dynamic>)
          .map(
            (entry) =>
                PodcastItem.fromCache(Map<String, dynamic>.from(entry as Map)),
          )
          .toList();

      return items;
    } catch (_) {
      return null;
    }
  }

  Future<PodcastItem> fetchDetail(int id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.read(_detailKey(id), _ttl);
      if (cached is Map<String, dynamic>) {
        return PodcastItem.fromCache(Map<String, dynamic>.from(cached));
      }
    }

    final fresh = await _service.fetchPodcast(id);
    await _cache.write(_detailKey(id), fresh.toCacheMap());
    return fresh;
  }

  /// Permite limpiar la cache (por ejemplo al cerrar sesion).
  Future<void> clearCache() async {
    await _cache.clear(_cacheKeyFirstPage);
  }

  Future<void> _saveFirstPage(List<PodcastItem> items) async {
    await _cache.write(_cacheKeyFirstPage, {
      'items': items.map((item) => item.toCacheMap()).toList(),
    });
  }

  Future<void> clearDetail(int id) async {
    await _cache.clear(_detailKey(id));
  }
}
