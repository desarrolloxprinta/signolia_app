import 'package:intl/intl.dart';

class WpNoticia {
  final int id;
  final String title;
  final String? excerpt;
  final String? featuredUrl;
  final DateTime date;
  final String? categoria;

  WpNoticia({
    required this.id,
    required this.title,
    required this.date,
    this.excerpt,
    this.featuredUrl,
    this.categoria,
  });

  static String? _featuredFromEmbedded(Map<String, dynamic> json) {
    try {
      final emb = json['_embedded']?['wp:featuredmedia'] as List?;
      if (emb != null && emb.isNotEmpty) {
        return emb.first['source_url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static String? _categoriaFromClasses(Map<String, dynamic> json) {
    try {
      final classes = (json['class_list'] as List?)?.cast<String>() ?? const [];
      final cat = classes.firstWhere(
        (c) => c.startsWith('categoria-noticia-'),
        orElse: () => '',
      );
      if (cat.isEmpty) return null;
      return cat.replaceFirst('categoria-noticia-', '').replaceAll('-', ' ');
    } catch (_) {
      return null;
    }
  }

  factory WpNoticia.fromListJson(Map<String, dynamic> json) {
    String? desc;
    try {
      final meta = json['meta'] as Map<String, dynamic>?;
      if (meta != null && meta['descripcion'] is String) {
        desc = (meta['descripcion'] as String)
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .trim();
      }
    } catch (_) {}

    return WpNoticia(
      id: json['id'] as int,
      title: (json['title']?['rendered'] as String?)?.trim() ?? 'Sin título',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      excerpt: (desc?.isNotEmpty ?? false) ? desc : null,
      featuredUrl: _featuredFromEmbedded(json),
      categoria: _categoriaFromClasses(json),
    );
  }

  String get dateLabel => DateFormat('d MMM y', 'es_ES').format(date);
}
