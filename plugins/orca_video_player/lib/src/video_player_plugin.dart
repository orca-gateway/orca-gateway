import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:orca_gateway/orca_gateway.dart';
import 'package:video_player/video_player.dart';

/// Orca Gateway plugin for video playback.
///
/// ## Widget: `VideoPlayer`
///
/// Props:
/// - `url` (String) — video URL to play
/// - `autoPlay` (bool) — start playing immediately (default false)
/// - `looping` (bool) — loop video (default false)
/// - `showControls` (bool) — show play/pause overlay (default true)
/// - `aspectRatio` (double) — aspect ratio (default from video metadata)
/// - `playerId` (String) — unique ID to address this player from actions
///
/// ## Triggers:
/// - `onPlay` — fires when playback starts
/// - `onPause` — fires when playback pauses
/// - `onComplete` — fires when video reaches the end
/// - `onProgress` — fires with `{position, duration, fraction}` during playback
/// - `onError` — fires with `{message}` on playback error
///
/// ## Actions:
/// - `playVideo` — starts playback (`playerId`)
/// - `pauseVideo` — pauses playback (`playerId`)
/// - `seekVideo` — seeks to position in ms (`playerId`, `position`)
/// - `setVolume` — sets volume 0.0–1.0 (`playerId`, `volume`)
/// - `setPlaybackSpeed` — sets speed (`playerId`, `speed`)
class VideoPlayerPlugin extends OrcaPlugin {
  VideoPlayerPlugin()
      : super(
          name: 'VideoPlayerPlugin',
          widgets: {
            'VideoPlayer': _buildVideoPlayer,
          },
          actions: {
            'playVideo': _handlePlay,
            'pauseVideo': _handlePause,
            'seekVideo': _handleSeek,
            'setVolume': _handleSetVolume,
            'setPlaybackSpeed': _handleSetSpeed,
          },
          triggers: {
            'VideoPlayer': [
              const TriggerDefinition(
                name: 'onPlay',
                description: 'Fires when playback starts',
              ),
              const TriggerDefinition(
                name: 'onPause',
                description: 'Fires when playback pauses',
              ),
              const TriggerDefinition(
                name: 'onComplete',
                description: 'Fires when video reaches the end',
              ),
              const TriggerDefinition(
                name: 'onProgress',
                dataType: 'VideoProgress',
                description: 'Fires with {position, duration, fraction} during playback',
              ),
              const TriggerDefinition(
                name: 'onError',
                dataType: 'String',
                description: 'Fires with {message} on playback error',
              ),
            ],
          },
          // Epic 38.1/38.2: the native video surface doesn't preview on web.
          widgetMetadata: {
            'VideoPlayer': WidgetWebMetadata(
              isSupportedOnWeb: false,
              displayName: 'Video Player',
              iconName: 'video',
            ),
          },
          // Epic 38.5: branded web stub in place of the platform view.
          webStubs: {
            'VideoPlayer': _buildVideoPlayerWebStub,
          },
        );

  /// Active controllers keyed by playerId for action targeting.
  static final Map<String, VideoPlayerController> _controllers = {};
}

/// Web stub for `VideoPlayer` (Epic 38.5).
Widget _buildVideoPlayerWebStub(OrcaComponentContext ctx) {
  return const OrcaWebStub(label: 'Video Player', icon: Icons.play_circle_outline);
}

Widget _buildVideoPlayer(OrcaComponentContext ctx) {
  final url = ctx.prop<String>('url') ?? '';
  final autoPlay = ctx.propOr<bool>('autoPlay', false);
  final looping = ctx.propOr<bool>('looping', false);
  final showControls = ctx.propOr<bool>('showControls', true);
  final aspectRatio = (ctx.prop<num>('aspectRatio'))?.toDouble();
  final playerId = ctx.prop<String>('playerId') ?? ctx.node.id;

  return _OrcaVideoPlayer(
    key: ValueKey('video_player_$playerId'),
    url: url,
    autoPlay: autoPlay,
    looping: looping,
    showControls: showControls,
    aspectRatio: aspectRatio,
    playerId: playerId,
    context: ctx,
  );
}

