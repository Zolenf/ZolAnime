import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/episodes.dart';
import '../models/stream_data.dart';

String anilist = 'https://graphql.anilist.co';
String anivexa = 'https://anivexa-api-qg31.onrender.com/';
String miruro = 'https://hunk-unadorned-uncoated.ngrok-free.dev/';

Future<String> _getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('anilist_token') ?? '';
}

Future<String> _getUsername() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('anilist_username') ?? '';
}

Future<Map<String, dynamic>> fetchAnimeByStatus(String status) async {
  final username = await _getUsername();
  final String query =
      '''
    query {
      MediaListCollection(userName: "$username", type: ANIME, status: $status) {
        lists { entries { progress media { episodes id title { english romaji } coverImage { large } } } }
      }
    }
  ''';

  final token = await _getToken();

  final stopwatch = Stopwatch()..start();
  final response = await http.post(
    Uri.parse(anilist),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'query': query}),
  );
  stopwatch.stop();
  print(
    "⏳ Czas API: ${stopwatch.elapsedMilliseconds}ms | Status: ${response.statusCode}",
  );
  print(
    "📡 Nagłówki (Rate Limit?): ${response.headers['x-ratelimit-remaining']}",
  );
  print("🚨 Body: ${response.body}");
  return jsonDecode(response.body);
}

Future<({int progress, String notes})> fetchUserProgress(int mediaId) async {
  final username = await _getUsername();
  final String query =
      '''
    query (\$mediaId: Int) {
      MediaList(mediaId: \$mediaId, userName: "$username") {
        progress
        notes
      }
    }
  ''';

  try {
    final token = await _getToken();

    final stopwatch = Stopwatch()..start();
    final response = await http.post(
      Uri.parse(anilist),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'query': query,
        'variables': {'mediaId': mediaId},
      }),
    );
    stopwatch.stop();
    print(
      "⏳ Czas API: ${stopwatch.elapsedMilliseconds}ms | Status: ${response.statusCode}",
    );
    print(
      "📡 Nagłówki (Rate Limit?): ${response.headers['x-ratelimit-remaining']}",
    );
    print("🚨 Body: ${response.body}");

    final data = jsonDecode(response.body);
    if (data['data'] != null && data['data']['MediaList'] != null) {
      return (
        progress: data['data']['MediaList']['progress'] as int? ?? 0,
        notes: data['data']['MediaList']['notes'] as String? ?? '',
      );
    }
    return (progress: 0, notes: '');
  } catch (e) {
    return (progress: 0, notes: '');
  }
}

Future<({bool hasSub, bool hasDub})> fetchSubDub(int animeId) async {
  try {
    final stopwatch = Stopwatch()..start();

    final String fastProviders =
        'reanime/anikoto/anineko/anidbapp/2dhive/anizone/senshi/animedunya';

    final mResFuture = http.get(
      Uri.parse('${miruro}episodes/$animeId'),
      headers: {'ngrok-skip-browser-warning': 'true'},
    );
    final aResFuture = http.get(
      Uri.parse('${anivexa}episodes/$fastProviders/$animeId'),
      headers: {'Content-Type': 'application/json', 'x-api-key': 'halo'},
    );

    final responses = await Future.wait([mResFuture, aResFuture]);
    final mRes = responses[0];
    final aRes = responses[1];

    stopwatch.stop();
    print("⏳ Czas API (SubDub): ${stopwatch.elapsedMilliseconds}ms");

    bool hasSub = false;
    bool hasDub = false;

    void checkEpisodes(Map<String, dynamic> epsMap) {
      if (epsMap['sub'] != null && (epsMap['sub'] as List).isNotEmpty) {
        hasSub = true;
      }
      if (epsMap['dub'] != null && (epsMap['dub'] as List).isNotEmpty) {
        hasDub = true;
      }
    }

    if (mRes.statusCode == 200) {
      final mData = jsonDecode(mRes.body);
      if (mData['providers'] != null) {
        final providers = mData['providers'] as Map<String, dynamic>;
        providers.forEach((_, v) {
          if (v is Map<String, dynamic> && v.containsKey('episodes')) {
            checkEpisodes(v['episodes']);
          }
        });
      }
    }

    if (aRes.statusCode == 200) {
      final aData = jsonDecode(aRes.body);
      aData.forEach((key, value) {
        if (key == 'page' ||
            key == 'type' ||
            key == 'mappings' ||
            key == 'animepahe' ||
            value == null)
          return;
        if (value is Map<String, dynamic> && value.containsKey('episodes')) {
          checkEpisodes(value['episodes']);
        }
      });
    }

    return (hasSub: hasSub, hasDub: hasDub);
  } catch (e) {
    print("Błąd parsowania sub/dub: $e");
    return (hasSub: false, hasDub: false);
  }
}

