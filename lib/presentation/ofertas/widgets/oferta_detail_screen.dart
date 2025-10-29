// lib/presentation/ofertas/widgets/oferta_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Si ya tienes este AppBar centrado en tu proyecto, importa su ruta real.
// Si no lo tienes, puedes usar tu SignoliaScaffold con su variante "detail"
// pero me pediste explícitamente el AppBar de detalle con logo centrado.
import 'package:signolia_app/widgets/center_logo_app_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DETALLE DE OFERTA (robusto, acepta mapa crudo de WP y completa datos si faltan)
// ─────────────────────────────────────────────────────────────────────────────
class OfertaDetailScreen extends StatefulWidget {
  /// ÚSALA DESDE EL DASHBOARD O LISTAS CUANDO TENGAS EL POST CRUDO DE WP:
  /// `OfertaDetailScreen.fromWp(post: wpMap)`
  const OfertaDetailScreen._({required this.initialPost});

  factory OfertaDetailScreen.fromWp({required Map<String, dynamic> post}) {
    return OfertaDetailScreen._(initialPost: post);
  }

  final Map<String, dynamic> initialPost;

  @override
  State<OfertaDetailScreen> createState() => _OfertaDetailScreenState();
}

class _OfertaDetailScreenState extends State<OfertaDetailScreen> {
  late Map<String, dynamic> _post; // siempre mantenemos un mapa WP
  bool _loadingExtra = false;

