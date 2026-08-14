import '../api/client.dart';

class Anime {
  final String? title, romaji;
  final String coverImage;
  final int id, episodes, progress;

  Anime({
    required this.title,
    required this.coverImage,
    required this.romaji,
    required this.id,
    required this.episodes,
    required this.progress,
  });

  // Fabryka - wyciąga dane z odpowiednich gałęzi JSON-a
  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      title: json['media']['title']['english'],
      romaji: json['media']['title']['romaji'] ?? 'brak tytułu',
      coverImage: json['media']['coverImage']['large'] ?? '',
      id: json['media']['id'] ?? -1,
      episodes: json['media']["episodes"] ?? -1,
      progress: json["progress"] ?? -1,
    );
  }
}

Future<List<Anime>> getAnimeList(int index) async {
  Map<String, dynamic> rawData;
  if (index == 0) {
    rawData = await fetchAnimeByStatus(
      "CURRENT",
    ); // Tutaj grzecznie czekamy na dane
  } else if (index == 1) {
    rawData = await fetchAnimeByStatus("PLANNING");
  } else {
    rawData = await fetchAnimeByStatus("COMPLETED");
  }

  // Przebijamy się przez warstwy GraphQL do konkretnej listy anime
  final lists = rawData['data']['MediaListCollection']['lists'] as List;
  if (lists.isEmpty) return []; // Zabezpieczenie przed pustą listą

  final entries = lists[0]['entries'] as List;

  // Pętla iterująca po JSON-ie i tworząca obiekty Anime
  return entries.map((entry) => Anime.fromJson(entry)).toList();
}
