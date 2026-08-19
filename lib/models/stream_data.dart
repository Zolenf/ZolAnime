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

class ApiSubtitle {
  final String url;
  final String label;
  final String lang;

  ApiSubtitle({required this.url, required this.label, required this.lang});

  factory ApiSubtitle.fromJson(Map<String, dynamic> json) {
    return ApiSubtitle(
      url: json['url'] ?? json['file'] ?? '',
      label: json['label'] ?? '',
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
      embedUrl: json['embedUrl'] as String?,
      quality: json['quality'] as String?,
    );
  }
}

class StreamResponse {
  final List<VideoStream> streams;
  final String? subtitleUrl;
  final double? introStart;
  final double? introEnd;
  final double? outroStart;
  final double? outroEnd;

  StreamResponse({
    required this.streams,
    this.subtitleUrl,
    this.introStart,
    this.introEnd,
    this.outroStart,
    this.outroEnd,
  });

  factory StreamResponse.fromJson(Map<String, dynamic> json) {
    final streamsList = json['streams'] as List<dynamic>? ?? [];

    String? foundSub;
    if (json['subtitles'] != null) {
      final subsList = json['subtitles'] as List<dynamic>;
      if (subsList.isNotEmpty) {
        foundSub = subsList.first['url'] ?? subsList.first['file'];
      }
    }

    double? iStart, iEnd, oStart, oEnd;

    if (json['intro'] != null) {
      iStart = json['intro']['start']?.toDouble();
      iEnd = json['intro']['end']?.toDouble();
    }

    if (json['outro'] != null) {
      oStart = json['outro']['start']?.toDouble();
      oEnd = json['outro']['end']?.toDouble();
    }

    return StreamResponse(
      streams: streamsList.map((s) => VideoStream.fromJson(s)).toList(),
      subtitleUrl: foundSub,
      introStart: iStart,
      introEnd: iEnd,
      outroStart: oStart,
      outroEnd: oEnd,
    );
  }

  VideoStream? get bestHls {
    final hlsStreams = streams.where((s) => s.type == 'hls').toList();
    if (hlsStreams.isEmpty) return null;
    return hlsStreams.first;
  }
}
