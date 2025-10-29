// lib/presentation/eventos/widgets/evento_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom; // <- firma onLinkTap v3
import 'package:url_launcher/url_launcher.dart';
import 'package:signolia_app/widgets/center_logo_app_bar.dart';


class BrandColors {
  static const primary   = Color(0xFF347778);
  static const secondary = Color(0xFFEF7F1A);
  static const text      = Color(0xFF0C0B0B);
  static const accent    = Color(0xFF833766);
}

class EventoDetailScreen extends StatelessWidget {
  const EventoDetailScreen({
    super.key,
    required this.evento,
  })  : _bridge = null,
        _useBridge = false;

  /// Atajo cuando vienes de un WP post crudo (dashboard/listas)
  factory EventoDetailScreen.fromWp({required Map<String, dynamic> post}) {
    final titulo = (post['title']?['rendered'] ?? '').toString();

    String? imagen;
    try {
      imagen = post['_embedded']?['wp:featuredmedia']?[0]?['source_url']?.toString();
    } catch (_) {}

    final html = (post['descripcion']
          ?? post['content']?['rendered']
          ?? post['excerpt']?['rendered']
          ?? '')
        .toString();

    final fIni = _normalizeDate(post['fecha'] ?? post['fecha_inicio'] ?? post['date']);
    final fFin = _normalizeDate(post['fecha_fin']);

    final clase = (post['class_list'] is List) ? (post['class_list'] as List).cast<String>() : const <String>[];
    final modalidadRaw = (post['modalidad'] ?? '').toString().toLowerCase();
    final isOnline = modalidadRaw.contains('online') ||
        clase.any((c) => c.contains('online')) ||
        (post['link_si_es_online'] ?? '').toString().isNotEmpty;
    final modalidad = isOnline ? 'Online' : 'Presencial';

    final precio       = (post['precio'] ?? '').toString();
    final ubicacion    = (post['ubicacion'] ?? post['localizacion'] ?? '').toString();
    final linkRegistro = (post['link_registro'] ?? post['linkRegistro'] ?? '').toString();
    final linkOnline   = (post['link_si_es_online'] ?? '').toString();

    final orgNombre = (post['nombre_organizador'] ?? '').toString();
    final orgEmail  = (post['email_organizador'] ?? '').toString();
    final orgTel    = (post['telefono_organizador'] ?? '').toString();
    final orgWeb    = (post['web_del_organizador_'] ?? post['webOrganizador'] ?? '').toString();

    final ig     = (post['instagram'] ?? '').toString();
    final fb     = (post['facebook'] ?? '').toString();
    final tw     = (post['twitter'] ?? '').toString();
    final yt     = (post['youtube'] ?? '').toString();
    final inx    = (post['linkedin'] ?? '').toString();
    final tiktok = (post['tiktok'] ?? '').toString();

    final map = <String, dynamic>{
      'titulo'       : titulo,
      'imagen'       : imagen,
      'html'         : html,
      'fecha_inicio' : fIni,
      'fecha_fin'    : fFin,
      'modalidad'    : modalidad,
      'precio'       : precio,
      'ubicacion'    : ubicacion,
      'link_registro': linkRegistro,
      'link_online'  : linkOnline,
      'org_nombre'   : orgNombre,
      'org_email'    : orgEmail,
      'org_tel'      : orgTel,
      'org_web'      : orgWeb,
      'ig'           : ig,
      'fb'           : fb,
      'tw'           : tw,
      'yt'           : yt,
      'in'           : inx,
      'tk'           : tiktok,
    };
    return EventoDetailScreen._fromMap(map);
  }

  const EventoDetailScreen._fromMap(this._bridge)
      : evento = null,
        _useBridge = true;

  final dynamic evento;
  final Map<String, dynamic>? _bridge;
  final bool _useBridge;

  // ---------------- Helpers de fecha y enlaces ----------------

