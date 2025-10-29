import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../features/podcasts/podcast_model.dart';
import 'podcast_detail_screen.dart';

/// Ajusta este color si quieres un tono más cercano al rojo YouTube oficial
const kYouTubeRed = Color(0xFFEA4335);

class PodcastCard extends StatelessWidget {
  final PodcastItem item;
  const PodcastCard({super.key, required this.item});

  String _guestsInline(PodcastItem p, {int max = 2}) {
    if (p.guests.isEmpty) return '';
    final names = p.guests.map((g) => g.name).where((e) => e.trim().isNotEmpty).toList();
    if (names.isEmpty) return '';
    final take = names.take(max).toList();
    final left = names.length - take.length;
    final base = take.join(', ');
    return left > 0 ? '$base +$left' : base;
  }

  Future<void> _openYouTube(String url) async {
    final uri = Uri.parse(url);
    // 1) Intenta app nativa
    final okNative = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    if (!okNative) {
      // 2) Fallback: navegador externo
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(14);

    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PodcastDetailScreen(id: item.id),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(borderRadius: radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniatura
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: item.thumbnailUrl == null || item.thumbnailUrl!.isEmpty
                      ? Container(
                          color: Colors.black12,
                          child: const Center(
                            child: Icon(Icons.podcasts_rounded, size: 48, color: Colors.black38),
                          ),
                        )
                      : Image.network(item.thumbnailUrl!, fit: BoxFit.cover),
                ),
              ),

              // Texto
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.episodeNumber != null && item.episodeNumber!.isNotEmpty) ...[
                          Text('Capítulo ${item.episodeNumber}', style: t.bodySmall),
                          const Text(' · '),
                        ],
                        if (item.durationMinutes != null)
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 16),
                              const SizedBox(width: 4),
                              Text('${item.durationMinutes} min', style: t.bodySmall),
                            ],
                          ),
                      ],
                    ),
                    if (_guestsInline(item).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Con: ${_guestsInline(item)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
              ),

              // Acciones
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Ver detalles'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PodcastDetailScreen(id: item.id),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kYouTubeRed,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Ver en YouTube'),
                        onPressed: (item.videoUrl == null || item.videoUrl!.isEmpty)
                            ? null
                            : () => _openYouTube(item.videoUrl!),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
