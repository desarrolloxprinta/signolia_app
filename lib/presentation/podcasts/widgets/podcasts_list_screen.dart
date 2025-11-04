import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:signolia_app/widgets/center_logo_app_bar.dart';
import '../../../features/podcasts/podcast_model.dart';
import '../../../features/podcasts/podcast_repository.dart';
import 'podcast_card.dart';

class PodcastsListScreen extends StatefulWidget {
  const PodcastsListScreen({super.key});

  @override
  State<PodcastsListScreen> createState() => _PodcastsListScreenState();
}

class _PodcastsListScreenState extends State<PodcastsListScreen> {
  late final PodcastRepository _repository = PodcastRepository();

  final _items = <PodcastItem>[];
  int _page = 1;
  final int _perPage = 8; // agil
  bool _loading = false;
  bool _hasMore = true;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _primeFromCache();
  }

  Future<void> _primeFromCache() async {
    final cached = await _repository.getCachedPage(1);
    if (!mounted) return;

    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _items
          ..clear()
          ..addAll(cached);
        _hasMore = cached.length == _perPage;
        _page = 2;
      });
    }

    _bootstrapped = true;
    await _load(
      refresh: true,
      keepExisting: cached != null && cached.isNotEmpty,
    );
  }

  Future<void> _load({bool refresh = false, bool keepExisting = false}) async {
    if (_loading || (!_bootstrapped && !refresh)) return;
    setState(() => _loading = true);

    try {
      if (refresh) {
        _page = 1;
        if (!keepExisting) {
          _items.clear();
        }
        _hasMore = true;
      }

      final pageItems = await _repository.fetchPage(
        _page,
        perPage: _perPage,
        forceRefresh: refresh,
      );

      if (refresh) {
        _items
          ..clear()
          ..addAll(pageItems);
        _page = 2;
        _hasMore = pageItems.length == _perPage;
      } else {
        if (pageItems.isEmpty || pageItems.length < _perPage) {
          _hasMore = false;
        }
        _items.addAll(pageItems);
        _page++;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando podcasts: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.selectionClick();
    await _load(refresh: true, keepExisting: true);
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
              if (index >= _items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return PodcastCard(item: _items[index]);
            },
          ),
        ),
      ),
    );
  }
}
