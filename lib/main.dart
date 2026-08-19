import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'pages/mainPage.dart';
import 'api/updater.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final ValueNotifier<List<String>> appLogs = ValueNotifier<List<String>>([]);

void logMessage(String message) {
  final currentLogs = List<String>.from(appLogs.value);
  currentLogs.insert(
    0,
    "[${DateTime.now().toIso8601String().split('T').last.substring(0, 8)}] $message",
  );
  if (currentLogs.length > 1000) currentLogs.removeLast();
  appLogs.value = currentLogs;
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      MediaKit.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        logMessage("FLUTTER ERROR: ${details.exceptionAsString()}");
        FlutterError.presentError(details);
      };

      await dotenv.load(fileName: ".env");

      runApp(const MyApp());
    },
    (error, stack) {
      logMessage("DART ERROR: $error\n$stack");
    },
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        logMessage(line);
        parent.print(zone, line);
      },
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoginAniList();
      AppUpdater.checkForUpdates(context);
    });
  }

  Future<void> _checkAndLoginAniList() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('anilist_token');
    String? username = prefs.getString('anilist_username');

    if (token == null ||
        token.isEmpty ||
        username == null ||
        username == 'Nieznany') {
      print(
        "Brak poprawnego tokenu lub nazwy profilu. Odpalam w pełni zautomatyzowane logowanie...",
      );

      const String clientId = "42228";
      final String authUrl =
          "https://anilist.co/api/v2/oauth/authorize?client_id=$clientId&response_type=token";

      try {
        final result = await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: "zolanime",
        );

        final match = RegExp(r'access_token=([^&]+)').firstMatch(result);

        if (match != null && match.groupCount >= 1) {
          final extractedToken = match.group(1)!;

          print(
            "✅ Przechwycono token z przeglądarki w tle! Weryfikacja nazwy...",
          );

          final response = await http.post(
            Uri.parse('https://graphql.anilist.co'),
            headers: {
              'Authorization': 'Bearer $extractedToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'query': '''
                query {
                  Viewer {
                    name
                  }
                }
              ''',
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final fetchedUsername = data['data']['Viewer']['name'];

            await prefs.setString('anilist_token', extractedToken);
            await prefs.setString('anilist_username', fetchedUsername);

            print(
              "✅ Sukces! Zalogowano profil na stałe jako: $fetchedUsername",
            );

            setState(() {
              _isInitialized = true;
            });
          } else {
            print("❌ Błąd pobierania nazwy z AniList: ${response.statusCode}");
          }
        }
      } catch (e) {
        print(
          "❌ Logowanie zostało anulowane przez użytkownika lub wystąpił błąd: $e",
        );
      }
    } else {
      print("Zalogowano automatycznie jako: $username");
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: _isInitialized
          ? const MainPage()
          : const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.purple),
              ),
            ),
    );
  }
}