Future<StreamResponse> fetchStreamDetails(String streamIdPath) async {
  String fullUrl;
  if (streamIdPath.startsWith('http')) {
    fullUrl = streamIdPath;
  } else if (streamIdPath.startsWith('watch/')) {
    fullUrl = '$miruro$streamIdPath';
  } else {
    fullUrl = '$anivexa$streamIdPath';
  }

  final stopwatch = Stopwatch()..start();
  final response = await http.get(
    Uri.parse(fullUrl),
    headers: {'ngrok-skip-browser-warning': 'true'},
  );
  stopwatch.stop();
  print(
    "⏳ Czas API: ${stopwatch.elapsedMilliseconds}ms | Status: ${response.statusCode}",
  );
  print(
    "📡 Nagłówki (Rate Limit?): ${response.headers['x-ratelimit-remaining']}",
  );
  print("🚨 Body: ${response.body}");

  if (response.statusCode != 200) {
    throw Exception("Błąd pobierania strumienia: ${response.statusCode}");
  }

  final data = jsonDecode(response.body);
  return StreamResponse.fromJson(data);
}

Future<AnimeEpisodes> fetchAnimeEpisodes(int id) async {
  final stopwatch = Stopwatch()..start();

  final String fastProviders =
      'reanime/anikoto/anineko/anidbapp/2dhive/anizone/senshi/animedunya';

  final mResFuture = http.get(
    Uri.parse('${miruro}episodes/$id'),
    headers: {'ngrok-skip-browser-warning': 'true'},
  );
  final aResFuture = http.get(
    Uri.parse('${anivexa}episodes/$fastProviders/$id'),
  );

  final responses = await Future.wait([mResFuture, aResFuture]);
  final mRes = responses[0];
  final aRes = responses[1];

  stopwatch.stop();
  print("⏳ Czas API (Odcinki): ${stopwatch.elapsedMilliseconds}ms");

  Map<String, dynamic> finalJson = {};

  if (mRes.statusCode == 200) {
    try {
      final mData = jsonDecode(mRes.body);
      if (mData['mappings'] != null) finalJson['mappings'] = mData['mappings'];
      if (mData['providers'] != null)
        finalJson['providers'] = mData['providers'];
    } catch (e) {}
  }

  if (aRes.statusCode == 200) {
    try {
      final aData = jsonDecode(aRes.body);
      finalJson['mappings'] ??= aData['mappings'];
      aData.forEach((k, v) {
        if (k != 'mappings' && k != 'page' && k != 'type') {
          finalJson[k] = v;
        }
      });
    } catch (e) {}
  }

  if (finalJson.isEmpty) {
    throw Exception("Failed to load episodes");
  }

  return AnimeEpisodes.fromJson(finalJson);
}

Future<bool> saveProgress(int mediaId, int progress, String notes) async {
  final String mutationString = '''
  mutation (\$mediaId: Int, \$progress: Int, \$notes: String) {
    SaveMediaListEntry (mediaId: \$mediaId, progress: \$progress, notes: \$notes) {
      id
      notes
    }
  }
  ''';

  final token = await _getToken();

  final stopwatch = Stopwatch()..start();
  final response = await http.post(
    Uri.parse(anilist),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'query': mutationString,
      'variables': {'mediaId': mediaId, 'progress': progress, 'notes': notes},
    }),
  );
  stopwatch.stop();
  print(
    "⏳ Czas API: ${stopwatch.elapsedMilliseconds}ms | Status: ${response.statusCode}",
  );
  print(
    "📡 Nagłówki (Rate Limit?): ${response.headers['x-ratelimit-remaining']}",
  );
  print("🚨 Body: ${response.body}");

  if (response.statusCode == 200) {
    print("Poprawnie zaktualizowano AniList: Odcinek $progress");
    return true;
  } else {
    print('Błąd zapisu AniList: ${response.body}');
    return false;
  }
}

