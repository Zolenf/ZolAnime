import 'package:flutter/material.dart';
import '../models/anime.dart';
import '../models/card.dart';
import 'SearchPage.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedid = 0;
  late Future<List<Anime>> _animeListFuture;

  void _updateList() {
    setState(() {
      _animeListFuture = getAnimeList(_selectedid);
    });
  }

  @override
  void initState() {
    super.initState();
    _updateList(); // Pierwsze pobranie danych
  }

  @override
  Widget build(BuildContext context) {
    // ZWRACAMY OD RAZU SCAFFOLD (MaterialApp jest teraz oczko wyżej w main.dart)
    return Scaffold(
      appBar: AppBar(
        title: const Text("ZolAnime"),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Szukaj anime',
            onPressed: () async {
              // Teraz context znajduje się W ŚRODKU MaterialApp i bez problemu widzi Navigatora
              final needsRefresh = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );

              if (needsRefresh == true) {
                setState(() {
                  _updateList();
                });
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[900]!,
                  Colors.purple[900]!,
                  Colors.grey[900]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(color: Colors.black.withAlpha(120)),
          FutureBuilder(
            future: _animeListFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final animeList = snapshot.data ?? [];
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: animeList.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2 / 3,
                ),
                itemBuilder: (context, index) {
                  // Karta niech będzie "głupia" - tylko wyświetla dane
                  return AnimeCard(anime: animeList[index]);
                },
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (value) => {
          setState(() {
            _selectedid = value;
            _updateList();
          }),
        },
        selectedIndex: _selectedid,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.remove_red_eye),
            label: "Watching",
          ),
          NavigationDestination(icon: Icon(Icons.bookmark), label: "Planning"),
          NavigationDestination(
            icon: Icon(Icons.check_rounded),
            label: "completed",
          ),
        ],
      ),
    );
  }
}
