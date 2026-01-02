import 'package:aniverse/helper/classes/anime_obj.dart';
import 'package:aniverse/helper/models/anime_model.dart';
import 'package:aniverse/objectbox.g.dart';
import 'package:aniverse/services/internal_db.dart';
import 'package:aniverse/helper/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_meedu_videoplayer/meedu_player.dart';
import 'package:get/get.dart';

class PlayerPage extends StatefulWidget {
  final String url;
  final ColorScheme colorScheme;

  final int animeId;
  final int episodeId;

  final AnimeClass anime;

  const PlayerPage({
    Key? key,
    required this.url,
    required this.colorScheme,
    required this.animeId,
    required this.episodeId,
    required this.anime,
  }) : super(key: key);

  @override
  State<PlayerPage> createState() => PlayerPageState();
}

class PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late MeeduPlayerController _meeduPlayerController;
  late AnimeModel animeModel;

  Box objBox = Get.find<ObjectBox>().store.box<AnimeModel>();
  int index = 0;
  bool firstTime = true;
  bool _retrying = false;
  int _retryCount = 0;
  int _retryTicket = 0;
  static const int _maxRetryCount = 2;
  String? _errorMessage;

  int getSeconds() {
    var currTime = animeModel.episodes[widget.episodeId.toString()];
    if (currTime == null) return 0;
    return currTime[0];
  }

  @override
  void initState() {
    debugPrint("Player page");
    debugPrint("URL: ${widget.url}");

    WidgetsBinding.instance.addObserver(this);

    animeModel = objBox.get(widget.animeId);
    animeModel.decodeStr();

    index = animeModel.lastSeenEpisodeIndex!;

    _meeduPlayerController = MeeduPlayerController(
      colorTheme: widget.colorScheme.primary,
      pipEnabled: true,
      showLogs: true,
      loadingWidget: CircularProgressIndicator(
        color: widget.colorScheme.primary,
      ),
      screenManager: const ScreenManager(
        forceLandScapeInFullscreen: true,
        orientations: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      ),
      enabledButtons: const EnabledButtons(
        fullscreen: false,
        muteAndSound: false,
        pip: true,
        playPauseAndRepeat: true,
        playBackSpeed: false,
        videoFit: true,
        rewindAndfastForward: false,
      ),
      controlsStyle: ControlsStyle.primary,
      customIcons: const CustomIcons(
        pip: Icon(Icons.picture_in_picture_alt),
        videoFit: Icon(Icons.fit_screen),
        play: Icon(Icons.play_arrow, size: 50),
        pause: Icon(Icons.pause, size: 50),
      ),
      header: Align(
        alignment: Alignment.topLeft,
        child: BackButton(
          color: widget.colorScheme.primary,
          onPressed: () {
            WidgetsBinding.instance.removeObserver(this);
            Get.back();
          },
        ),
      ),
    );

    _meeduPlayerController.setDataSource(
      DataSource(
        type: DataSourceType.network,
        source: widget.url,
        httpHeaders: _buildStreamHeaders(),
      ),
      autoplay: true,
      seekTo: Duration(seconds: getSeconds()),
    );

    _meeduPlayerController.onDataStatusChanged.listen((event) {
      if (event == DataStatus.loaded) {
        _retryCount = 0;
        _retrying = false;
        if (_errorMessage != null && mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
        _meeduPlayerController.setFullScreen(true, context);
      }
      if (event == DataStatus.error) {
        if (mounted) {
          setState(() {
            _errorMessage = _retryCount < _maxRetryCount
                ? "Server non disponibile, riprovo..."
                : "Server momentaneamente non disponibile. Riprova tra qualche secondo.";
          });
        }
        _refreshStreamUrlOnce();
      }
    });

    _meeduPlayerController.onFullscreenChanged.listen((event) {
      if (event == false) {
        Get.back();
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });

    trackTime();

    super.initState();
  }

  Future<void> _refreshStreamUrlOnce() async {
    if (_retrying || !mounted || _retryCount >= _maxRetryCount) {
      return;
    }
    _retrying = true;
    _retryCount += 1;
    final ticket = ++_retryTicket;
    final delaySeconds = _retryCount;
    try {
      await Future.delayed(Duration(seconds: delaySeconds));
      if (!mounted || ticket != _retryTicket) {
        return;
      }
      final position = _meeduPlayerController.position.value;
      final freshUrl = await fetchEpisodeStreamUrl(widget.episodeId);
      if (!mounted || ticket != _retryTicket) {
        return;
      }
      _meeduPlayerController.setDataSource(
        DataSource(
          type: DataSourceType.network,
          source: freshUrl,
          httpHeaders: _buildStreamHeaders(),
        ),
        autoplay: true,
        seekTo: position,
      );
    } catch (_) {
      if (mounted && _retryCount >= _maxRetryCount) {
        setState(() {
          _errorMessage =
              "Server momentaneamente non disponibile. Riprova tra qualche secondo.";
        });
      }
    } finally {
      _retrying = false;
    }
  }

  Map<String, String> _buildStreamHeaders() {
    return const {
      "User-Agent":
          "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
      "Referer": "https://www.animeunity.so/",
      "Origin": "https://www.animeunity.so",
    };
  }

  @override
  void dispose() {
    _meeduPlayerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && firstTime) {
      firstTime = false;
      return;
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // _meeduPlayerController.enterPip(context);
    }
  }

  void trackTime() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    var current = _meeduPlayerController.position.value;
    var duration = _meeduPlayerController.duration.value;
    // update the lastMinutage of the episode
    animeModel.episodes[widget.episodeId.toString()] = [current.inSeconds, duration.inSeconds];
    animeModel.episodes['_lastEpisodeId'] = widget.episodeId;

    int remaining = duration.inSeconds - current.inSeconds;
    if (remaining < 120 && remaining != -1 && duration.inSeconds > 0) {
      animeModel.lastSeenEpisodeIndex = (index + 1) % widget.anime.episodes.length;
    }

    animeModel.encodeStr();
    objBox.put(animeModel);

    debugPrint("Current: ${current.inSeconds.toString()}");

    trackTime();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          Positioned.fill(
            child: MeeduVideoPlayer(
              controller: _meeduPlayerController,
            ),
          ),
          if (_errorMessage != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.colorScheme.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

