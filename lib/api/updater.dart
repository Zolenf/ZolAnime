import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdater {
  // PODMIEŃ NA SWÓJ LOGIN I NAZWĘ REPO (np. 'olaf/Zolanime')
  static const String _repoUrl = 'Zolenf/ZolAnime';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoUrl/releases/latest';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final latestVersionTag = data['tag_name'] as String; // np. "v1.0.1"
      final latestVersion = latestVersionTag.replaceAll('v', ''); // np. "1.0.1"

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isNewerVersion(currentVersion, latestVersion)) {
        String? downloadUrl = _getDownloadUrl(data['assets'] as List<dynamic>);

        if (downloadUrl != null && context.mounted) {
          _showUpdatePrompt(context, latestVersion, downloadUrl);
        }
      }
    } catch (e) {
      print("Błąd sprawdzania aktualizacji: $e");
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    List<int> currentParts = current
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    List<int> latestParts = latest
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    for (int i = 0; i < 3; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static String? _getDownloadUrl(List<dynamic> assets) {
    if (Platform.isWindows) {
      try {
        return assets.firstWhere(
          (a) => a['name'].toString().endsWith('.msix'),
        )['browser_download_url'];
      } catch (_) {
        return null;
      }
    } else if (Platform.isAndroid) {
      try {
        return assets.firstWhere(
          (a) => a['name'].toString().endsWith('.apk'),
        )['browser_download_url'];
      } catch (_) {
        return null;
      }
    }
    return null; // Zabezpieczenie dla Linuxa, na wypadek jak będziesz z niego używał apki z Hyprland
  }

  static void _showUpdatePrompt(
    BuildContext context,
    String newVersion,
    String url,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Aktualizacja Zolanime",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Dostępna jest nowa wersja aplikacji (v$newVersion).\nCzy chcesz zaktualizować teraz?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Później", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () async {
              Navigator.pop(context);
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            child: const Text(
              "Zainstaluj",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
