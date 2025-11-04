import '../../core/cache/simple_cache.dart';
import '../../core/env.dart';
import '../../core/wp/wp_client.dart';
import 'oferta_model.dart';

class OfertasPage {
  OfertasPage({required this.items, required this.totalPages});

  final List<Oferta> items;
  final int totalPages;
}

class OfertasRepository {
  OfertasRepository({WpClient? client, SimpleCache? cache})
    : _client = client ?? WpClient(),
      _cache = cache ?? SimpleCache.instance;

  final WpClient _client;
  final SimpleCache _cache;

  static const _cacheKey = 'ofertas_page_1_v1';
  static const _ttl = Duration(minutes: 30);

  Future<OfertasPage?> getCachedFirstPage() async {
    final payload = await _cache.read(_cacheKey, _ttl);
    if (payload is! Map) return null;

    try {
      final rawItems = (payload['items'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final total = (payload['totalPages'] as num?)?.toInt() ?? 1;
      final items = rawItems.map(Oferta.fromJson).toList();
      return OfertasPage(items: items, totalPages: total);
    } catch (_) {
      return null;
    }
  }

  Future<OfertasPage> fetchPage(
    int page, {
    int perPage = 10,
    bool forceRefresh = false,
  }) async {
    if (page == 1 && !forceRefresh) {
      final cached = await getCachedFirstPage();
      if (cached != null) return cached;
    }

    final fresh = await _client.fetchPage(
      Env.cptOfertas,
      page: page,
      perPage: perPage,
      embed: true,
    );
    final items = fresh.items.map(Oferta.fromJson).toList();

    if (page == 1) {
      await _cache.write(_cacheKey, {
        'items': fresh.items,
        'totalPages': fresh.totalPages,
      });
    }

    return OfertasPage(items: items, totalPages: fresh.totalPages);
  }

  Future<void> clearCache() => _cache.clear(_cacheKey);
}
