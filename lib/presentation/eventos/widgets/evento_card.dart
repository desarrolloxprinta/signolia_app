import 'package:flutter/material.dart';
import 'evento_detail_screen.dart';

class BrandColors {
  static const primary   = Color(0xFF347778);
  static const secondary = Color(0xFFEF7F1A);
  static const text      = Color(0xFF0C0B0B);
  static const accent    = Color(0xFF347778);
}

class EventoCard extends StatelessWidget {
  final Map<String, dynamic> post; // Map crudo WP
  const EventoCard({super.key, required this.post});

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

  String _plain(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final title = _plain(post['title']?['rendered'] ?? '');
    final excerpt = _plain(
      (post['descripcion'] ??
       post['excerpt']?['rendered'] ??
       post['content']?['rendered'] ??
       '')
      .toString(),
    );
    final img = _image(post);

    return Card(
      color: const Color(0xFFF5F5F5),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // 👇 unificado con dashboard
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventoDetailScreen.fromWp(post: post),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (img != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                child: Image.network(
                  img,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // badge
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
                      style: t.bodyMedium?.copyWith(color: Colors.grey.shade700, height: 1.35),
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
