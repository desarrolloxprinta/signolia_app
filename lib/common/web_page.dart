// lib/common/web_page.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebPage: pantalla sencilla para abrir URLs http/https dentro de la app.
/// Se usa como *fallback* cuando no existe una app externa que maneje el enlace.
class WebPage extends StatefulWidget {
  const WebPage({
    super.key,
    required this.url,
    this.title,
  });

  /// Debe ser http(s). Otros esquemas (mailto:, tel:) no se cargan aquí.
  final String url;
  final String? title;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController _controller;
  final ValueNotifier<int> _progress = ValueNotifier<int>(0);

  bool get _isHttp =>
      widget.url.startsWith('http://') || widget.url.startsWith('https://');

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => _progress.value = p,
          onWebResourceError: (err) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al cargar: ${err.description}')),
            );
          },
        ),
      );

    if (_isHttp) {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Signolia';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _isHttp ? () => _controller.reload() : null,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Abrir en navegador',
            onPressed: _isHttp
                ? () => _controller.loadRequest(Uri.parse(widget.url))
                : null,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: ValueListenableBuilder<int>(
            valueListenable: _progress,
            builder: (_, p, __) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (p.clamp(0, 100)) / 100,
                child: Container(color: const Color(0xFFEF7F1A)),
              ),
            ),
          ),
        ),
      ),
      body: _isHttp
          ? WebViewWidget(controller: _controller)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Este enlace no es compatible para mostrar dentro de la app:\n\n${widget.url}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}
