import 'dart:convert';

class Oferta {
  final int id;
  final String titulo;
  final String descripcion; // descripcion_oferta
  final DateTime? fechaInicio; // fecha_inicio_oferta
  final DateTime? fechaFin;    // fecha_fin_oferta

  final String? empresa;       // nombre_empresa_oferta
  final String? direccion;     // direccion_de_la_empresa
  final String? email;         // email_empresa_oferta
  final String? telefono;      // telefono_empresa_oferta
  final String? webEmpresa;    // web_oferta_empresa

  final String? descuento;     // descuento_oferta
  final String? linkOferta;    // link_oferta

  final String? imagenDestacada; // vía _embedded wp:featuredmedia[0].source_url (si existe)

  Oferta({
    required this.id,
    required this.titulo,
    required this.descripcion,
    this.fechaInicio,
    this.fechaFin,
    this.empresa,
    this.direccion,
    this.email,
    this.telefono,
    this.webEmpresa,
    this.descuento,
    this.linkOferta,
    this.imagenDestacada,
  });

  bool get estaActiva {
    final now = DateTime.now();
    final desdeOk = (fechaInicio == null) || !now.isBefore(fechaInicio!);
    final hastaOk = (fechaFin == null) || !now.isAfter(fechaFin!);
    return desdeOk && hastaOk;
  }

  factory Oferta.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(String? v) {
      if (v == null || v.isEmpty) return null;
      return DateTime.fromMillisecondsSinceEpoch(int.parse(v) * 1000);
    }

    return Oferta(
      id: json['id'],
      titulo: json['title']?['rendered'] ?? '',
      descripcion: json['descripcion_oferta'] ?? '',
      fechaInicio: parseTs(json['fecha_inicio_oferta']),
      fechaFin: parseTs(json['fecha_fin_oferta']),
      empresa: json['nombre_empresa_oferta'],
      direccion: json['direccion_de_la_empresa'],
      email: json['email_empresa_oferta'],
      telefono: json['telefono_empresa_oferta'],
      webEmpresa: json['web_oferta_empresa'],
      descuento: json['descuento_oferta'],
      linkOferta: json['link_oferta'],
      imagenDestacada: json['_embedded']?['wp:featuredmedia']?[0]?['source_url'],
    );
  }

  get descripcionOferta => null;

  get fechaInicioEpoch => null;

  get fechaFinEpoch => null;

  get nombreEmpresa => null;

  get web => null;

  get autorNombre => null;

  get excerptHtml => null;

  get link => null;

  get linkPublico => null;

  get title => null;

  String? get descripcionCorta => null;

  String? get descripcionHtml => null;

  String? get direccionEmpresa => null;

  String? get emailEmpresa => null;

  String? get telefonoEmpresa => null;

  String? get linkExterno => null;

  String? get imageUrl => null;

  static List<Oferta> listFromJson(String body) {
    final List data = jsonDecode(body);
    return data.map((e) => Oferta.fromJson(e)).toList();
  }
}
