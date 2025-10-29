import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/env.dart';
import 'podcast_model.dart';

class PodcastService {
  final String base = Env.cptPodcasts;// Asegúrate de tenerlo en env.dart, p.ej.: https://signolia.com/wp-json/wp/v2/podcast

  /// ===== LISTA (ya la tendrás) =====
  Future<List<PodcastItem>> fetchList({int page = 1, int perPage = 10}) async {
    final uri = Uri.parse('$base?_embed=1&status=publish&page=$page&per_page=$perPage');
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    if (data is! List) return [];

    final items = <PodcastItem>[];
    for (final it in data) {
      final map = Map<String, dynamic>.from(it);
      final thumb = await _resolveMiniaturaUrl(map);
      final item = PodcastItem.fromWp(map, resolvedThumbnailUrl: thumb);
      items.add(item);
    }
    return items;
  }

  /// ===== DETALLE (FALTABA) =====
  Future<PodcastItem> fetchPodcast(int id) async {
    // 1) post
    final postUri = Uri.parse('$base/$id?_embed=1');
    final postRes = await http.get(postUri);
    if (postRes.statusCode != 200) {
      throw Exception('No se pudo cargar el podcast $id');
    }
    final map = Map<String, dynamic>.from(jsonDecode(postRes.body));

    // 2) miniatura
    final thumb = await _resolveMiniaturaUrl(map);

    // 3) invitados (via JetEngine)
    final guestIds = await _getGuestIds(id);
    final guests = <PodcastGuest>[];
    for (final gid in guestIds) {
  final g = await _fetchGuest(gid);
  if (g != null) guests.add(g);
}

    // 4) segmentos & enlaces
    final segments = _parseSegments(map);
    final links = _parseLinks(map);

    return PodcastItem.fromWp(
      map,
      resolvedThumbnailUrl: thumb,
      guests: guests,
      segments: segments,
      links: links,
    );
  }

  /// ====== MINIATURA desde meta['miniatura'] (media ID) ======
  Future<String?> _resolveMiniaturaUrl(Map<String, dynamic> post) async {
    String? idStr;
    final meta = (post['meta'] is Map<String, dynamic>) ? post['meta'] as Map<String, dynamic> : post;

    // meta['miniatura'] o post['miniatura']
    if (meta['miniatura'] != null) idStr = meta['miniatura'].toString();
    if ((idStr == null || idStr.isEmpty) && post['miniatura'] != null) {
      idStr = post['miniatura'].toString();
    }
    if (idStr == null || idStr.isEmpty) return null;
    final mediaId = int.tryParse(idStr);
    if (mediaId == null) return null;

    final mRes = await http.get(Uri.parse('${Env.wpMedia}/$mediaId')); // ✅ Env.wpMedia
    if (mRes.statusCode != 200) return null;
    final m = jsonDecode(mRes.body);
    return (m['source_url'] ?? m['media_details']?['sizes']?['full']?['source_url'])?.toString();
  }

  /// ====== Invitados desde JetEngine Relations ======
  Future<List<int>> _getGuestIds(int podcastId) async {
    final jetBase = '${Env.baseUrl}/wp-json/jet-rel/16';                // ✅ Env.baseUrl
    final res = await http.get(Uri.parse('$jetBase/children/$podcastId'));
    if (res.statusCode != 200) return const [];

    final body = jsonDecode(res.body);
    return _extractIdsFromJetBody(body);
  }

  List<int> _extractIdsFromJetBody(dynamic body) {
    // Soporta tu forma: [{"child_object_id":"11089"},{...}]
    final ids = <int>{};
    void walk(dynamic node) {
      if (node is List) {
        for (final e in node) {
          walk(e);
        }
        return;
      }
      if (node is Map) {
        final v = node['child_object_id'] ?? node['child_id'] ?? node['to_id'] ?? node['id'] ?? node['post_id'];
        if (v != null) {
          final s = v.toString();
          final n = int.tryParse(s);
          if (n != null && n > 0) ids.add(n);
        }
        for (final val in node.values) {
          if (val is List || val is Map) walk(val);
        }
      }
    }
    walk(body);
    return ids.toList();
  }

  Future<PodcastGuest?> _fetchGuest(int id) async {
    final uri = Uri.parse('${Env.wpInvitados}/$id?_embed=1');          // ✅ Env.wpInvitados
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final map = Map<String, dynamic>.from(jsonDecode(res.body));

    // avatar desde _embedded.wp:featuredmedia[0].source_url
    String? avatar;
    try {
      avatar = map['_embedded']?['wp:featuredmedia']?[0]?['source_url']?.toString();
    } catch (_) {}

    return PodcastGuest.fromWp(map, resolvedAvatar: avatar);
  }

  /// ====== Segmentos: 'resumen-de-capitulo' o 'resumen-de-capitulo' en meta ======
  List<PodcastSegment> _parseSegments(Map<String, dynamic> post) {
    final meta = (post['meta'] is Map<String, dynamic>) ? post['meta'] as Map<String, dynamic> : post;
    final raw = meta['resumen-de-capitulo'] ?? post['resumen-de-capitulo'] ?? meta['resumen-de-capitulo'] ?? post['resumen'] ?? '';
    if (raw is String && raw.isEmpty) return const [];

    Map<String, dynamic> map;
    try {
      map = (raw is String) ? Map<String, dynamic>.from(jsonDecode(raw)) : Map<String, dynamic>.from(raw);
    } catch (_) {
      return const [];
    }
    final segments = <PodcastSegment>[];
    final keys = map.keys.toList()..sort();
    for (final k in keys) {
      final item = map[k];
      if (item is Map) {
        final time = item['tiempo']?.toString();
        final resumenHtml = (item['resumen'] ?? '').toString();
        final title = _stripHtml(resumenHtml).split('\n').first.trim();
        if (title.isNotEmpty) {
          segments.add(PodcastSegment(time: time, title: title));
        }
      }
    }
    return segments;
  }

  /// ====== Enlaces relacionados: 'enlaces' (repeater) ======
  List<PodcastLink> _parseLinks(Map<String, dynamic> post) {
    final meta = (post['meta'] is Map<String, dynamic>) ? post['meta'] as Map<String, dynamic> : post;
    final raw = meta['enlaces'] ?? post['enlaces'];
    if (raw == null) return const [];
    Map<String, dynamic> map;
    try {
      map = (raw is String) ? Map<String, dynamic>.from(jsonDecode(raw)) : Map<String, dynamic>.from(raw);
    } catch (_) {
      return const [];
    }
    final links = <PodcastLink>[];
    for (final e in map.values) {
      if (e is Map) {
        final url = (e['enlace-'] ?? e['url'] ?? '').toString();
        final title = (e['titulo-de-enlace-relacionado'] ?? e['titulo'] ?? '').toString();
        if (url.isNotEmpty) {
          links.add(PodcastLink(url: url, title: title.isEmpty ? null : title));
        }
      }
    }
    return links;
  }

  static String _stripHtml(String html) {
    final reg = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return html
        .replaceAll(reg, ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#038;', '&')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', '’')
        .replaceAll('&#8211;', '–')
        .trim();
  }
}
