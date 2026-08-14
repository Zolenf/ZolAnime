import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerView extends StatelessWidget {
  final VideoController controller;
  final String currentProvider;
  final String currentAudio;
  final List<String> availableAudio;
  final bool autoplayEnabled;
  final bool autoSkipIntro;
  final bool autoSkipOutro;
  final bool subsEnabled; // <--- NOWE

  final ValueChanged<String> onProviderChanged;
  final ValueChanged<String> onAudioChanged;
  final ValueChanged<bool> onAutoplayChanged;
  final ValueChanged<bool> onSkipIntroChanged;
  final ValueChanged<bool> onSkipOutroChanged;
  final VoidCallback onToggleSubs; // <--- NOWE
  final VoidCallback onManualSkipIntro;
  final VoidCallback onManualSkipOutro;

  const VideoPlayerView({
    super.key,
    required this.controller,
    required this.currentProvider,
    required this.currentAudio,
    required this.availableAudio,
    required this.autoplayEnabled,
    required this.autoSkipIntro,
    required this.autoSkipOutro,
    required this.subsEnabled, // <--- NOWE
    required this.onProviderChanged,
    required this.onAudioChanged,
    required this.onAutoplayChanged,
    required this.onSkipIntroChanged,
    required this.onSkipOutroChanged,
    required this.onToggleSubs, // <--- NOWE
    required this.onManualSkipIntro,
    required this.onManualSkipOutro,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        Widget videoWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(controller: controller),
          ),
        );

        if (isDesktop) {
          return Column(
            children: [
              Expanded(child: Center(child: videoWidget)),
              const SizedBox(height: 16),
              _buildDesktopControls(),
            ],
          );
        } else {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              videoWidget,
              const SizedBox(height: 16),
              _buildMobileControls(),
            ],
          );
        }
      },
    );
  }

  Widget _buildDesktopControls() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPrimaryButton(
                    "Auto Intro: ${autoSkipIntro ? 'ON' : 'OFF'}",
                    autoSkipIntro ? Icons.bolt : Icons.bolt_outlined,
                    autoSkipIntro,
                    () => onSkipIntroChanged(!autoSkipIntro),
                  ),
                  _buildPrimaryButton(
                    "Auto Outro: ${autoSkipOutro ? 'ON' : 'OFF'}",
                    autoSkipOutro
                        ? Icons.music_video
                        : Icons.music_video_outlined,
                    autoSkipOutro,
                    () => onSkipOutroChanged(!autoSkipOutro),
                  ),
                  _buildPrimaryButton(
                    "Autoplay: ${autoplayEnabled ? 'ON' : 'OFF'}",
                    autoplayEnabled ? Icons.sync : Icons.sync_disabled,
                    autoplayEnabled,
                    () => onAutoplayChanged(!autoplayEnabled),
                  ),
                  // <--- NOWY PRZYCISK NAPISÓW (DESKTOP)
                  _buildPrimaryButton(
                    "Napisy: ${subsEnabled ? 'ON' : 'OFF'}",
                    subsEnabled ? Icons.subtitles : Icons.subtitles_outlined,
                    subsEnabled,
                    onToggleSubs,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSecondaryButton(
                    "Skip Intro",
                    Icons.fast_forward,
                    onManualSkipIntro,
                  ),
                  _buildSecondaryButton(
                    "Skip Outro",
                    Icons.skip_next,
                    onManualSkipOutro,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(mainAxisSize: MainAxisSize.min, children: _buildDropdowns()),
      ],
    );
  }

  Widget _buildMobileControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPrimaryButton(
                "Auto Intro: ${autoSkipIntro ? 'ON' : 'OFF'}",
                autoSkipIntro ? Icons.bolt : Icons.bolt_outlined,
                autoSkipIntro,
                () => onSkipIntroChanged(!autoSkipIntro),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPrimaryButton(
                "Auto Outro: ${autoSkipOutro ? 'ON' : 'OFF'}",
                autoSkipOutro ? Icons.music_video : Icons.music_video_outlined,
                autoSkipOutro,
                () => onSkipOutroChanged(!autoSkipOutro),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPrimaryButton(
                "Autoplay: ${autoplayEnabled ? 'ON' : 'OFF'}",
                autoplayEnabled ? Icons.sync : Icons.sync_disabled,
                autoplayEnabled,
                () => onAutoplayChanged(!autoplayEnabled),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                "Skip Intro",
                Icons.fast_forward,
                onManualSkipIntro,
              ),
            ),
            const SizedBox(width: 8),
            // <--- NOWY PRZYCISK NAPISÓW W MIEJSCU PUSTEGO SIZEDBOXA (MOBILE)
            Expanded(
              child: _buildPrimaryButton(
                "Napisy: ${subsEnabled ? 'ON' : 'OFF'}",
                subsEnabled ? Icons.subtitles : Icons.subtitles_outlined,
                subsEnabled,
                onToggleSubs,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSecondaryButton(
                "Skip Outro",
                Icons.skip_next,
                onManualSkipOutro,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: _buildDropdowns(),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(
    String text,
    IconData icon,
    bool isOn,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isOn ? Colors.purple[800] : Colors.grey[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.purple),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(text),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDropdowns() {
    return [
      DropdownButton<String>(
        dropdownColor: Colors.grey[900],
        value: currentProvider,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        items:
            ['kiwi', 'bee', 'anineko', 'reanime'] // Dopasuj do swoich dostawców
                .map(
                  (p) =>
                      DropdownMenuItem(value: p, child: Text(p.toUpperCase())),
                )
                .toList(),
        onChanged: (val) {
          if (val != null) onProviderChanged(val);
        },
      ),
      const SizedBox(width: 16),
      DropdownButton<String>(
        dropdownColor: Colors.grey[900],
        value: currentAudio,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        items: availableAudio
            .map(
              (a) => DropdownMenuItem(value: a, child: Text(a.toUpperCase())),
            )
            .toList(),
        onChanged: (val) {
          if (val != null) onAudioChanged(val);
        },
      ),
    ];
  }
}
