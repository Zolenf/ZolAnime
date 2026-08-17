import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:zolanime/api/client.dart';
import '../models/episodes.dart';
import '../models/stream_data.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class Wideopage extends StatefulWidget {
  final int animeId;
  final String animeTitle;
  const Wideopage({super.key, required this.animeId, required this.animeTitle});

  @override
  State<Wideopage> createState() => _WideopageState();
}

class _WideopageState extends State<Wideopage> {
  late final Player _player;
  late final VideoController _controller;
  late final Future<AnimeEpisodes> _episodesFuture;
  List<VideoStream> _availableSubServers = [];
  VideoStream? _selectedSubServer;
  String? _savedSubServerName;

  String _selectedProvider = 'anikoto';
  String _selectedAudio = 'dub';
  dynamic _currentEpisode;
  AnimeEpisodes? _animeData;
  List<dynamic> _cachedEpisodesList = [];

  int? _watchedEpisodes;
  String _savedNotes = "";
  final Set<int> _savedEpisodesSession = {};

  String? _subUrl;
  bool _subsOn = false;

  bool _autoplayEnabled = true;
  bool _autoSkipIntroEnabled = true;
  bool _autoSkipOutroEnabled = true;

  double? _introStart, _introEnd;
  double? _outroStart, _outroEnd;
  bool _introSkipped = false;
  bool _outroSkipped = false;

  bool _showSkipIntroButton = false;
  bool _showSkipOutroButton = false;

