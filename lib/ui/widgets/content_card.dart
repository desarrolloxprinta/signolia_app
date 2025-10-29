import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ContentCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final List<Widget>? badges;
  final VoidCallback? onTap;

  const ContentCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.subtitle,
    this.badges,
    this.onTap, required date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            _LeadingImage(imageUrl: imageUrl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badges != null && badges!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(spacing: 6, runSpacing: -6, children: badges!),
                      ),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

class _LeadingImage extends StatelessWidget {
  final String? imageUrl;
  const _LeadingImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const SizedBox(
        width: size, height: size,
        child: Icon(Icons.image_not_supported),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: Colors.white,
        child: Container(width: size, height: size, color: Colors.white),
      ),
      errorWidget: (_, __, ___) => const SizedBox(
        width: size, height: size,
        child: Icon(Icons.broken_image),
      ),
    );
  }
}
