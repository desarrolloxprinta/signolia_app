import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:signolia_app/widgets/center_logo_app_bar.dart';
import '../../../features/podcasts/podcast_model.dart';
import '../../../features/podcasts/podcast_service.dart';
import 'podcast_card.dart';

class PodcastsListScreen extends StatefulWidget {
  const PodcastsListScreen({super.key});

  @override
  State<PodcastsListScreen> createState() => _PodcastsListScreenState();
}

class _PodcastsListScreenState extends State<PodcastsListScreen> {
  final _service = PodcastService();

  final _items = <PodcastItem>[];
  int _page = 1;
  final int _perPage = 8; // ágil
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      if (refresh) {
        _page = 1;
        _items.clear();
        _hasMore = true;
      }

      final pageItems = await _service.fetchList(page: _page, perPage: _perPage);
      if (pageItems.isEmpty || pageItems.length < _perPage) {
        _hasMore = false;
      }
      _items.addAll(pageItems);
      _page++;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando podcasts: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.selectionClick();
    await _load(refresh: true);
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (!_hasMore || _loading) return false;
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
      _load();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const CenterLogoAppBar(showBack: true),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _items.length + (_loading || _hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              // Loader final mientras paginamos
              if (index >= _items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final p = _items[index];
              // La card se encarga de navegar al detalle
              return PodcastCard(item: p);
            },
          ),
        ),
      ),
    );
  }
}
