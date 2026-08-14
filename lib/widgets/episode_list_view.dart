import 'package:flutter/material.dart';
import '../models/episodes.dart';

class EpisodeListView extends StatelessWidget {
  final Future<AnimeEpisodes> episodesFuture;
  final String selectedProvider;
  final dynamic currentEpisode;
  final int watchedEpisodes;
  final ValueChanged<AnimeEpisodes> onDataLoaded;
  final Function(dynamic ep) onEpisodeSelected;

  const EpisodeListView({
    super.key,
    required this.episodesFuture,
    required this.selectedProvider,
    required this.currentEpisode,
    required this.watchedEpisodes,
    required this.onDataLoaded,
    required this.onEpisodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnimeEpisodes>(
      future: episodesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          print(snapshot.error);
          print(snapshot.data);
          return const Center(child: Text("Błąd ładowania odcinków"));
        }

        final episodesData = snapshot.data!;
        final episodesList = episodesData.episodes.values.toList()
          ..sort((a, b) => a.number.compareTo(b.number));

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onDataLoaded(episodesData);
        });

        return ListView.builder(
          itemCount: episodesList.length,
          itemBuilder: (context, index) {
            final episode = episodesList[index];
            final bool isCurrent =
                currentEpisode != null &&
                episode.number == currentEpisode.number;

            final bool isWatched = episode.number <= watchedEpisodes;

            return EpisodeTile(
              episode: episode,
              selectedProvider: selectedProvider,
              isCurrent: isCurrent,
              isWatched: isWatched,
              onTap: onEpisodeSelected,
            );
          },
        );
      },
    );
  }
}

class EpisodeTile extends StatefulWidget {
  final dynamic episode;
  final String selectedProvider;
  final bool isCurrent;
  final bool isWatched;
  final Function(dynamic ep) onTap;

  const EpisodeTile({
    super.key,
    required this.episode,
    required this.selectedProvider,
    required this.isCurrent,
    required this.isWatched,
    required this.onTap,
  });

  @override
  State<EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<EpisodeTile> {
  bool _isHovered = false;

  Widget _buildAudioIcon(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1),
      ),
      child: Icon(icon, color: color, size: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerData = widget.episode.sources[widget.selectedProvider];
    final bool hasSub = providerData?['sub'] != null;
    final bool hasDub = providerData?['dub'] != null;

    final Color bgColor = widget.isCurrent
        ? Colors.purple.withValues(alpha: 0.35)
        : (widget.isWatched
              ? Colors.white.withValues(alpha: 0.02)
              : (_isHovered
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent));

    final Color textColor = widget.isCurrent
        ? Colors.white
        : (widget.isWatched ? Colors.white38 : Colors.white70);

    return AnimatedScale(
      scale: _isHovered ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isCurrent
                ? Colors.purple.shade300
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onHover: (value) => setState(() => _isHovered = value),
          onTap: () => widget.onTap(widget.episode),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            leading: Opacity(
              opacity: (widget.isWatched && !widget.isCurrent) ? 0.4 : 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  widget.episode.image.isNotEmpty
                      ? widget.episode.image
                      : 'https://placehold.co/120x68/1a1a1a/FFF?text=No+Image',
                  width: 80,
                  height: 45,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    "Odcinek ${widget.episode.number}",
                    style: TextStyle(
                      color: widget.isCurrent ? Colors.white : textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasSub)
                  _buildAudioIcon(
                    Icons.subtitles,
                    (widget.isWatched && !widget.isCurrent)
                        ? Colors.blue[900]!
                        : Colors.blue[400]!,
                  ),
                if (hasDub)
                  _buildAudioIcon(
                    Icons.mic,
                    (widget.isWatched && !widget.isCurrent)
                        ? Colors.deepOrange[900]!
                        : Colors.deepOrange[400]!,
                  ),
              ],
            ),
            subtitle: Text(
              widget.episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isCurrent
                    ? Colors.white
                    : textColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
