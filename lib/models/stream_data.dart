class Resolution {
  final int width;
  final int height;

  Resolution({required this.width, required this.height});

  factory Resolution.fromJson(Map<String, dynamic> json) {
    return Resolution(
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
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

  VideoStream({
    required this.url,
    required this.type,
    required this.audio,
    required this.server,
    this.referer,
    this.embedUrl,
    this.quality,
  });

  factory VideoStream.fromJson(Map<String, dynamic> json) {
    return VideoStream(
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? '',
      audio: json['audio'] as String? ?? 'sub',
      server: json['server'] as String? ?? 'Unknown',
      referer: json['referer'] as String?,
      embedUrl: json['embed'] as String?,
      quality: json['quality'] as String?,
    );
  }
}

class StreamResponse {
  final List<VideoStream> streams;

  StreamResponse({required this.streams});

  factory StreamResponse.fromJson(Map<String, dynamic> json) {
    final streamsList = json['streams'] as List<dynamic>? ?? [];
    return StreamResponse(
      streams: streamsList.map((s) => VideoStream.fromJson(s)).toList(),
    );
  }

  VideoStream? get bestHls {
    // Media Kit obsługuje tylko streamy bezpośrednie, ignorujemy "embed"
    final hlsStreams = streams.where((s) => s.type == 'hls').toList();
    if (hlsStreams.isEmpty) return null;

    // Pobieramy po prostu pierwszy najwyższy priorytet z Anivexa
    // (Anivexa sortuje HLS domyślnie pod priorytet więc bierzemy .first)
    return hlsStreams.first;
  }
}