class _OrcaVideoPlayer extends StatefulWidget {
  final String url;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final double? aspectRatio;
  final String playerId;
  final OrcaComponentContext context;

  const _OrcaVideoPlayer({
    super.key,
    required this.url,
    required this.autoPlay,
    required this.looping,
    required this.showControls,
    this.aspectRatio,
    required this.playerId,
    required this.context,
  });

  @override
  State<_OrcaVideoPlayer> createState() => _OrcaVideoPlayerState();
}

class _OrcaVideoPlayerState extends State<_OrcaVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(widget.looping);

    _controller.addListener(_onControllerUpdate);

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      VideoPlayerPlugin._controllers[widget.playerId] = _controller;
      if (widget.autoPlay) {
        _controller.play();
      }
    }).catchError((error) {
      if (!mounted) return;
      setState(() => _hasError = true);
      widget.context.fireAction('onError', eventData: {
        'message': error.toString(),
      });
    });
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final value = _controller.value;

    // Progress events
    if (value.isPlaying && value.duration.inMilliseconds > 0) {
      widget.context.fireAction('onProgress', eventData: {
        'position': value.position.inMilliseconds,
        'duration': value.duration.inMilliseconds,
        'fraction': value.position.inMilliseconds / value.duration.inMilliseconds,
      });
    }

    // Completion detection
    if (value.position >= value.duration &&
        value.duration.inMilliseconds > 0 &&
        !_completed) {
      _completed = true;
      widget.context.fireAction('onComplete');
    } else if (value.position < value.duration) {
      _completed = false;
    }
  }

  @override
  void didUpdateWidget(_OrcaVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.removeListener(_onControllerUpdate);
      _controller.dispose();
      VideoPlayerPlugin._controllers.remove(oldWidget.playerId);
      _initialized = false;
      _hasError = false;
      _completed = false;
      _initController();
    }
  }

  @override
  void dispose() {
    VideoPlayerPlugin._controllers.remove(widget.playerId);
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      widget.context.fireAction('onPause');
    } else {
      _controller.play();
      widget.context.fireAction('onPlay');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Text('Video failed to load', style: TextStyle(fontSize: 14)),
      );
    }

    if (!_initialized) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x33000000),
            ),
          ),
        ),
      );
    }

    final video = AspectRatio(
      aspectRatio: widget.aspectRatio ?? _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );

    if (!widget.showControls) return video;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          video,
          if (!_controller.value.isPlaying)
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0x99000000),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    '\u25B6',
                    style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 24),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Action Handlers ──────────────────────────────────────

Future<void> _handlePlay(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final playerId = executor.resolveString(action['playerId'] ?? '');
  final controller = VideoPlayerPlugin._controllers[playerId];
  if (controller == null) return;
  await controller.play();
}

Future<void> _handlePause(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final playerId = executor.resolveString(action['playerId'] ?? '');
  final controller = VideoPlayerPlugin._controllers[playerId];
  if (controller == null) return;
  await controller.pause();
}

Future<void> _handleSeek(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final playerId = executor.resolveString(action['playerId'] ?? '');
  final positionMs = (executor.resolveValue(action['position']) as num?)?.toInt();
  final controller = VideoPlayerPlugin._controllers[playerId];
  if (controller == null || positionMs == null) return;
  await controller.seekTo(Duration(milliseconds: positionMs));
}

Future<void> _handleSetVolume(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final playerId = executor.resolveString(action['playerId'] ?? '');
  final volume = (executor.resolveValue(action['volume']) as num?)?.toDouble();
  final controller = VideoPlayerPlugin._controllers[playerId];
  if (controller == null || volume == null) return;
  await controller.setVolume(volume.clamp(0.0, 1.0));
}

Future<void> _handleSetSpeed(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final playerId = executor.resolveString(action['playerId'] ?? '');
  final speed = (executor.resolveValue(action['speed']) as num?)?.toDouble();
  final controller = VideoPlayerPlugin._controllers[playerId];
  if (controller == null || speed == null) return;
  await controller.setPlaybackSpeed(speed);
}