  bool _isVideoSafeToSave = false;
  bool _hasSeekedToSavedTime = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(bufferSize: 1024 * 1024 * 15),
    );
    _setupPlayer();
    _setupListeners();
    _episodesFuture = fetchAnimeEpisodes(widget.animeId);
    _controller = VideoController(_player);
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadSettings();
    await _initProgress();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoplayEnabled = prefs.getBool('autoplay') ?? true;
      _autoSkipIntroEnabled = prefs.getBool('skip_intro') ?? true;
      _autoSkipOutroEnabled = prefs.getBool('skip_outro') ?? true;
      _subsOn = prefs.getBool('subs_on') ?? false;
      _selectedProvider = prefs.getString('provider') ?? 'anikoto';
      _selectedAudio = prefs.getString('audio') ?? 'dub';
      _savedSubServerName = prefs.getString('subserver');
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _initProgress() async {
    final fetchedData = await fetchUserProgress(widget.animeId);

    if (!mounted) return;

    setState(() {
      _watchedEpisodes = fetchedData.progress;
      _savedNotes = fetchedData.notes;
    });

    _autoLoadFirstUnwatched();
  }

  void _autoLoadFirstUnwatched() {
    if (_animeData == null ||
        _watchedEpisodes == null ||
        _currentEpisode != null ||
        _cachedEpisodesList.isEmpty)
      return;

    dynamic episodeToLoad;
    try {
      episodeToLoad = _cachedEpisodesList.firstWhere(
        (ep) => ep.number > _watchedEpisodes!,
      );
    } catch (e) {
      episodeToLoad = _cachedEpisodesList.last;
    }
    setState(() => _currentEpisode = episodeToLoad);
    _loadVideoForEpisode(episodeToLoad);
  }

  Future<void> _setupPlayer() async {
    if (_player.platform is NativePlayer) {
      await (_player.platform as dynamic).setProperty(
        'demuxer-max-bytes',
        '500000000',
      );
      await (_player.platform as dynamic).setProperty(
        'demuxer-max-back-bytes',
        '250000000',
      );
      await (_player.platform as dynamic).setProperty('log-level', 'debug');
      await (_player.platform as dynamic).setProperty('sub-fix-timing', 'yes');
      await (_player.platform as dynamic).setProperty(
        'sub-clear-on-seek',
        'yes',
      );
    }
  }

  void _setupListeners() {
    _player.stream.completed.listen((completed) {
      if (completed && _autoplayEnabled) _handleNextEpisode();
    });

    _player.stream.playing.listen((isPlaying) {
      if (!isPlaying && _isVideoSafeToSave) {
        _saveCurrentTime();
      }
    });

    _player.stream.position.listen((position) {
      final double currentSecs = position.inMilliseconds / 1000.0;
      final int totalSecs = _player.state.duration.inSeconds;

      if (totalSecs == 0 || currentSecs < 1.0) return;

      if (!_hasSeekedToSavedTime && _currentEpisode != null) {
        _hasSeekedToSavedTime = true;
        if (_savedNotes.isNotEmpty) {
          final match = RegExp(r'ep:(\d+),time:(\d+)').firstMatch(_savedNotes);

          if (match != null) {
            final savedEpNum = int.tryParse(match.group(1)!);
            final secs = int.tryParse(match.group(2)!) ?? 0;

            if (savedEpNum == _currentEpisode.number) {
              if (secs > 2) {
                _player.seek(Duration(seconds: secs));
                return;
              }
            }
          }
        }
      }

      _isVideoSafeToSave = true;

      final duration = _player.state.duration.inSeconds;
      final limit = duration > 180 ? duration - 30 : 1080;

      if (_isVideoSafeToSave &&
          currentSecs >= limit &&
          _currentEpisode != null &&
          _watchedEpisodes != null) {
        final currentEpNum = _currentEpisode.number;

        if (!_savedEpisodesSession.contains(currentEpNum) &&
            currentEpNum > _watchedEpisodes!) {
          _savedEpisodesSession.add(currentEpNum);
          saveProgress(widget.animeId, currentEpNum, "");

          setState(() {
            _watchedEpisodes = currentEpNum;
            _savedNotes = "";
          });
        }
      }

      if (_autoSkipIntroEnabled &&
          !_introSkipped &&
          _introStart != null &&
          _introEnd != null) {
        if (currentSecs >= _introStart! && currentSecs < _introEnd!) {
          _introSkipped = true;
          _player.seek(Duration(milliseconds: (_introEnd! * 1000).toInt()));
          return;
        }
      }

      if (_autoSkipOutroEnabled &&
          !_outroSkipped &&
          _outroStart != null &&
          _outroEnd != null) {
        if (currentSecs >= _outroStart! && currentSecs < _outroEnd!) {
          _outroSkipped = true;
          _player.seek(Duration(milliseconds: (_outroEnd! * 1000).toInt()));
        }
      }

      final inIntro =
          _introStart != null &&
          currentSecs >= _introStart! &&
          currentSecs < _introEnd!;
      final inOutro =
          _outroStart != null &&
          currentSecs >= _outroStart! &&
          currentSecs < _outroEnd!;

      if (_showSkipIntroButton != inIntro || _showSkipOutroButton != inOutro) {
        setState(() {
          _showSkipIntroButton = inIntro;
          _showSkipOutroButton = inOutro;
        });
      }
    });
  }

  Future<void> _saveCurrentTime() async {
    if (_currentEpisode == null || _watchedEpisodes == null) return;

    final epNum = _currentEpisode.number;
    final secs = _player.state.position.inSeconds;

    if (secs >= 1080) return;

    if (secs > 5) {
      final note = "ep:$epNum,time:$secs";
      if (_savedNotes != note) {
        await saveProgress(widget.animeId, _watchedEpisodes!, note);
        _savedNotes = note;
      }
    }
  }

  Future<void> _exitPage() async {
    await _saveCurrentTime();
    if (mounted) {
      setState(() => _canPop = true);
      Navigator.pop(context, true);
    }
  }

  void _changeSubServerAndPlay(VideoStream server) {
    if (server.introStart != null && server.introEnd != null) {
      _introStart = server.introStart;
      _introEnd = server.introEnd;
    }
    if (server.outroStart != null && server.outroEnd != null) {
      _outroStart = server.outroStart;
      _outroEnd = server.outroEnd;
    }

    String finalReferer = server.url.contains('kwik')
        ? 'https://kwik.cx/'
        : (server.referer ?? 'https://anineko.to/');

    _player.open(
      Media(
        server.url,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64) Chrome/120.0.0',
          'Referer': finalReferer,
        },
      ),
    );
  }

  Future<void> _loadVideoForEpisode(dynamic episode) async {
    if (episode == null) return;

    _introSkipped = false;
    _outroSkipped = false;
    _introStart = null;
    _introEnd = null;
    _outroStart = null;
    _outroEnd = null;
    _hasSeekedToSavedTime = false;
    _isVideoSafeToSave = false;

    setState(() {
      _showSkipIntroButton = false;
      _showSkipOutroButton = false;
    });

    if (_animeData != null) {
      final localSkips = _animeData!.skipTimes
          .where((s) => s.episode == episode.number)
          .toList();

      if (localSkips.isNotEmpty) {
        for (var skip in localSkips) {
          if (skip.type == 'op') {
            _introStart = skip.start;
            _introEnd = skip.end;
          } else if (skip.type == 'ed') {
            _outroStart = skip.start;
            _outroEnd = skip.end;
          }
        }
      } else if (_animeData!.malId != null) {
        final externalSkips = await fetchAniSkip(
          _animeData!.malId!,
          episode.number,
        );

        for (var skip in externalSkips) {
          if (skip.type == 'op') {
            _introStart = skip.start;
            _introEnd = skip.end;
          } else if (skip.type == 'ed') {
            _outroStart = skip.start;
            _outroEnd = skip.end;
          }
        }
      }
    }

    final String? streamPath =
        episode.sources[_selectedProvider]?[_selectedAudio]?.id;
    if (streamPath == null) return;

    try {
      final streamData = await fetchStreamDetails(streamPath);
      final valid = streamData.streams
          .where((s) => s.type == 'hls' || s.type == 'mp4')
          .toList();

      valid.sort(
        (a, b) =>
            (int.tryParse(b.quality?.replaceAll(RegExp(r'\D'), '') ?? '0') ?? 0)
                .compareTo(
                  int.tryParse(
                        a.quality?.replaceAll(RegExp(r'\D'), '') ?? '0',
                      ) ??
                      0,
                ),
      );

      if (valid.isEmpty || !mounted) return;

      setState(() {
        _availableSubServers = valid;

        Iterable<VideoStream> match;
        if (_selectedSubServer != null) {
          match = valid.where((s) => s.server == _selectedSubServer?.server);
        } else if (_savedSubServerName != null) {
          match = valid.where((s) => s.server == _savedSubServerName);
        } else {
          match = [];
        }

        _selectedSubServer = match.isNotEmpty
            ? match.first
            : (streamData.bestHls ?? valid.first);

        _savedSubServerName = _selectedSubServer!.server;
        _saveSetting('subserver', _savedSubServerName);
      });

      var streamToPlay = _selectedSubServer!;

      if (streamToPlay.introStart != null && streamToPlay.introEnd != null) {
        _introStart = streamToPlay.introStart;
        _introEnd = streamToPlay.introEnd;
      }
      if (streamToPlay.outroStart != null && streamToPlay.outroEnd != null) {
        _outroStart = streamToPlay.outroStart;
        _outroEnd = streamToPlay.outroEnd;
      }

      String finalReferer = streamToPlay.url.contains('kwik')
          ? 'https://kwik.cx/'
          : (streamToPlay.referer ?? 'https://anineko.to/');

      _player.open(
        Media(
          streamToPlay.url,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64) Chrome/120.0.0',
            'Referer': finalReferer,
          },
        ),
      );

      _subUrl = streamData.subtitleUrl;

      if (_subUrl != null) {
        if (_subsOn) {
          Future.microtask(() async {
            try {
              final subRes = await http
                  .get(
                    Uri.parse(_subUrl!),
                    headers: {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      'Referer': finalReferer,
                    },
                  )
                  .timeout(const Duration(seconds: 4));

              if (subRes.statusCode == 200) {
                final fixedVtt = subRes.body.replaceAll(
                  RegExp(r'(\r?\n){2,}(?!\d{2}:\d{2})'),
                  '\n',
                );
                await Future.delayed(const Duration(milliseconds: 100));
                _player.setSubtitleTrack(SubtitleTrack.data(fixedVtt));
              }
            } catch (e) {}
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Błąd serwera: Nie można pobrać wideo."),
          ),
        );
      }
    }
  }

  void _handleNextEpisode() async {
    if (_currentEpisode == null || _cachedEpisodesList.isEmpty) return;
    final currentIndex = _cachedEpisodesList.indexWhere(
      (ep) => ep.number == _currentEpisode.number,
    );
    if (currentIndex != -1 && currentIndex < _cachedEpisodesList.length - 1) {
      await _saveCurrentTime();
      final nextEpisode = _cachedEpisodesList[currentIndex + 1];
      setState(() => _currentEpisode = nextEpisode);
      _loadVideoForEpisode(nextEpisode);
    }
  }

  List<String> _getAvailableProviders() {
    if (_currentEpisode == null) {
      if (_animeData != null && _animeData!.episodes.isNotEmpty) {
        return _animeData!.episodes.values.first.sources.keys.toList();
      }
      return ['anikoto', 'anineko'];
    }
    return _currentEpisode.sources.keys.toList();
  }

  List<String> _getAvailableAudioForCurrent() {
    if (_currentEpisode == null) return ['sub', 'dub'];
    final pD = _currentEpisode.sources[_selectedProvider];
    if (pD == null) return ['sub'];
    List<String> a = [];
    if (pD['sub'] != null) a.add('sub');
    if (pD['dub'] != null) a.add('dub');
    return a.isEmpty ? ['sub'] : a;
  }

  void _manualSkip(bool intro) {
    if (intro) {
      if (_introEnd != null)
        _player.seek(Duration(milliseconds: (_introEnd! * 1000).toInt()));
      else
        _player.seek(_player.state.position + const Duration(seconds: 85));
    } else {
      if (_outroEnd != null)
        _player.seek(Duration(milliseconds: (_outroEnd! * 1000).toInt()));
      else {
        final d = _player.state.duration;
        if (d > const Duration(seconds: 95))
          _player.seek(d - const Duration(seconds: 5));
      }
    }
  }

  void _toggleSubs() {
    setState(() => _subsOn = !_subsOn);
    _saveSetting('subs_on', _subsOn);
    if (!_subsOn) {
      _player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      if (_subUrl != null && _currentEpisode != null) {
        _loadVideoForEpisode(_currentEpisode);
      }
    }
  }

  void _openDebugConsole(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Konsola Debugowania",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white30),
              Expanded(
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: appLogs,
                  builder: (context, logs, child) {
                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: SelectableText(
                            logs[index],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableProviders = _getAvailableProviders();
    if (!availableProviders.contains(_selectedProvider) &&
        availableProviders.isNotEmpty) {
      _selectedProvider = availableProviders.first;
    }

    final availableAudio = _getAvailableAudioForCurrent();
    if (!availableAudio.contains(_selectedAudio) && availableAudio.isNotEmpty) {
      _selectedAudio = availableAudio.first;
    }

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _exitPage();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: IconButton(
            onPressed: _exitPage,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.animeTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.terminal, color: Colors.greenAccent),
              tooltip: "Otwórz logi",
              onPressed: () => _openDebugConsole(context),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
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
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withAlpha(120)),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;

                final leftSide = Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _buildLeftSide(
                    controller: _controller,
                    currentProvider: _selectedProvider,
                    currentAudio: _selectedAudio,
                    availableProviders: availableProviders,
                    availableAudio: availableAudio,
                    availableSubServers: _availableSubServers,
                    currentSubServer: _selectedSubServer,
                    autoplayEnabled: _autoplayEnabled,
                    autoSkipIntro: _autoSkipIntroEnabled,
                    autoSkipOutro: _autoSkipOutroEnabled,
                    showSkipIntroButton: _showSkipIntroButton,
                    showSkipOutroButton: _showSkipOutroButton,
                    subsEnabled: _subsOn,
                    onToggleSubs: _toggleSubs,
                    onProviderChanged: (p) {
                      setState(() => _selectedProvider = p);
                      _saveSetting('provider', p);
                      _loadVideoForEpisode(_currentEpisode);
                    },
                    onSubServerChanged: (server) {
                      setState(() => _selectedSubServer = server);
                      _saveSetting('subserver', server.server);
                      _changeSubServerAndPlay(server);
                    },
                    onAudioChanged: (a) {
                      setState(() => _selectedAudio = a);
                      _saveSetting('audio', a);
                      _loadVideoForEpisode(_currentEpisode);
                    },
                    onAutoplayChanged: (v) {
                      setState(() => _autoplayEnabled = v);
                      _saveSetting('autoplay', v);
                    },
                    onSkipIntroChanged: (v) {
                      setState(() => _autoSkipIntroEnabled = v);
                      _saveSetting('skip_intro', v);
                    },
                    onSkipOutroChanged: (v) {
                      setState(() => _autoSkipOutroEnabled = v);
                      _saveSetting('skip_outro', v);
                    },
                    onManualSkipIntro: () => _manualSkip(true),
                    onManualSkipOutro: () => _manualSkip(false),
                  ),
                );

                final rightSide = _buildRightSide(
                  episodesFuture: _episodesFuture,
                  selectedProvider: _selectedProvider,
                  currentEpisode: _currentEpisode,
                  watchedEpisodes: _watchedEpisodes ?? 0,
                  onDataLoaded: (data) {
                    _animeData = data;
                    _cachedEpisodesList = data.episodes.values.toList()
                      ..sort((a, b) => a.number.compareTo(b.number));
                    _autoLoadFirstUnwatched();
                  },
                  onEpisodeSelected: (ep) async {
                    await _saveCurrentTime();
                    setState(() => _currentEpisode = ep);
                    _loadVideoForEpisode(ep);
                  },
                );

                return isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: leftSide),
                          Expanded(flex: 3, child: rightSide),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(flex: 3, child: leftSide),
                          Expanded(flex: 2, child: rightSide),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _buildLeftSide extends StatelessWidget {
  final VideoController controller;
  final String currentProvider;
  final String currentAudio;
  final List<String> availableProviders;
  final List<String> availableAudio;
  final List<VideoStream> availableSubServers;
  final VideoStream? currentSubServer;
  final bool autoplayEnabled;
  final bool autoSkipIntro;
  final bool autoSkipOutro;
  final bool showSkipIntroButton;
  final bool showSkipOutroButton;
  final bool subsEnabled;
  final VoidCallback onToggleSubs;

  final ValueChanged<String> onProviderChanged;
  final ValueChanged<VideoStream> onSubServerChanged;
  final ValueChanged<String> onAudioChanged;
  final ValueChanged<bool> onAutoplayChanged;
  final ValueChanged<bool> onSkipIntroChanged;
  final ValueChanged<bool> onSkipOutroChanged;
  final VoidCallback onManualSkipIntro;
  final VoidCallback onManualSkipOutro;

  const _buildLeftSide({
    required this.controller,
    required this.currentProvider,
    required this.currentAudio,
    required this.availableProviders,
    required this.availableAudio,
    required this.availableSubServers,
    required this.currentSubServer,
    required this.autoplayEnabled,
    required this.autoSkipIntro,
    required this.autoSkipOutro,
    required this.showSkipIntroButton,
    required this.showSkipOutroButton,
    required this.onProviderChanged,
    required this.onSubServerChanged,
    required this.onAudioChanged,
    required this.onAutoplayChanged,
    required this.onSkipIntroChanged,
    required this.onSkipOutroChanged,
    required this.onManualSkipIntro,
    required this.onManualSkipOutro,
    required this.subsEnabled,
    required this.onToggleSubs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Video(
                    controller: controller,
                    subtitleViewConfiguration: const SubtitleViewConfiguration(
                      style: TextStyle(
                        backgroundColor: Colors.black54,
                        fontSize: 50,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (showSkipIntroButton || showSkipOutroButton)
                  Positioned(
                    right: 32,
                    bottom: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: showSkipIntroButton
                                ? onManualSkipIntro
                                : onManualSkipOutro,
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.15),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fast_forward,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    showSkipIntroButton
                                        ? "Pomiń Intro"
                                        : "Pomiń Outro",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: autoSkipIntro
                    ? Colors.purple[800]
                    : Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () => onSkipIntroChanged(!autoSkipIntro),
              icon: Icon(
                autoSkipIntro ? Icons.bolt : Icons.bolt_outlined,
                size: 16,
              ),
              label: Text("Auto Intro: ${autoSkipIntro ? 'ON' : 'OFF'}"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: autoSkipOutro
                    ? Colors.purple[800]
                    : Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () => onSkipOutroChanged(!autoSkipOutro),
              icon: Icon(
                autoSkipOutro ? Icons.music_video : Icons.music_video_outlined,
                size: 16,
              ),
              label: Text("Auto Outro: ${autoSkipOutro ? 'ON' : 'OFF'}"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: autoplayEnabled
                    ? Colors.purple[800]
                    : Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () => onAutoplayChanged(!autoplayEnabled),
              icon: Icon(
                autoplayEnabled ? Icons.sync : Icons.sync_disabled,
                size: 16,
              ),
              label: Text("Autoplay: ${autoplayEnabled ? 'ON' : 'OFF'}"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: subsEnabled
                    ? Colors.purple[800]
                    : Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              onPressed: onToggleSubs,
              icon: Icon(
                subsEnabled ? Icons.subtitles : Icons.subtitles_off,
                size: 16,
              ),
              label: Text("Napisy: ${subsEnabled ? 'ON' : 'OFF'}"),
            ),
            DropdownButton<String>(
              dropdownColor: Colors.grey[900],
              value: currentProvider,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              items: availableProviders
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) onProviderChanged(val);
              },
            ),
            if (availableSubServers.isNotEmpty)
              DropdownButton<VideoStream>(
                dropdownColor: Colors.grey[900],
                value: currentSubServer,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                items: availableSubServers.map((serverData) {
                  return DropdownMenuItem<VideoStream>(
                    value: serverData,
                    child: Text(serverData.server.toUpperCase()),
                  );
                }).toList(),
                onChanged: (VideoStream? newServer) {
                  if (newServer != null) {
                    onSubServerChanged(newServer);
                  }
                },
              ),
            DropdownButton<String>(
              dropdownColor: Colors.grey[900],
              value: currentAudio,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              items: availableAudio
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) onAudioChanged(val);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _buildRightSide extends StatelessWidget {
  final Future<AnimeEpisodes> episodesFuture;
  final String selectedProvider;
  final dynamic currentEpisode;
  final int watchedEpisodes;
  final ValueChanged<AnimeEpisodes> onDataLoaded;
  final Function(dynamic ep) onEpisodeSelected;

  const _buildRightSide({
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
