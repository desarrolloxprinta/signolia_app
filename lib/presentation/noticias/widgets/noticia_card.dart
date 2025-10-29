import 'package:flutter/material.dart';
import '../models/wp_noticia.dart';

class NoticiaCard extends StatelessWidget {
  final WpNoticia noticia;
  final VoidCallback? onTap;

  const NoticiaCard({
    super.key,
    required this.noticia,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: noticia.featuredUrl != null
                    ? Image.network(
                        noticia.featuredUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                      )
                    : Container(color: Colors.grey.shade200),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (noticia.categoria != null && noticia.categoria!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        noticia.categoria!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  Text(
                    noticia.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (noticia.excerpt != null)
                    Text(
                      noticia.excerpt!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: (theme.textTheme.bodyMedium?.color ?? Colors.black)
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    noticia.dateLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: (theme.textTheme.bodySmall?.color ?? Colors.black)
                          .withValues(alpha: 0.7),
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