  // Campos derivados
  String _featuredUrl = '';
  String _linkSignolia = '';
  String _linkExterno = '';
  String _title = '';
  String _excerptHtml = '';
  String _descripcionHtml = '';
  String _empresa = '';
  String _direccion = '';
  String _email = '';
  String _telefono = '';
  String _webEmpresa = '';
  String _descuento = '';
  int _fIni = 0, _fFin = 0;
  String _autor = '';

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _hydrateFromPost(_post);
    // Si no tenemos link público o imagen, pedimos el POST completo (_embed=1)
    // Esto arregla el caso del LISTADO donde a veces no llega todo
    if (_linkSignolia.isEmpty || _featuredUrl.isEmpty) {
      _fetchExpandIfNeeded();
    }
  }

  // ───────────────────────── helpers de parsing ─────────────────────────

  String _s(Object? v) => (v ?? '').toString();

  String _decode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&#038;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#8217;', '’')
      .replaceAll('&#8211;', '–')
      .replaceAll('&nbsp;', ' ')
      .trim();

  String _html(Map m, List<String> path, {String fallback = ''}) {
    try {
      dynamic cur = m;
      for (final k in path) {
        if (cur is Map) cur = cur[k];
      }
      return _decode(_s(cur));
    } catch (_) {
      return fallback;
    }
  }

  int _epoch(Map m, List<String> path) {
    try {
      dynamic cur = m;
      for (final k in path) {
        if (cur is Map) cur = cur[k];
      }
      if (cur is int) return cur;
      if (cur is String) return int.tryParse(cur) ?? 0;
    } catch (_) {}
    return 0;
  }

  String _fmtEpochEs(int epochSeconds) {
    if (epochSeconds <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  String _sanitizeUrl(String raw) {
    final s = _decode(raw.trim());
    if (s.isEmpty) return s;

    final looksEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    final looksPhone = RegExp(r'^\+?[0-9][0-9\s\-()]*$').hasMatch(s);

    if (looksEmail && !s.startsWith('mailto:')) return 'mailto:$s';
    if (looksPhone && !s.startsWith('tel:')) return 'tel:${s.replaceAll(' ', '')}';
    if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('mailto:') || s.startsWith('tel:')) {
      return s;
    }
    return 'https://$s';
  }

  Future<void> _openUrl(String raw) async {
    if (raw.trim().isEmpty) return;
    final uri = Uri.parse(_sanitizeUrl(raw));
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    final ok2 = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok2 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  // ───────────────────────── mapeo desde el JSON ─────────────────────────

  void _hydrateFromPost(Map<String, dynamic> post) {
    // Título y excerpt
    _title       = _html(post, ['title', 'rendered']);
    _excerptHtml = _html(post, ['excerpt', 'rendered']);

    // Link público (Signolia) para el botón de formulario
    _linkSignolia = _s(post['link']);

    // Imagen destacada: intentar desde _embedded.wp:featuredmedia
    try {
      final fm = post['_embedded']?['wp:featuredmedia'];
      if (fm is List && fm.isNotEmpty) {
        _featuredUrl = _s(fm[0]['source_url']);
      }
    } catch (_) {}

    // META
    final meta = (post['meta'] is Map) ? (post['meta'] as Map).cast<String, dynamic>() : const <String, dynamic>{};

    _descripcionHtml = _decode(_s(meta['descripcion_oferta']).isNotEmpty
        ? _s(meta['descripcion_oferta'])
        : _s(post['descripcion_oferta'] ?? ''));

    _fIni      = _epoch(post, ['meta', 'fecha_inicio_oferta']);
    _fFin      = _epoch(post, ['meta', 'fecha_fin_oferta']);
    _empresa   = _decode(_s(meta['nombre_empresa_oferta'] ?? post['nombre_empresa_oferta'] ?? ''));
    _direccion = _decode(_s(meta['direccion_de_la_empresa'] ?? post['direccion_de_la_empresa'] ?? ''));
    _email     = _decode(_s(meta['email_empresa_oferta'] ?? post['email_empresa_oferta'] ?? ''));
    _telefono  = _decode(_s(meta['telefono_empresa_oferta'] ?? post['telefono_empresa_oferta'] ?? ''));
    _webEmpresa= _decode(_s(meta['web_oferta_empresa'] ?? post['web_oferta_empresa'] ?? ''));
    _descuento = _decode(_s(meta['descuento_oferta'] ?? post['descuento_oferta'] ?? ''));
    _linkExterno = _decode(_s(meta['link_oferta'] ?? post['link_oferta'] ?? ''));

    // Autor (opcional)
    _autor = '';
    try {
      _autor = _decode(_s(post['_embedded']?['author']?[0]?['name']));
    } catch (_) {}
    setState(() {});
  }

  Future<void> _fetchExpandIfNeeded() async {
    final id = _post['id'];
    if (id == null) return;
    setState(() => _loadingExtra = true);
    try {
      final uri = Uri.parse('https://signolia.com/wp-json/wp/v2/ofertas/$id?_embed=1');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final map = json.decode(res.body) as Map<String, dynamic>;
        // fusiona y re-hidrata
        _post = {..._post, ...map};
        _hydrateFromPost(_post);
      }
    } catch (_) {
      // ignoramos, mostramos lo que tengamos
    } finally {
      if (mounted) setState(() => _loadingExtra = false);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fIniLabel = _fmtEpochEs(_fIni);
    final fFinLabel = _fmtEpochEs(_fFin);

    return Scaffold(
      appBar: const CenterLogoAppBar(showBack: true),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_featuredUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                _featuredUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),

          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              _title.isEmpty ? 'Oferta' : _title,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),

          // Autor
          if (_autor.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Publicado por $_autor', style: t.labelMedium?.copyWith(color: Colors.grey[700])),
            ),

          // Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (fIniLabel.isNotEmpty) _chip('Inicio: $fIniLabel'),
                if (fFinLabel.isNotEmpty) _chip('Fin: $fFinLabel'),
                if (_descuento.isNotEmpty) _chip('Descuento: $_descuento'),
              ],
            ),
          ),

          // Descripción (prefer meta.descripcion_oferta; si no, excerpt)
          if (_descripcionHtml.isNotEmpty || _excerptHtml.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Html(data: _descripcionHtml.isNotEmpty ? _descripcionHtml : _excerptHtml),
            ),
          ],

          const SizedBox(height: 16),

          // Botones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (_linkSignolia.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openUrl(_linkSignolia),
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Rellenar formulario en Signolia'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
                if (_linkSignolia.isNotEmpty && _linkExterno.isNotEmpty) const SizedBox(height: 10),
                if (_linkExterno.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openUrl(_linkExterno),
                      icon: const Icon(Icons.public_rounded),
                      label: const Text('Web de la oferta'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
              ],
            ),
          ),

          // Contacto
          if (_empresa.isNotEmpty || _direccion.isNotEmpty || _email.isNotEmpty || _telefono.isNotEmpty || _webEmpresa.isNotEmpty) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                color: const Color(0xFFF5F5F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Información de la empresa', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (_empresa.isNotEmpty) _rowIconText(Icons.business, _empresa),
                      if (_direccion.isNotEmpty) _rowIconText(Icons.place, _direccion),
                      if (_email.isNotEmpty) _rowLink(Icons.email_outlined, _email),
                      if (_telefono.isNotEmpty) _rowLink(Icons.call_outlined, _telefono),
                      if (_webEmpresa.isNotEmpty) _rowLink(Icons.link, _webEmpresa),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (_loadingExtra) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  // ───────────────────────── UI helpers ─────────────────────────

  static Widget _chip(String text) {
    final c = Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .07),
        border: Border.all(color: c.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  static Widget _rowIconText(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _rowLink(IconData icon, String value) {
    return InkWell(
      onTap: () => _openUrl(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }
}