  static String _normalizeDate(dynamic v) {
    if (v == null) return '';
    try {
      if (v is num) {
        final d = DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000, isUtc: true).toLocal();
        return '${d.day}/${d.month}/${d.year}';
      }
      if (v is String) {
        final n = int.tryParse(v);
        if (n != null) {
          final d = DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true).toLocal();
          return '${d.day}/${d.month}/${d.year}';
        }
        final d = DateTime.tryParse(v);
        if (d != null) {
          final dl = d.toLocal();
          return '${dl.day}/${dl.month}/${dl.year}';
        }
      }
    } catch (_) {}
    return '';
  }

  static String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&#038;', '&')
      .replaceAll('&quot;', '"')
      .trim();

  static String _sanitizeUrl(String raw) {
    var s = _decodeEntities(raw).trim();
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

  static Future<void> _openUrlFlexible(BuildContext context, String raw) async {
    final s = _sanitizeUrl(raw);
    if (s.isEmpty) return;
    final uri = Uri.parse(s);

    // 1) Intenta externo
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    // 2) Fallback: in-app webview
    final ok2 = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok2 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  static Future<void> _openMap(BuildContext context, String address) async {
    if (address.isEmpty) return;
    final q = Uri.encodeComponent(address);
    final u = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');

    if (await canLaunchUrl(u)) {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    // Fallback webview
    final ok2 = await launchUrl(u, mode: LaunchMode.inAppBrowserView);
    if (!ok2 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa')),
      );
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final data = _useBridge ? _bridge! : _fromModel(evento);

    final title  = (data['titulo'] ?? '') as String;
    final img    = (data['imagen'] ?? '') as String;
    final html   = (data['html'] ?? '') as String;

    final fIni   = (data['fecha_inicio'] ?? '') as String;
    final fFin   = (data['fecha_fin'] ?? '') as String;
    final modalidad = (data['modalidad'] ?? '') as String;
    final precio = (data['precio'] ?? '') as String;

    final ubic   = (data['ubicacion'] ?? '') as String;
    final reg    = (data['link_registro'] ?? '') as String;
    final linkOnline = (data['link_online'] ?? '') as String;

    final orgNom = (data['org_nombre'] ?? '') as String;
    final orgMail= (data['org_email'] ?? '') as String;
    final orgTel = (data['org_tel'] ?? '') as String;
    final orgWeb = (data['org_web'] ?? '') as String;

    final ig  = (data['ig'] ?? '') as String;
    final fb  = (data['fb'] ?? '') as String;
    final tw  = (data['tw'] ?? '') as String;
    final yt  = (data['yt'] ?? '') as String;
    final inn = (data['in'] ?? '') as String;
    final tk  = (data['tk'] ?? '') as String;

    final hasRange = fIni.isNotEmpty || fFin.isNotEmpty;
    final dateText = hasRange
        ? (fIni.isNotEmpty && fFin.isNotEmpty ? '$fIni — $fFin' : (fIni.isNotEmpty ? fIni : fFin))
        : '';

   return Scaffold(
   appBar: const CenterLogoAppBar(showBack: true),
  body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (img.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                img,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
            child: Text(
              title,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (modalidad.isNotEmpty)
                  _chip(
                    modalidad,
                    color: modalidad.toLowerCase() == 'online'
                        ? Colors.blue
                        : BrandColors.primary,
                  ),
                if (precio.isNotEmpty)
                  _chip('Precio: $precio', color: BrandColors.secondary),
                if (dateText.isNotEmpty)
                  _chip('Fechas: $dateText', color: Colors.grey.shade700),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (ubic.isNotEmpty || reg.isNotEmpty || linkOnline.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ubic.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.place, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(ubic, style: t.bodyMedium)),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _openMap(context, ubic),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Mapa'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      if (reg.isNotEmpty)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openUrlFlexible(context, reg),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Enlace al evento'),
                            style: FilledButton.styleFrom(
                              backgroundColor: BrandColors.secondary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (reg.isNotEmpty && linkOnline.isNotEmpty)
                        const SizedBox(width: 10),
                      if (linkOnline.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openUrlFlexible(context, linkOnline),
                            icon: const Icon(Icons.play_circle_outline),
                            label: const Text('Acceso Online'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Contenido HTML con soportes de enlace (firma v3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Html(
              data: html,
              onLinkTap: (String? url, Map<String, String> attributes, dom.Element? element) {
                if (url != null) _openUrlFlexible(context, url);
              },
              onAnchorTap: (String? url, Map<String, String> attributes, dom.Element? element) {
                if (url != null) _openUrlFlexible(context, url);
              },
              style: {
                'p': Style(lineHeight: const LineHeight(1.6), fontSize: FontSize(16)),
                'h2': Style(margin: Margins.only(top: 16, bottom: 8)),
                'h3': Style(margin: Margins.only(top: 16, bottom: 8)),
                'img': Style(margin: Margins.only(top: 12, bottom: 12)),
                'ul': Style(margin: Margins.only(left: 16)),
                'ol': Style(margin: Margins.only(left: 16)),
                'a' : Style(color: BrandColors.secondary),
              },
            ),
          ),

          if (orgNom.isNotEmpty || orgMail.isNotEmpty || orgTel.isNotEmpty || orgWeb.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Organizador', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    color: const Color(0xFFF5F5F5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (orgNom.isNotEmpty)
                            Text(orgNom, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (orgMail.isNotEmpty)
                                ActionChip(
                                  label: const Text('Email'),
                                  avatar: const Icon(Icons.email_outlined, size: 18),
                                  onPressed: () => _openUrlFlexible(context, orgMail),
                                ),
                              if (orgTel.isNotEmpty)
                                ActionChip(
                                  label: const Text('Teléfono'),
                                  avatar: const Icon(Icons.call_outlined, size: 18),
                                  onPressed: () => _openUrlFlexible(context, orgTel),
                                ),
                              if (orgWeb.isNotEmpty)
                                ActionChip(
                                  label: const Text('Web'),
                                  avatar: const Icon(Icons.link, size: 18),
                                  onPressed: () => _openUrlFlexible(context, orgWeb),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (ig.isNotEmpty || fb.isNotEmpty || tw.isNotEmpty || yt.isNotEmpty || inn.isNotEmpty || tk.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comparte el evento', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      if (ig.isNotEmpty)  _socialIcon(context, Icons.camera_alt_outlined, 'Instagram', ig),
                      if (fb.isNotEmpty)  _socialIcon(context, Icons.facebook, 'Facebook', fb),
                      if (tw.isNotEmpty)  _socialIcon(context, Icons.alternate_email, 'Twitter/X', tw),
                      if (yt.isNotEmpty)  _socialIcon(context, Icons.ondemand_video, 'YouTube', yt),
                      if (inn.isNotEmpty) _socialIcon(context, Icons.business_center_outlined, 'LinkedIn', inn),
                      if (tk.isNotEmpty)  _socialIcon(context, Icons.music_note, 'TikTok', tk),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _chip(String text, {Color? color}) {
    final c = color ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .10),
        border: Border.all(color: c.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
          fontSize: 12,
        ),
      ),
    );
  }

  static Widget _socialIcon(BuildContext context, IconData icon, String label, String urlRaw) {
    return InkWell(
      onTap: () => _openUrlFlexible(context, urlRaw),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _fromModel(dynamic m) {
    String? pick(String k) {
      try {
        final dyn = (m as dynamic);
        switch (k) {
          case 'titulo': return dyn.titulo?.toString();
          case 'title': return dyn.title?.toString();
          case 'nombre': return dyn.nombre?.toString();
          case 'descripcionHtml': return dyn.descripcionHtml?.toString();
          case 'descripcion': return dyn.descripcion?.toString();
          case 'html': return dyn.html?.toString();
          case 'imagenDestacada': return dyn.imagenDestacada?.toString();
          case 'imagenUrl': return dyn.imagenUrl?.toString();
          case 'coverUrl': return dyn.coverUrl?.toString();
          case 'fechaInicio': return dyn.fechaInicio?.toString();
          case 'fechaFin': return dyn.fechaFin?.toString();
          case 'ubicacion': return dyn.ubicacion?.toString();
          case 'linkRegistro': return dyn.linkRegistro?.toString();
          case 'emailOrganizador': return dyn.emailOrganizador?.toString();
          case 'webOrganizador': return dyn.webOrganizador?.toString();
          case 'facebook': return dyn.facebook?.toString();
          case 'instagram': return dyn.instagram?.toString();
          case 'twitter': return dyn.twitter?.toString();
          case 'youtube': return dyn.youtube?.toString();
          case 'precio': return dyn.precio?.toString();
          case 'modalidad': return dyn.modalidad?.toString();
        }
      } catch (_) {}
      return null;
    }

    final titulo = pick('titulo') ?? pick('title') ?? pick('nombre') ?? '';
    final imagen = pick('imagenDestacada') ?? pick('imagenUrl') ?? pick('coverUrl') ?? '';
    final html   = pick('descripcionHtml') ?? pick('descripcion') ?? pick('html') ?? '';

    final fIni   = _normalizeDate(pick('fechaInicio'));
    final fFin   = _normalizeDate(pick('fechaFin'));
    final ubic   = pick('ubicacion') ?? '';
    final reg    = pick('linkRegistro') ?? '';

    final email  = pick('emailOrganizador') ?? '';
    final web    = pick('webOrganizador') ?? '';
    final fb     = pick('facebook') ?? '';
    final ig     = pick('instagram') ?? '';
    final tw     = pick('twitter') ?? '';
    final yt     = pick('youtube') ?? '';

    final precio = pick('precio') ?? '';
    final modalidad = pick('modalidad') ?? '';

    return {
      'titulo': titulo,
      'imagen': imagen,
      'html': html,
      'fecha_inicio': fIni,
      'fecha_fin': fFin,
      'ubicacion': ubic,
      'link_registro': reg,
      'org_nombre': '',
      'org_email': email,
      'org_tel': '',
      'org_web': web,
      'fb': fb,
      'ig': ig,
      'tw': tw,
      'yt': yt,
      'precio': precio,
      'modalidad': modalidad.isEmpty ? 'Presencial' : modalidad,
    };
  }
}
