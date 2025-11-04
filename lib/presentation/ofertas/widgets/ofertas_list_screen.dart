import 'package:flutter/material.dart';

import '../../../features/ofertas/oferta_model.dart';
import '../../../features/ofertas/ofertas_repository.dart';
import 'oferta_card.dart';

class OfertasListScreen extends StatefulWidget {
  const OfertasListScreen({super.key});

  @override
  State<OfertasListScreen> createState() => _OfertasListScreenState();
}

class _OfertasListScreenState extends State<OfertasListScreen> {
  final OfertasRepository _repository = OfertasRepository();
  final List<Oferta> _items = <Oferta>[];

  bool _loading = false;
  bool _error = false;
  bool _bootstrapped = false;

  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _primeFromCache();
  }

  Future<void> _primeFromCache() async {
    final cached = await _repository.getCachedFirstPage();
    if (!mounted) return;

    if (cached != null && cached.items.isNotEmpty) {
      setState(() {
        _items
          ..clear()
          ..addAll(cached.items);
      });
    }

    _bootstrapped = true;
    await _load(
      refresh: true,
      keepExisting: cached != null && cached.items.isNotEmpty,
    );
  }

  Future<void> _load({bool refresh = false, bool keepExisting = false}) async {
    if (_loading || (!_bootstrapped && !refresh)) return;
    setState(() {
      _loading = true;
      if (refresh) {
        _error = false;
        if (!keepExisting) {
          _items.clear();
        }
      }
    });

    try {
      final page = await _repository.fetchPage(
        1,
        perPage: _perPage,
        forceRefresh: refresh,
      );
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
      });
    } catch (_) {
      setState(() => _error = true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      } else {
        _loading = false;
      }
    }
  }

  Future<void> _onRefresh() async {
    await _load(refresh: true, keepExisting: true);
  }

  @override
  Widget build(BuildContext context) {
    final showLoader = _loading && _items.isEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: showLoader
            ? const Center(child: CircularProgressIndicator())
            : _error && _items.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  const Center(child: Text('Error al cargar ofertas')),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              )
            : _items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No hay ofertas disponibles')),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (_, i) => OfertaCard(oferta: _items[i]),
              ),
      ),
    );
  }
}
