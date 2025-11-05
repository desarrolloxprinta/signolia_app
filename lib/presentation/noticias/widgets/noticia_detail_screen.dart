// lib/presentation/noticias/widgets/noticia_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// <-- AppBar con logo centrado y fondo negro
import 'package:signolia_app/widgets/center_logo_app_bar.dart';

class NoticiasDetailScreenV2 extends StatefulWidget {
  final int id;
  const NoticiasDetailScreenV2({super.key, required this.id});

  static Future<void> push(BuildContext context, {required int id}) {
    debugPrint('🟢 push -> NoticiasDetailScreenV2(id=$id)');
    return Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'noticias_detail_v2'),
        builder: (_) => NoticiasDetailScreenV2(id: id),
      ),
    );
  }

  @override
  State<NoticiasDetailScreenV2> createState() => _NoticiasDetailScreenV2State();
}

class _NoticiasDetailScreenV2State extends State<NoticiasDetailScreenV2> {
  late Future<_NoticiaDetail> _future;

  @override
  void initState() {
    super.initState();
    debugPrint('👉 Entrando en NoticiasDetailScreenV2 (id=${widget.id})');
    _future = _fetch();
  }

  Future<_NoticiaDetail> _fetch() async {
    final url = 'https://signolia.com/wp-json/wp/v2/noticias/${widget.id}?_embed=1';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('No se pudo cargar la noticia (status ${res.statusCode})');
    }
    final map = json.decode(res.body) as Map<String, dynamic>;

    final detail = _NoticiaDetail.fromJson(map);

    // Completar patrocinador desde el usuario si falta
    if ((detail.sponsorName == null || detail.sponsorName!.isEmpty)) {
      final authorId = (map['author'] as int?) ?? 0;
      final sponsor = await _fetchSponsorFromUser(authorId);
      if (sponsor != null && sponsor.isNotEmpty) {
        detail.sponsorName = sponsor; // mutable
      }
    }

