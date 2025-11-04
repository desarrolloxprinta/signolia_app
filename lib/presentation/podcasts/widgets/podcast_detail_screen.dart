import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../features/podcasts/podcast_repository.dart';
import '../../../features/podcasts/podcast_model.dart';
// ajusta el import real
import 'package:signolia_app/widgets/center_logo_app_bar.dart';

const kYouTubeRed = Color(0xFFEA4335);

class PodcastDetailScreen extends StatefulWidget {
  final int id;
  const PodcastDetailScreen({super.key, required this.id});

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen> {
  final PodcastRepository _repository = PodcastRepository();
  late Future<PodcastItem> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchDetail(widget.id);
  }

  Future<void> _refresh() async {
    final future = _repository.fetchDetail(widget.id, forceRefresh: true);
    setState(() => _future = future);
    await future;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final okNative = await launchUrl(
      uri,
      mode: LaunchMode.externalNonBrowserApplication,
    );
    if (!okNative) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const CenterLogoAppBar(showBack: true),
      body: FutureBuilder<PodcastItem>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return const Center(child: Text('No se pudo cargar el episodio'));
          }
          final p = snap.data!;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    // portada
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: p.thumbnailUrl == null || p.thumbnailUrl!.isEmpty
                          ? Container(
                              color: Colors.black12,
                              child: const Center(
                                child: Icon(
                                  Icons.podcasts_rounded,
                                  size: 56,
                                  color: Colors.black38,
                                ),
                              ),
                            )
                          : Image.network(p.thumbnailUrl!, fit: BoxFit.cover),
                    ),

                    // título + intro
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        p.title,
                        style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (p.sinopsisText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Text(
                          p.sinopsisText,
                          style: t.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ),

                    // metadatos
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: .25),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _MetaRow(
                              label: 'Episodio',
                              value: p.episodeNumber?.toString() ?? '—',
                            ),
                            _MetaRow(
                              label: 'Duracion',
                              value: p.durationMinutes != null
                                  ? '${p.durationMinutes} min'
                                  : '—',
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Invitados
                    if (p.guests.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Invitados',
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: p.guests
                              .map(
                                (g) =>
                                    _GuestTile(guest: g, onLinkTap: _openUrl),
                              )
                              .toList(),
                        ),
                      ),
                    ],

                    // Segmentos (si los tienes)
                    if (p.segments.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Resumen del capitulo',
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: p.segments.map((s) {
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.bolt_rounded),
                              title: Text(s.title),
                              subtitle: s.time == null ? null : Text(s.time!),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // Enlaces relacionados (si los tienes)
                    if (p.links.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Enlaces',
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: p.links.map((l) {
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.link_rounded),
                              title: Text(l.title ?? l.url),
                              onTap: () => _openUrl(l.url),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // FAB YouTube
              if (p.videoUrl != null && p.videoUrl!.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'yt_fab_${p.id}',
                    backgroundColor: kYouTubeRed,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Ver en YouTube'),
                    onPressed: () => _openUrl(p.videoUrl!),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: .25)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: t.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GuestTile extends StatelessWidget {
  final PodcastGuest guest;
  final Future<void> Function(String url) onLinkTap;
  const _GuestTile({required this.guest, required this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.black12,
        backgroundImage: (guest.avatarUrl?.isNotEmpty ?? false)
            ? NetworkImage(guest.avatarUrl!)
            : null,
        child: (guest.avatarUrl == null || guest.avatarUrl!.isEmpty)
            ? const Icon(Icons.person_outline_rounded, color: Colors.black45)
            : null,
      ),
      title: Text(
        guest.name,
        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: (guest.bio?.isNotEmpty ?? false)
          ? Text(guest.bio!, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Wrap(
        spacing: 8,
        children: [
          if (guest.linkedin != null && guest.linkedin!.isNotEmpty)
            IconButton(
              tooltip: 'LinkedIn',
              icon: const Icon(Icons.business_rounded),
              onPressed: () => onLinkTap(guest.linkedin!),
            ),
          if (guest.youtube != null && guest.youtube!.isNotEmpty)
            IconButton(
              tooltip: 'YouTube',
              color: kYouTubeRed,
              icon: const Icon(Icons.play_circle_fill_rounded),
              onPressed: () => onLinkTap(guest.youtube!),
            ),
          if (guest.web != null && guest.web!.isNotEmpty)
            IconButton(
              tooltip: 'Web',
              icon: const Icon(Icons.public_rounded),
              onPressed: () => onLinkTap(guest.web!),
            ),
        ],
      ),
    );
  }
}