Future<List<dynamic>> searchAnime(String queryStr) async {
  if (queryStr.trim().isEmpty) return [];

  final String query = '''
    query (\$search: String) {
      Page(page: 1, perPage: 20) {
        media(search: \$search, type: ANIME, sort: SEARCH_MATCH) {
          id
          title { english romaji }
          coverImage { large }
          episodes
        }
      }
    }
  ''';

  try {
    final token = await _getToken();

    final stopwatch = Stopwatch()..start();
    final response = await http.post(
      Uri.parse(anilist),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'query': query,
        'variables': {'search': queryStr},
      }),
    );
    stopwatch.stop();
    print(
      "⏳ Czas API: ${stopwatch.elapsedMilliseconds}ms | Status: ${response.statusCode}",
    );
    print(
      "📡 Nagłówki (Rate Limit?): ${response.headers['x-ratelimit-remaining']}",
    );
    print("🚨 Body: ${response.body}");

    final data = jsonDecode(response.body);
    if (data['data'] != null && data['data']['Page'] != null) {
      return data['data']['Page']['media'] ?? [];
    }
    return [];
  } catch (e) {
    print("Błąd wyszukiwania: $e");
    return [];
  }
}

Future<bool> addToWatching(int mediaId) async {
  final String mutationString = '''
  mutation (\$mediaId: Int) {
    SaveMediaListEntry (mediaId: \$mediaId, status: CURRENT) { id status }
  }
  ''';

  try {
    final token = await _getToken();

    final stopwatch = Stopwatch()..start();
    final response = await http.post(
      Uri.parse(anilist),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'query': mutationString,
        'variables': {'mediaId': mediaId},
      }),
    );
    stopwatch.stop();
    print(
      "⏳ Czas API: ${stopwatch.elapsedMilliseconds}ms | Status: ${response.statusCode}",
    );
    print(
      "📡 Nagłówki (Rate Limit?): ${response.headers['x-ratelimit-remaining']}",
    );
    print("🚨 Body: ${response.body}");

    if (response.statusCode == 200) {
      print("Pomyślnie dodano do Watching!");
      return true;
    } else {
      print('Błąd dodawania do listy: ${response.body}');
      return false;
    }
  } catch (e) {
    print("Błąd: $e");
    return false;
  }
}

Future<List<AniSkip>> fetchAniSkip(int malId, int episodeNumber) async {
  final url =
      'https://api.aniskip.com/v2/skip-times/$malId/$episodeNumber?types=op&types=ed&episodeLength=0';
  print("🌐 [AniSkip] Szukam skipów pod adresem: $url");

  try {
    final stopwatch = Stopwatch()..start();
    final response = await http.get(Uri.parse(url));
    print("🌐 [AniSkip] Kod odpowiedzi HTTP: ${response.statusCode}");
    stopwatch.stop();
    print(
      "⏳ Czas API: ${stopwatch.elapsedMilliseconds}ms | Status: ${response.statusCode}",
    );
    print(
      "📡 Nagłówki (Rate Limit?): ${response.headers['x-ratelimit-remaining']}",
    );
    print("🚨 Body: ${response.body}");
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['found'] == true) {
        List<AniSkip> skips = [];
        final results = data['results'] as List;

        for (var result in results) {
          skips.add(
            AniSkip(
              episode: episodeNumber,
              type: result['skipType'],
              start: (result['interval']['startTime'] as num).toDouble(),
              end: (result['interval']['endTime'] as num).toDouble(),
            ),
          );
        }
        print("✅ [AniSkip] Pomyślnie pobrano z bazy czasów: ${skips.length}");
        return skips;
      }
    } else if (response.statusCode == 404) {
      print(
        "⚠️ [AniSkip] Błąd 404: Społeczność nie dodała jeszcze czasów dla tego odcinka.",
      );
    } else {
      print("❌ [AniSkip] Błąd API: ${response.statusCode}");
    }
  } catch (e) {
    print("🚨 [AniSkip] Błąd połączenia: $e");
  }
  return [];
}
