import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ajusta el import real

class RotulistasScreen extends StatefulWidget {
  const RotulistasScreen({super.key});

  @override
  State<RotulistasScreen> createState() => _RotulistasScreenState();
}

class _RotulistasScreenState extends State<RotulistasScreen> {
  late final WebViewController _controller;
  double _progress = 0;

  static const _iframeHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <style>
    html, body { margin:0; padding:0; height:100%; background:#fff; }
    .wrap { position:fixed; inset:0; }
    iframe { border:0; width:100%; height:100%; }
  </style>
</head>
<body>
  <div class="wrap">
<iframe src="https://map.proxi.co/r/Xok7O40hXvzKIRnvfyBE" allow="geolocation; clipboard-write">
</iframe>
  </div>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onWebResourceError: (error) {
            debugPrint('WebView error: $error');
          },
        ),
      )
      ..loadHtmlString(_iframeHtml);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
