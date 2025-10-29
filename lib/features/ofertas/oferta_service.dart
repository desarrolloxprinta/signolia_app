// lib/presentation/ofertas/data/oferta_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'oferta_model.dart';

class OfertaService {
  static const String baseUrl = "https://signolia.com/wp-json/wp/v2/ofertas";

  /// Lista SOLO publicadas, con _embed y paginación opcional.
  Future<List<Oferta>> fetchOfertas({
    int page = 1,
    int perPage = 10,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      '_embed': '1',
      'status': 'publish', // ✅ solo publicadas
      'page': '$page',
      'per_page': '$perPage',
    });

    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return Oferta.listFromJson(res.body);
    }
    throw Exception("Error al cargar ofertas (HTTP ${res.statusCode})");
  }

  /// Detalle: si por alguna razón el endpoint devuelve un estado != publish,
  /// rechazamos la carga para mantener la regla de “solo publicadas”.
  Future<Oferta> fetchOferta(int id) async {
    final uri = Uri.parse("$baseUrl/$id?_embed=1");
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      if ((map['status'] as String?)?.toLowerCase() != 'publish') {
        throw Exception("La oferta $id no está publicada");
      }
      return Oferta.fromJson(map);
    }
    // 404 si no existe o no está accesible públicamente
    throw Exception("Error al cargar oferta (HTTP ${res.statusCode})");
  }
}
