import 'dart:convert';

class Evento {
  final int id;
  final String titulo;
  final String descripcion;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? ubicacion;
  final String? nombreOrganizador;
  final String? emailOrganizador;
  final String? telefonoOrganizador;
  final String? webOrganizador;
  final String? precio;
  final String? linkRegistro;
  final String? instagram;
  final String? facebook;
  final String? linkedin;
  final String? tiktok;
  final String? imagenDestacada; // url de la imagen

  Evento({
    required this.id,
    required this.titulo,
    required this.descripcion,
    this.fechaInicio,
    this.fechaFin,
    this.ubicacion,
    this.nombreOrganizador,
    this.emailOrganizador,
    this.telefonoOrganizador,
    this.webOrganizador,
    this.precio,
    this.linkRegistro,
    this.instagram,
    this.facebook,
    this.linkedin,
    this.tiktok,
    this.imagenDestacada,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      id: json['id'],
      titulo: json['title']?['rendered'] ?? '',
      descripcion: json['descripcion'] ?? '',
      fechaInicio: json['fecha'] != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(json['fecha']) * 1000)
          : null,
      fechaFin: json['fecha_fin'] != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(json['fecha_fin']) * 1000)
          : null,
      ubicacion: json['ubicacion'],
      nombreOrganizador: json['nombre_organizador'],
      emailOrganizador: json['email_organizador'],
      telefonoOrganizador: json['telefono_organizador'],
      webOrganizador: json['web_del_organizador_'],
      precio: json['precio'],
      linkRegistro: json['link_registro'],
      instagram: json['instagram'],
      facebook: json['facebook'],
      linkedin: json['linkedin'],
      tiktok: json['tiktok'],
      imagenDestacada: json['_embedded']?['wp:featuredmedia']?[0]?['source_url'],
    );
  }

  static List<Evento> listFromJson(String body) {
    final List data = jsonDecode(body);
    return data.map((e) => Evento.fromJson(e)).toList();
  }
}
