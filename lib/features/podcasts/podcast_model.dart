/// Modelo normalizado para que las vistas puedan usar:
/// - thumbnailUrl
/// - sinopsisText
/// - durationMinutes
/// - videoUrl
/// - guests / segments / links
class PodcastItem {
  final int id;
  final String title;

  // Crudo de WP por si lo necesitas en otra parte
  final Map<String, dynamic> raw;

  // Campos base que llegan desde el API de WP
  final String? excerptHtml; // excerpt.rendered
  final String? sinopsisHtml; // meta['sinopsis'] (HTML)
  final String?
  thumbnail; // URL ya resuelta en el servicio (miniatura ID -> URL)
  final int? duration; // meta['duracion'] en minutos
  final String? episodeNumber; // meta['numero-de-episodio']
  final String? video; // meta['video'] (YouTube)
  final List<PodcastGuest> guests;
  final List<PodcastSegment> segments;
  final List<PodcastLink> links;

  PodcastItem({
    required this.id,
    required this.title,
    required this.raw,
    this.excerptHtml,
    this.sinopsisHtml,
    this.thumbnail,
    this.duration,
    this.episodeNumber,
    this.video,
    this.guests = const [],
    this.segments = const [],
    this.links = const [],
  });

  /// ======= GETTERS que esperan las vistas =======
  String? get thumbnailUrl => thumbnail;

  /// Texto plano de sinopsis (si no hay, cae a excerpt)
  String get sinopsisText {
    final html = (sinopsisHtml?.trim().isNotEmpty ?? false)
        ? sinopsisHtml!
        : (excerptHtml ?? '');
    return _stripHtml(html);
  }

  int? get durationMinutes => duration;

  String? get videoUrl => video;

  /// ======= Helpers =======
  static String _stripHtml(String html) {
    final reg = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return html
        .replaceAll(reg, ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#038;', '&')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', '’')
        .replaceAll('&#8211;', '–')
        .trim();
  }

  /// Parser genérico desde WP (detalle o lista)
  factory PodcastItem.fromWp(
    Map<String, dynamic> json, {
    String? resolvedThumbnailUrl,
    List<PodcastGuest>? guests,
    List<PodcastSegment>? segments,
    List<PodcastLink>? links,
  }) {
    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse('${json['id']}') ?? -1;
    final title = (json['title']?['rendered'] ?? '').toString();
    final excerpt = (json['excerpt']?['rendered'] ?? '').toString();

    // Muchos custom fields vienen bajo 'meta' en tu API
    final meta = (json['meta'] is Map<String, dynamic>)
        ? (json['meta'] as Map<String, dynamic>)
        : json;

    final sinopsis = (meta['sinopsis'] ?? json['sinopsis'] ?? '').toString();
    final duracionStr = (meta['duracion'] ?? json['duracion'] ?? '').toString();
    final numeroEpisodio =
        (meta['numero-de-episodio'] ?? json['numero-de-episodio'] ?? '')
            .toString();
    final video = (meta['video'] ?? json['video'] ?? '').toString();

    int? duracion;
    if (duracionStr.isNotEmpty) {
      duracion = int.tryParse(duracionStr);
    }

    return PodcastItem(
      id: id,
      title: _stripHtml(title),
      raw: Map<String, dynamic>.from(json),
      excerptHtml: excerpt,
      sinopsisHtml: sinopsis,
      thumbnail:
          resolvedThumbnailUrl, // el servicio nos pasa la URL ya resuelta
      duration: duracion,
      episodeNumber: numeroEpisodio.isEmpty ? null : numeroEpisodio,
      video: video.isEmpty ? null : video,
      guests: guests ?? const [],
      segments: segments ?? const [],
      links: links ?? const [],
    );
  }

  Map<String, dynamic> toCacheMap() => {
    'raw': raw,
    'thumbnail': thumbnail,
    'guests': guests.map((g) => g.toCacheMap()).toList(),
    'segments': segments.map((s) => s.toCacheMap()).toList(),
    'links': links.map((l) => l.toCacheMap()).toList(),
  };

  factory PodcastItem.fromCache(Map<String, dynamic> cache) {
    final raw = Map<String, dynamic>.from(cache['raw'] as Map? ?? const {});
    final guests = (cache['guests'] as List<dynamic>? ?? const [])
        .map((g) => PodcastGuest.fromCache(Map<String, dynamic>.from(g as Map)))
        .toList();
    final segments = (cache['segments'] as List<dynamic>? ?? const [])
        .map(
          (s) => PodcastSegment.fromCache(Map<String, dynamic>.from(s as Map)),
        )
        .toList();
    final links = (cache['links'] as List<dynamic>? ?? const [])
        .map((l) => PodcastLink.fromCache(Map<String, dynamic>.from(l as Map)))
        .toList();

    return PodcastItem.fromWp(
      raw,
      resolvedThumbnailUrl: cache['thumbnail'] as String?,
      guests: guests,
      segments: segments,
      links: links,
    );
  }
}

class PodcastGuest {
  final int id;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final String? linkedin;
  final String? youtube;
  final String? web;
  final Map<String, dynamic> raw;

  PodcastGuest({
    required this.id,
    required this.name,
    required this.raw,
    this.bio,
    this.avatarUrl,
    this.linkedin,
    this.youtube,
    this.web,
  });

  factory PodcastGuest.fromWp(
    Map<String, dynamic> json, {
    String? resolvedAvatar,
  }) {
    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse('${json['id']}') ?? -1;
    final name = (json['title']?['rendered'] ?? '').toString();
    final bio = (json['bio_invitado'] ?? '').toString();

    // Social
    String? pick(String key) {
      final v = json[key] ?? json['meta']?[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return PodcastGuest(
      id: id,
      name: PodcastItem._stripHtml(name),
      raw: Map<String, dynamic>.from(json),
      bio: PodcastItem._stripHtml(bio),
      avatarUrl: resolvedAvatar,
      linkedin: pick('linkedin') ?? pick('linkedin-'),
      youtube: pick('youtube') ?? pick('youtube-'),
      web: pick('web') ?? pick('web-'),
    );
  }

  Map<String, dynamic> toCacheMap() => {'raw': raw, 'avatarUrl': avatarUrl};

  factory PodcastGuest.fromCache(Map<String, dynamic> cache) {
    final raw = Map<String, dynamic>.from(cache['raw'] as Map? ?? const {});
    final guest = PodcastGuest.fromWp(
      raw,
      resolvedAvatar: cache['avatarUrl'] as String?,
    );
    return guest;
  }
}

class PodcastSegment {
  final String? time;
  final String title;

  PodcastSegment({this.time, required this.title});

  Map<String, dynamic> toCacheMap() => {'time': time, 'title': title};

  factory PodcastSegment.fromCache(Map<String, dynamic> cache) =>
      PodcastSegment(
        time: cache['time'] as String?,
        title: (cache['title'] ?? '') as String,
      );
}

class PodcastLink {
  final String url;
  final String? title;

  PodcastLink({required this.url, this.title});

  Map<String, dynamic> toCacheMap() => {'url': url, 'title': title};

  factory PodcastLink.fromCache(Map<String, dynamic> cache) => PodcastLink(
    url: (cache['url'] ?? '') as String,
    title: cache['title'] as String?,
  );
}
