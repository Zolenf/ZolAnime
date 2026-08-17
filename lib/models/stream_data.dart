class Resolution {
  // Rozdzielczość wideo
  final int width;
  // Szerokość i wysokość wideo
  final int height;

  // Konstruktor do tworzenia instancji Resolution
  Resolution({required this.width, required this.height});

  // Tworzenie obiektu Resolution z mapy JSON
  factory Resolution.fromJson(Map<String, dynamic> json) {
    return Resolution(
      // Zabezpieczenie przed null: jeśli brak 'width', ustaw 0
      width: json['width'] as int? ?? 0,
      // Zabezpieczenie przed null: jeśli brak 'height', ustaw 0
      height: json['height'] as int? ?? 0,
    );
  }
}

// NOWA KLASA: Przechowuje informacje o napisach z API Anivexa
class ApiSubtitle {
  // Bezpośredni link do pliku z napisami .vtt
  final String url;
  // Nazwa napisów do wyświetlenia (np. "English")
  final String label;
  // Krótki kod języka (np. "en")
  final String lang;

  // Konstruktor wymagający wszystkich 3 parametrów
  ApiSubtitle({required this.url, required this.label, required this.lang});

  // Funkcja ładująca napisy z JSON-a do naszego modelu
  factory ApiSubtitle.fromJson(Map<String, dynamic> json) {
    return ApiSubtitle(
      // Bezpieczne przypisanie URL
      url: json['url'] ?? '',
      // Bezpieczne przypisanie etykiety (fallback na pusty string)
      label: json['label'] ?? '',
      // Wyciągnięcie kodu języka (domyślnie 'en' jeśli brakuje)
      lang: json['srclang'] ?? 'en',
    );
  }
}

class VideoStream {
  final String url;
  final String type;
  final String audio;
  final String server;
  final String? referer;
  final String? embedUrl;
  final String? quality;
  final double? introStart;
  final double? introEnd;
  final double? outroStart;
  final double? outroEnd;

  VideoStream({
    required this.url,
    required this.type,
    required this.audio,
    required this.server,
    this.referer,
    this.embedUrl,
    this.quality,
    this.introStart,
    this.introEnd,
    this.outroStart,
    this.outroEnd,
  });

  factory VideoStream.fromJson(Map<String, dynamic> json) {
    return VideoStream(
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? '',
      audio: json['audio'] as String? ?? 'sub',
      server: json['server'] as String? ?? 'Unknown',
      referer: json['referer'] as String?,
      embedUrl: json['embedUrl'] as String?,
      quality: json['quality'] as String?,
      introStart: json['intro']?['start']?.toDouble(),
      introEnd: json['intro']?['end']?.toDouble(),
      outroStart: json['outro']?['start']?.toDouble(),
      outroEnd: json['outro']?['end']?.toDouble(),
    );
  }
}

class StreamResponse {
  final List<VideoStream> streams;
  final String? subtitleUrl;

  StreamResponse({required this.streams, this.subtitleUrl});

  factory StreamResponse.fromJson(Map<String, dynamic> json) {
    final streamsList = json['streams'] as List<dynamic>? ?? [];

    String? foundSub;
    if (json['subtitles'] != null) {
      final subsList = json['subtitles'] as List<dynamic>;
      if (subsList.isNotEmpty) {
        foundSub = subsList.first['url'];
      }
    }

    return StreamResponse(
      streams: streamsList.map((s) => VideoStream.fromJson(s)).toList(),
      subtitleUrl: foundSub,
    );
  }

  VideoStream? get bestHls {
    final hlsStreams = streams.where((s) => s.type == 'hls').toList();
    if (hlsStreams.isEmpty) return null;
    return hlsStreams.first;
  }
}
