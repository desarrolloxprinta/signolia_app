import 'dart:convert';
import 'package:http/http.dart' as http;
import 'evento_model.dart';

class EventoService {
  static const String baseUrl = "https://signolia.com/wp-json/wp/v2/eventos";

  Future<List<Evento>> fetchEventos() async {
    final response = await http.get(Uri.parse("$baseUrl?_embed"));
    if (response.statusCode == 200) {
      return Evento.listFromJson(response.body);
    } else {
      throw Exception("Error al cargar eventos");
    }
  }

  Future<Evento> fetchEvento(int id) async {
    final response = await http.get(Uri.parse("$baseUrl/$id?_embed"));
    if (response.statusCode == 200) {
      return Evento.fromJson(jsonDecode(response.body));
    } else {
      throw Exception("Error al cargar evento");
    }
  }
}