    // Resolver URLs de la galería (si hay IDs)
    if (detail.galleryIds.isNotEmpty) {
      final urls = await Future.wait(detail.galleryIds.map(_mediaToUrl));
      detail.galleryUrls.addAll(urls.whereType<String>());
    }
    return detail;
  }

  /// Llama al endpoint público del usuario para leer meta.nombre_empresa
  Future<String?> _fetchSponsorFromUser(int? authorId) async {
    if (authorId == null || authorId <= 0) return null;
    try {
      final url = 'https://signolia.com/wp-json/wp/v2/users/$authorId?_embed=1';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final m = json.decode(res.body) as Map<String, dynamic>;
        final meta = (m['meta'] as Map?)?.cast<String, dynamic>();
        final nombreEmpresa = (meta?['nombre_empresa'] as String?)?.trim();
        if (nombreEmpresa != null && nombreEmpresa.isNotEmpty) {
          return nombreEmpresa;
        }
        final empresa = (meta?['empresa'] as String?)?.trim();
        if (empresa != null && empresa.isNotEmpty) return empresa;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _mediaToUrl(String id) async {
    try {
      final u = 'https://signolia.com/wp-json/wp/v2/media/$id';
      final res = await http.get(Uri.parse(u));
      if (res.statusCode == 200) {
        final m = json.decode(res.body) as Map<String, dynamic>;
        return (m['source_url'] as String?) ??
            (m['media_details']?['sizes']?['large']?['source_url'] as String?);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<_NoticiaDetail>(
      future: _future,
      builder: (context, snap) {
        // AppBar de detalles: SIEMPRE el mismo (logo centrado, fondo negro)
        const appBar = CenterLogoAppBar(showBack: true);

        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            appBar: appBar,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No se ha podido cargar la noticia.\n\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final n = snap.data!;
        final patrocinador = (n.sponsorName ?? n.authorName)?.trim(); // prioridad a empresa

        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (n.featuredUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    n.featuredUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey.shade200),
                  ),
                ),

              // Título
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  n.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              // Autor + fecha + categoría
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (n.authorAvatar != null)
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: NetworkImage(n.authorAvatar!),
                      ),
                    if (n.authorName != null) ...[
                      const SizedBox(width: 8),
                      Text(n.authorName!, style: theme.textTheme.labelMedium),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      '• ${n.dateLabel}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    if (n.categoria != null && n.categoria!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          n.categoria!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // —— Patrocinador (empresa del autor) ——
              if ((patrocinador ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    'Noticia patrocinada por: $patrocinador',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ),

              // Encabezado / Descripción / Contenido (HTML)
              if ((n.encabezado ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(n.encabezado!, style: theme.textTheme.titleMedium),
                ),
              if ((n.descripcionHtml ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Html(data: n.descripcionHtml!),
                ),
              if ((n.contentHtml ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Html(data: n.contentHtml!),
                ),

              // Bloques repetidos
              ...n.repeatedSections.map(
                (b) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((b.title ?? '').isNotEmpty)
                        Text(
                          b.title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if ((b.html ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Html(data: b.html!),
                        ),
                      if ((b.imageUrl ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(b.imageUrl!, fit: BoxFit.cover),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Galería
              if (n.galleryUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Galería',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: n.galleryUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.network(
                          n.galleryUrls[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }


}

/// =================== MODELO ===================

class _NoticiaDetail {
  final int id;
  final String title;
  final String? contentHtml;
  final String? encabezado;
  final String? descripcionHtml;
  final String? featuredUrl;
  final DateTime date;
  final String? authorName;
  final String? authorAvatar;
  final String? categoria;
  final String? videoUrl;
  final String? externalUrl;
  final String? webUrl;

  // mutable para poder completarlo tras pedir el usuario
  String? sponsorName;

  final List<String> galleryIds;
  final List<String> galleryUrls;
  final List<_RepeatedBlock> repeatedSections;

  _NoticiaDetail({
    required this.id,
    required this.title,
    required this.date,
    this.contentHtml,
    this.encabezado,
    this.descripcionHtml,
    this.featuredUrl,
    this.authorName,
    this.authorAvatar,
    this.categoria,
    this.videoUrl,
    this.externalUrl,
    this.webUrl,
    this.sponsorName,
    List<String>? galleryIds,
    List<String>? galleryUrls,
    List<_RepeatedBlock>? repeatedSections,
  })  : galleryIds = galleryIds ?? [],
        galleryUrls = galleryUrls ?? [],
        repeatedSections = repeatedSections ?? [];

  String get dateLabel => DateFormat('d MMM y', 'es_ES').format(date);

  static String? _readString(dynamic source, String key) {
    if (source is Map) {
      final v = source[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  factory _NoticiaDetail.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? meta;
    if (j['meta'] is Map) {
      meta = Map<String, dynamic>.from(j['meta'] as Map);
    }

    // Autor + avatar + posible empresa embebida
    String? authorName;
    String? authorAvatar;
    String? sponsorFromEmbedded;

    try {
      final authors = (j['_embedded']?['author'] as List?) ?? [];
      if (authors.isNotEmpty) {
        final a = authors.first as Map<String, dynamic>;
        authorName = a['name'] as String?;
        authorAvatar = (a['avatar_urls']?['96'] as String?) ??
            (a['avatar_urls']?['48'] as String?);

        sponsorFromEmbedded = _readString(a, 'sponsor_company') ??
            _readString(a, 'nombre_empresa') ??
            _readString(a['meta'], 'nombre_empresa') ??
            _readString(a['jet_engine'], 'nombre_empresa');
      }
    } catch (_) {}

    // Imagen destacada
    String? featuredUrl;
    try {
      final fm = (j['_embedded']?['wp:featuredmedia'] as List?) ?? [];
      if (fm.isNotEmpty) featuredUrl = fm.first['source_url'] as String?;
    } catch (_) {}

    // Categoría desde class_list
    String? categoria;
    try {
      final classes = (j['class_list'] as List?)?.cast<String>() ?? const [];
      final cat = classes.firstWhere(
        (c) => c.startsWith('categoria-noticia-'),
        orElse: () => '',
      );
      if (cat.isNotEmpty) {
        categoria = cat
            .replaceFirst('categoria-noticia-', '')
            .replaceAll('-', ' ');
      }
    } catch (_) {}

    // Encabezado y descripción
    final encabezado = j['encabezado'] as String?;
    String? descripcionHtml;
    try {
      final d = (meta != null ? meta['descripcion'] : j['descripcion']);
      if (d is String) descripcionHtml = d;
    } catch (_) {}

    // Bloques “contenido_repetido”
    final blocks = <_RepeatedBlock>[];
    try {
      dynamic cr = j['contenido_repetido'];
      if (cr is! Map && meta != null) cr = meta['contenido_repetido'];
      if (cr is Map) {
        final m = Map<String, dynamic>.from(cr);
        final keys = m.keys.toList()..sort();
        for (final k in keys) {
          final v = m[k];
          if (v is Map) {
            final mm = Map<String, dynamic>.from(v);
            final h = (mm['encabezado_1'] as String?)?.trim();
            final d = (mm['descripcion_1'] as String?)?.trim();
            String? img;
            final i1 = mm['imagen_1'];
            if (i1 is String && i1.startsWith('http')) img = i1;
            blocks.add(_RepeatedBlock(title: h, html: d, imageUrl: img));
          }
        }
      }
    } catch (_) {}

    // Galería: lista o CSV (root o meta)
    final ids = <String>[];
    try {
      dynamic g = j['galeria_de_imagenes'];
      if (g == null && meta != null) g = meta['galeria_de_imagenes'];
      if (g is List) {
        ids.addAll(g.map((e) => e.toString()));
      } else if (g is String && g.trim().isNotEmpty) {
        ids.addAll(g.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
      }
    } catch (_) {}

    return _NoticiaDetail(
      id: j['id'] as int,
      title: (j['title']?['rendered'] as String?)?.trim() ?? 'Sin título',
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      contentHtml: (j['content']?['rendered'] as String?) ?? '',
      encabezado: encabezado,
      descripcionHtml: descripcionHtml,
      featuredUrl: featuredUrl,
      authorName: authorName,
      authorAvatar: authorAvatar,
      categoria: categoria,
      videoUrl: (j['video'] as String?) ?? (meta?['video'] as String?),
      externalUrl: (j['enlace'] as String?) ?? (meta?['enlace'] as String?),
      webUrl: j['link'] as String?,
      repeatedSections: blocks,
      galleryIds: ids,
      sponsorName: (j['sponsor_company'] as String?)?.trim() ?? sponsorFromEmbedded,
    );
  }
}

class _RepeatedBlock {
  final String? title;
  final String? html;
  final String? imageUrl;

  _RepeatedBlock({this.title, this.html, this.imageUrl});
}
