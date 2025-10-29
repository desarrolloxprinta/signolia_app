class RouteTitles {
  /// Mapea nombres de rutas -> título humano.
  /// Ajusta las claves a los RouteSettings.name que uses al hacer push.
  static const Map<String, String> _titles = {
    'dashboard': 'Inicio',
    'noticias_list': 'Noticias',
    'noticias_detail_v2_from_dashboard': 'Noticia',
    'eventos_list': 'Eventos',
    'evento_detail': 'Evento',
    'ofertas_list': 'Ofertas',
    'oferta_detail': 'Oferta',
    'podcasts_list': 'Podcast',
    'podcast_detail': 'Podcast',
    'signolia_pro': 'Signolia Pro',
    // añade aquí el resto
  };

  /// Devuelve el título humano a partir del nombre de ruta.
  static String? forRouteName(String? routeName) {
    if (routeName == null) return null;
    return _titles[routeName];
  }
}
