import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/helper/classes/streamingcommunity_utils.dart';
import 'package:aniverse/helper/streamingcommunity_api.dart';
import 'package:aniverse/helper/models/media_model.dart';
import 'package:aniverse/objectbox.g.dart';
import 'package:aniverse/services/internal_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_meedu_videoplayer/meedu_player.dart';
import 'package:get/get.dart';

class ScPlayerPage extends StatefulWidget {
  final ScMedia media;
  final int? episodeId;
  final int? episodeNumber;
  final String streamUrl;
  final String iframeUrl;
  final String referer;

  const ScPlayerPage({
    super.key,
    required this.media,
    required this.streamUrl,
    required this.iframeUrl,
    required this.referer,
    this.episodeId,
    this.episodeNumber,
  });

  @override
  State<ScPlayerPage> createState() => _ScPlayerPageState();
}

class _ScPlayerPageState extends State<ScPlayerPage>
    with WidgetsBindingObserver {
  late MeeduPlayerController _controller;
  late MediaModel mediaModel;
  final Box<MediaModel> _box =
      Get.find<ObjectBox>().store.box<MediaModel>();

  bool _retrying = false;
  int _retryCount = 0;
  int _retryTicket = 0;
  static const int _maxRetryCount = 2;
  String? _errorMessage;

  String _progressKey() {
    if (widget.episodeId != null) {
      return widget.episodeId.toString();
    }
    return widget.media.id.toString();
  }

  int _getSeconds() {
    final value = mediaModel.episodes[_progressKey()];
    if (value == null) {
      return 0;
    }
    if (value is List && value.isNotEmpty && value.first is int) {
      return value.first as int;
    }
    return 0;
  }

  Map<String, String> _buildStreamHeaders() {
    final origin = Uri.parse(widget.iframeUrl).origin;
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36',
      'Referer': widget.iframeUrl,
      'Origin': origin,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    mediaModel = fetchMediaModel(
      widget.media,
      imageUrl: buildScImageUrl(
        images: widget.media.images,
        cdnUrl: '',
      ),
    );

    _controller = MeeduPlayerController(
      colorTheme: Theme.of(context).colorScheme.primary,
      pipEnabled: true,
      showLogs: true,
      loadingWidget: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
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
          color: Theme.of(context).colorScheme.primary,
          onPressed: () {
            WidgetsBinding.instance.removeObserver(this);
            Get.back();
          },
        ),
      ),
    );

    _controller.setDataSource(
      DataSource(
        type: DataSourceType.network,
        source: widget.streamUrl,
        httpHeaders: _buildStreamHeaders(),
      ),
      autoplay: true,
      seekTo: Duration(seconds: _getSeconds()),
    );

    _controller.onDataStatusChanged.listen((event) {
      if (event == DataStatus.loaded) {
        _retryCount = 0;
        _retrying = false;
        if (_errorMessage != null && mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
        _controller.setFullScreen(true, context);
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

    _controller.onFullscreenChanged.listen((event) {
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

    _trackTime();
  }

  Future<void> _refreshStreamUrlOnce() async {
    if (_retrying || !mounted || _retryCount >= _maxRetryCount) {
      return;
    }
    _retrying = true;
    _retryCount += 1;
    final ticket = ++_retryTicket;
    try {
      await Future.delayed(Duration(seconds: _retryCount));
      if (!mounted || ticket != _retryTicket) {
        return;
      }
      final position = _controller.position.value;
      final freshUrl = await resolveStreamingCommunityStreamUrl(
        iframeUrl: widget.iframeUrl,
        referer: widget.referer,
      );
      if (!mounted || ticket != _retryTicket) {
        return;
      }
      _controller.setDataSource(
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

  void _trackTime() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) {
      return;
    }
    final current = _controller.position.value;
    final duration = _controller.duration.value;
    final key = _progressKey();
    mediaModel.episodes[key] = [current.inSeconds, duration.inSeconds];
    mediaModel.episodes['_lastEpisodeId'] = key;
    if (widget.episodeNumber != null) {
      mediaModel.lastSeenEpisodeIndex = widget.episodeNumber! - 1;
    }
    mediaModel.lastSeenDate = DateTime.now();
    mediaModel.encodeStr();
    _box.put(mediaModel);
    _trackTime();
  }

  @override
  void dispose() {
    _controller.dispose();
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
  Widget build(BuildContext context) {
    final playerBody = Material(
      child: Stack(
        children: [
          Positioned.fill(
            child: MeeduVideoPlayer(
              controller: _controller,
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
                      color: Theme.of(context).colorScheme.onBackground,
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

    return playerBody;
  }
}
