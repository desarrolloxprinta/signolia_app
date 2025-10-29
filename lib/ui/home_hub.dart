import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/env.dart';

class HomeHub extends StatelessWidget {
  const HomeHub({super.key});

  static final List<HubItem> items = [
    HubItem('Podcast', Icons.podcasts, (context) => _openExternal(Env.urlSpotify)),
    HubItem('Mapa', Icons.map, (context) => _openWeb(context, 'Mapa', Env.urlMapa)),
    HubItem('Empleo', Icons.work, (context) => _openWeb(context, 'Empleo', Env.urlEmpleo)),
    HubItem('Ordenanzas', Icons.gavel, (context) => _openWeb(context, 'Ordenanzas', Env.urlOrdenanzas)),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          floating: true,
          title: Text('Signolia'),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => HubCard(item: items[index]),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void _openWeb(BuildContext context, String title, String url) {
    final controller = WebViewController()..loadRequest(Uri.parse(url));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: WebViewWidget(controller: controller),
        ),
      ),
    );
  }
}

class HubItem {
  final String title;
  final IconData icon;
  final void Function(BuildContext) onTap;
  const HubItem(this.title, this.icon, this.onTap);
}

class HubCard extends StatelessWidget {
  final HubItem item;
  const HubCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.2), // ✅ corregido
        onTap: () => item.onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
