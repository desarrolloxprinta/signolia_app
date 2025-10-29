import 'package:flutter/material.dart';
import '../../../features/ofertas/oferta_model.dart';
import 'oferta_detail_screen.dart';

class OfertaCard extends StatelessWidget {
  final Oferta oferta;
  const OfertaCard({super.key, required this.oferta});

  String _fmt(DateTime? d) => d == null ? '' : "${d.day}/${d.month}/${d.year}";

  // ───────────────────────── Adaptador Oferta -> mapa WP ─────────────────────────
  Map<String, dynamic> _toWpPost(Oferta o) {
    // Helpers de lectura con fallback
    String? s(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

    // Título
    final title = s(o.titulo) ?? s(o.title) ?? '';

    // Enlace público de Signolia (para el botón "Rellenar formulario en Signolia")
    final linkPublico = s(o.linkPublico) ?? s(o.link) ?? '';

    // Descripción corta (excerpt)
    final excerpt = s(o.excerptHtml) ?? s(o.descripcionCorta) ?? '';

    // Descripción larga de la oferta
    final descripcion = s(o.descripcionOferta) ?? s(o.descripcionHtml) ?? '';

    // Fechas en epoch (segundos)
    int? toEpochSeconds(DateTime? d) =>
        d == null ? null : (d.millisecondsSinceEpoch / 1000).round();

    final fechaIniEpoch = o.fechaInicioEpoch ?? toEpochSeconds(o.fechaInicio) ?? 0;
    final fechaFinEpoch = o.fechaFinEpoch ?? toEpochSeconds(o.fechaFin) ?? 0;

    // Empresa / contacto
    final nombreEmpresa = s(o.nombreEmpresa) ?? s(o.empresa) ?? '';
    final direccion     = s(o.direccionEmpresa) ?? s(o.direccion) ?? '';
    final email         = s(o.emailEmpresa) ?? s(o.email) ?? '';
    final telefono      = s(o.telefonoEmpresa) ?? s(o.telefono) ?? '';
    final webEmpresa    = s(o.webEmpresa) ?? s(o.web) ?? '';

    // Descuento
    final descuento     = s(o.descuento) ?? '';

    // Link externo de la promo (si existe)
    final linkOfertaExt = s(o.linkExterno) ?? s(o.linkOferta) ?? '';

    // Imagen destacada
    final img = s(o.imagenDestacada) ?? s(o.imageUrl);

    final map = <String, dynamic>{
      'id': o.id,
      'link': linkPublico ?? '',

      'title': {
        'rendered': title,
      },
      'excerpt': {
        'rendered': excerpt ?? '',
      },

      'meta': {
        'descripcion_oferta'   : descripcion ?? '',
        'fecha_inicio_oferta'  : fechaIniEpoch,
        'fecha_fin_oferta'     : fechaFinEpoch,
        'nombre_empresa_oferta': nombreEmpresa ?? '',
        'direccion_de_la_empresa': direccion ?? '',
        'email_empresa_oferta' : email ?? '',
        'telefono_empresa_oferta': telefono ?? '',
        'web_oferta_empresa'   : webEmpresa ?? '',
        'descuento_oferta'     : descuento ?? '',
        'link_oferta'          : linkOfertaExt ?? '',
      },
    };

    if (img != null && img.isNotEmpty) {
      map['_embedded'] = {
        'wp:featuredmedia': [
          {'source_url': img}
        ],
      };
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = oferta.estaActiva
        ? Colors.green.withValues(alpha: 0.12)
        : Colors.red.withValues(alpha: 0.12);
    final chipText = oferta.estaActiva ? "Activa" : "Expirada";
    final chipTextColor = oferta.estaActiva ? Colors.green : Colors.red;

    return InkWell(
      onTap: () {
        // 👉 Usa SIEMPRE el constructor nombrado desde el mapa WP
        final wpPost = _toWpPost(oferta);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfertaDetailScreen.fromWp(post: wpPost),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Imagen
          if (oferta.imagenDestacada != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Image.network(
                oferta.imagenDestacada!,
                width: 120, height: 170, fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 120, height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Icon(Icons.local_offer, size: 40, color: Colors.grey[600]),
            ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oferta.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chipText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: chipTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (oferta.fechaInicio != null)
                      Text(
                        "🗓 ${_fmt(oferta.fechaInicio)}"
                        "${oferta.fechaFin != null ? " - ${_fmt(oferta.fechaFin)}" : ""}",
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                  ]),
                  if ((oferta.descuento ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "💸 ${oferta.descuento}",
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if ((oferta.empresa ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "🏢 ${oferta.empresa}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
