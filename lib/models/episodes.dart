class EpisodeSource {
  final String id;
  final String audio;
  final String provider;

  EpisodeSource({
    required this.id,
    required this.audio,
    required this.provider,
  });
}

class EpisodeDetails {
  final int number;
  final String title;
  final String description;
  final String image;
  final String airDate;

  final Map<String, Map<String, EpisodeSource>> sources = {};

  EpisodeDetails({
    required this.number,
    required this.title,
    required this.description,
    required this.image,
    required this.airDate,
  });

  void addSource(String provider, String audioType, String id) {
    sources.putIfAbsent(provider, () => {});
    sources[provider]![audioType] = EpisodeSource(
      id: id,
      audio: audioType,
      provider: provider,
    );
  }
}

class AniSkip {
  final int episode;
  final String type;
  final double start;
  final double end;

  AniSkip({
    required this.episode,
    required this.type,
    required this.start,
    required this.end,
  });

  factory AniSkip.fromJson(Map<String, dynamic> json) {
    return AniSkip(
      episode: (json['episode'] as num).toInt(),
      type: json['type'] as String,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
    );
  }
}

class AnimeEpisodes {
  final Map<int, EpisodeDetails> episodes = {};
  final List<AniSkip> skipTimes = [];
  int? malId; // <--- DODANO: Przechowuje id z MyAnimeList dla AniSkip

  AnimeEpisodes();

  factory AnimeEpisodes.fromJson(Map<String, dynamic> json) {
    final animeEps = AnimeEpisodes();

    // Łapiemy malId z sekcji mappings
    animeEps.malId = json['mappings']?['malId'];

    // 1. Parsowanie AniSkip (Oparte na mappings z Anivexa)
    final aniskipList = json['mappings']?['aniskip'] as List<dynamic>? ?? [];
    for (var skip in aniskipList) {
      animeEps.skipTimes.add(AniSkip.fromJson(skip));
    }

    // 2. Przemielenie całej reszty JSONa z dostawcami
    json.forEach((providerName, providerData) {
      if (providerName == 'page' ||
          providerName == 'type' ||
          providerName == 'mappings' ||
          providerName == 'animepahe' ||
          providerData == null) {
        return;
      }

      if (providerData is Map<String, dynamic> &&
          providerData.containsKey('episodes')) {
        final epsMap = providerData['episodes'] as Map<String, dynamic>;

        epsMap.forEach((audioType, episodesList) {
          if (episodesList is! List) return;

          for (var epJson in episodesList) {
            final number = (epJson['number'] as num).toInt();

            if (!animeEps.episodes.containsKey(number)) {
              animeEps.episodes[number] = EpisodeDetails(
                number: number,
                title: epJson['title'] ?? 'Odcinek $number',
                description: epJson['description'] ?? 'Brak opisu.',
                image: epJson['image'] ?? '',
                airDate: epJson['airDate'] ?? '',
              );
            }

            animeEps.episodes[number]!.addSource(
              providerName,
              audioType,
              epJson['id'],
            );
          }
        });
      }
    });

    return animeEps;
  }
}
