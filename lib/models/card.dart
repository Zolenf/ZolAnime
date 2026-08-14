import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'anime.dart';
import 'dart:ui';
import '../pages/wideoPage.dart';

class AnimeCard extends StatefulWidget {
  final Anime anime; // 1. Musisz zadeklarować pole w pamięci
  const AnimeCard({super.key, required this.anime}); // Przypisanie

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Odwołujesz się przez systemowy wskaźnik 'widget.'

    return AnimatedScale(
      scale: _isHovered ? 1.05 : 1,
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final wasWatched = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Wideopage(
                animeId: widget.anime.id,
                animeTitle:
                    widget.anime.title ?? widget.anime.romaji ?? "Brak tytułu",
              ),
            ),
          );

          if (wasWatched == true) {
            setState(() {
              // Tu wywołaj na nowo zapytanie pobierające kafelki anime na stronę główną
            });
          }
        },
        mouseCursor: SystemMouseCursors.click,
        onHover: (value) {
          setState(() {
            _isHovered = value;
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: widget.anime.id.toString(),
                child: Image.network(
                  widget.anime.coverImage,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                    child: Container(
                      color: Colors.black.withAlpha(180),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            widget.anime.title ?? widget.anime.romaji!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),

                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  color: Colors.grey[400],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    "Ep. ${widget.anime.progress}/${widget.anime.episodes}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
