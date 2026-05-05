import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:orca_gateway/orca_gateway.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Orca Gateway plugin for voice recording and playback.
///
/// ## Widget: `VoiceRecorder`
///
/// A visual recording indicator that shows recording state.
///
/// Props:
/// - `recorderId` (String) — unique ID to address this recorder from actions
/// - `showAmplitude` (bool) — whether to show amplitude visualization
///
/// ## Triggers:
/// - `onAmplitudeChange` — fires with `{amplitude, dBFS}` during recording
/// - `onStateChange` — fires with `{state}` ("idle", "recording", "paused")
/// - `onRecordingComplete` — fires with `{path, duration}` when recording stops
///
/// ## Actions:
/// - `startRecording` — starts recording audio (`recorderId`, `format?`)
/// - `stopRecording` — stops recording and gets the file path (`recorderId`)
/// - `pauseRecording` — pauses active recording (`recorderId`)
/// - `resumeRecording` — resumes paused recording (`recorderId`)
/// - `playRecording` — plays a recorded file (`path`)
/// - `stopPlayback` — stops current playback
class VoiceRecorderPlugin extends OrcaPlugin {
  VoiceRecorderPlugin()
      : super(
          name: 'VoiceRecorderPlugin',
          widgets: {
            'VoiceRecorder': _buildVoiceRecorder,
          },
          actions: {
            'startRecording': _handleStartRecording,
            'stopRecording': _handleStopRecording,
            'pauseRecording': _handlePauseRecording,
            'resumeRecording': _handleResumeRecording,
            'playRecording': _handlePlayRecording,
            'stopPlayback': _handleStopPlayback,
            'pausePlayback': _handlePausePlayback,
            'resumePlayback': _handleResumePlayback,
            'seekPlayback': _handleSeekPlayback,
          },
          triggers: {
            'VoiceRecorder': [
              const TriggerDefinition(
                name: 'onAmplitudeChange',
                dataType: 'Amplitude',
                description: 'Fires periodically with {amplitude, dBFS} during recording',
              ),
              const TriggerDefinition(
                name: 'onStateChange',
                dataType: 'String',
                description: 'Fires with {state} when recording state changes',
              ),
              const TriggerDefinition(
                name: 'onRecordingComplete',
                dataType: 'RecordingResult',
                description: 'Fires with {path, duration} when recording stops',
              ),
            ],
          },
        );

  static final Map<String, _RecorderInstance> _recorders = {};
  static final AudioPlayer _player = AudioPlayer();

  static _RecorderInstance _getOrCreate(String id) {
    return _recorders.putIfAbsent(id, () => _RecorderInstance());
  }
}

class _RecorderInstance {
  final AudioRecorder recorder = AudioRecorder();
  final ValueNotifier<String> state = ValueNotifier('idle');
  final ValueNotifier<double> amplitude = ValueNotifier(-60.0);
  StreamSubscription<Amplitude>? amplitudeSub;
  DateTime? startTime;

  Future<void> dispose() async {
    await amplitudeSub?.cancel();
    await recorder.dispose();
    state.dispose();
    amplitude.dispose();
  }
}

Widget _buildVoiceRecorder(OrcaComponentContext ctx) {
  final recorderId = ctx.prop<String>('recorderId') ?? ctx.node.id;
  final showAmplitude = ctx.propOr<bool>('showAmplitude', true);

  return _VoiceRecorderWidget(
    key: ValueKey('voice_recorder_$recorderId'),
    recorderId: recorderId,
    showAmplitude: showAmplitude,
    context: ctx,
  );
}

class _VoiceRecorderWidget extends StatefulWidget {
  final String recorderId;
  final bool showAmplitude;
  final OrcaComponentContext context;

  const _VoiceRecorderWidget({
    super.key,
    required this.recorderId,
    required this.showAmplitude,
    required this.context,
  });

  @override
  State<_VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<_VoiceRecorderWidget> {
  _RecorderInstance? _instance;

  @override
  void initState() {
    super.initState();
    _instance = VoiceRecorderPlugin._getOrCreate(widget.recorderId);
    _instance!.state.addListener(_onStateChanged);
    _instance!.amplitude.addListener(_onAmplitudeChanged);
  }

  @override
  void dispose() {
    _instance?.state.removeListener(_onStateChanged);
    _instance?.amplitude.removeListener(_onAmplitudeChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
    widget.context.fireAction('onStateChange', eventData: {
      'state': _instance!.state.value,
    });
  }

  void _onAmplitudeChanged() {
    if (!mounted) return;
    setState(() {});
    widget.context.fireAction('onAmplitudeChange', eventData: {
      'amplitude': _instance!.amplitude.value,
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _instance?.state.value ?? 'idle';
    final amp = _instance?.amplitude.value ?? -60.0;
    final isRecording = state == 'recording';
    final isPaused = state == 'paused';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecording
                ? const Color(0xFFFF0000)
                : isPaused
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF9E9E9E),
          ),
        ),
        if (widget.showAmplitude && isRecording) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            height: 4,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (amp + 60).clamp(0, 60) / 60,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          isRecording ? 'Recording' : isPaused ? 'Paused' : 'Ready',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

Future<void> _handleStartRecording(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final recorderId = executor.resolveString(action['recorderId'] ?? '');
  if (recorderId.isEmpty) return;

  final instance = VoiceRecorderPlugin._getOrCreate(recorderId);

  if (!await instance.recorder.hasPermission()) return;

  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/orca_recording_${recorderId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

  await instance.recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc),
    path: path,
  );
  instance.startTime = DateTime.now();
  instance.state.value = 'recording';

  instance.amplitudeSub = instance.recorder
      .onAmplitudeChanged(const Duration(milliseconds: 200))
      .listen((amp) {
    instance.amplitude.value = amp.current;
  });
}

Future<void> _handleStopRecording(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final recorderId = executor.resolveString(action['recorderId'] ?? '');
  if (recorderId.isEmpty) return;

  final instance = VoiceRecorderPlugin._recorders[recorderId];
  if (instance == null) return;

  final path = await instance.recorder.stop();
  await instance.amplitudeSub?.cancel();
  instance.state.value = 'idle';

  final duration = instance.startTime != null
      ? DateTime.now().difference(instance.startTime!).inMilliseconds
      : 0;

  // Store result in state if keys are provided
  final pathKey = action['pathKey'] as String?;
  final durationKey = action['durationKey'] as String?;
  final scope = action['scope'] as String? ?? 'page';

  if (pathKey != null && path != null) {
    await executor.execute({
      'type': 'setState',
      'key': pathKey,
      'value': path,
      'scope': scope,
    });
  }
  if (durationKey != null) {
    await executor.execute({
      'type': 'setState',
      'key': durationKey,
      'value': duration,
      'scope': scope,
    });
  }
}

Future<void> _handlePauseRecording(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final recorderId = executor.resolveString(action['recorderId'] ?? '');
  if (recorderId.isEmpty) return;
  final instance = VoiceRecorderPlugin._recorders[recorderId];
  if (instance == null) return;
  await instance.recorder.pause();
  instance.state.value = 'paused';
}

Future<void> _handleResumeRecording(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final recorderId = executor.resolveString(action['recorderId'] ?? '');
  if (recorderId.isEmpty) return;
  final instance = VoiceRecorderPlugin._recorders[recorderId];
  if (instance == null) return;
  await instance.recorder.resume();
  instance.state.value = 'recording';
}

/// True after we've configured the global audio context for playback. Set
/// once on first play and reused thereafter — `setAudioContext` is cheap but
/// we still avoid re-issuing the platform call on every tap.
bool _playerContextConfigured = false;

/// Active stream subscriptions for the current playback. Replaced on every
/// `playRecording` call (previous subs are cancelled) and cleared on
/// stopPlayback / player-complete. Kept in a plain struct instead of
/// individual fields so the "cancel all + null out" pattern is a one-liner.
class _PlaybackSubs {
  StreamSubscription<Duration>? position;
  StreamSubscription<Duration>? duration;
  StreamSubscription<void>? complete;

  Future<void> cancelAll() async {
    await position?.cancel();
    await duration?.cancel();
    await complete?.cancel();
    position = null;
    duration = null;
    complete = null;
  }
}

final _PlaybackSubs _playbackSubs = _PlaybackSubs();

/// Push a setState response to the SDK's executor. Thin wrapper so the
/// stream subscribers below don't repeat the literal Map shape.
Future<void> _writeState(
  ActionExecutor executor,
  String? key,
  dynamic value,
  String scope,
) async {
  if (key == null || key.isEmpty) return;
  await executor.execute({
    'type': 'setState',
    'key': key,
    'value': value,
    'scope': scope,
  });
}

Future<void> _handlePlayRecording(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final path = executor.resolveString(action['path'] ?? '');
  if (path.isEmpty) {
    debugPrint('[orca_voice_recorder] playRecording: empty path, skipping');
    return;
  }

  // Optional state keys — when the caller wires them up, the plugin writes
  // live progress into these pageState / appState slots so UI can draw a
  // scrubber without polling. Same mechanism stopRecording already uses.
  final positionKey = action['positionKey'] as String?;
  final durationKey = action['durationKey'] as String?;
  final stateKey = action['stateKey'] as String?;
  final scope = (action['scope'] as String?) ?? 'page';

  // iOS-specific fix: the `record` package leaves AVAudioSession in `.record`
  // category after stopping. `audioplayers` then calls `play()` against a
  // session that physically can't route output, so the user hears nothing
  // and there's no error. Forcing the session to `.playback` before the
  // play call resets routing for output.
  if (!kIsWeb && !_playerContextConfigured && Platform.isIOS) {
    try {
      await VoiceRecorderPlugin._player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
          ),
        ),
      );
      _playerContextConfigured = true;
    } catch (e) {
      debugPrint('[orca_voice_recorder] setAudioContext failed: $e');
    }
  }

  // Cancel any prior subscriptions before starting the new clip. Without
  // this, rapid-fire taps on different clips would leave orphan listeners
  // pushing progress for the OLD clip on top of the new one.
  await _playbackSubs.cancelAll();

  // Wire up progress streams BEFORE calling play — on iOS the position and
  // duration events can fire in the same microtask as play(), so late
  // subscribers miss the initial emit.
  if (positionKey != null) {
    _playbackSubs.position = VoiceRecorderPlugin._player.onPositionChanged
        .listen((pos) => _writeState(executor, positionKey, pos.inMilliseconds, scope));
  }
  if (durationKey != null) {
    _playbackSubs.duration = VoiceRecorderPlugin._player.onDurationChanged
        .listen((dur) => _writeState(executor, durationKey, dur.inMilliseconds, scope));
  }
  // Completion always clears the state keys (and the optional stateKey) so
  // the UI snaps back to an idle view without the caller needing to re-wire
  // anything.
  _playbackSubs.complete = VoiceRecorderPlugin._player.onPlayerComplete.listen((_) async {
    await _playbackSubs.cancelAll();
    await _writeState(executor, positionKey, 0, scope);
    await _writeState(executor, stateKey, 'stopped', scope);
  });

  try {
    await VoiceRecorderPlugin._player.play(DeviceFileSource(path));
    await _writeState(executor, stateKey, 'playing', scope);
    debugPrint('[orca_voice_recorder] play started: $path');
  } catch (e, st) {
    // audioplayers normally swallows errors silently — surface them so the
    // dev console at least shows what went wrong (codec, missing file, etc).
    debugPrint('[orca_voice_recorder] play failed: $e\n$st');
    await _playbackSubs.cancelAll();
    await _writeState(executor, stateKey, 'error', scope);
  }
}

Future<void> _handleStopPlayback(
    Map<String, dynamic> action, ActionExecutor executor) async {
  await VoiceRecorderPlugin._player.stop();
  // Cancel the live-progress subs so the progress bar stops updating.
  // Callers that bound `positionKey` / `stateKey` in the preceding
  // playRecording call can optionally pass them here too so the state
  // snaps to zero — otherwise the last-emitted position lingers.
  await _playbackSubs.cancelAll();
  final positionKey = action['positionKey'] as String?;
  final stateKey = action['stateKey'] as String?;
  final scope = (action['scope'] as String?) ?? 'page';
  await _writeState(executor, positionKey, 0, scope);
  await _writeState(executor, stateKey, 'stopped', scope);
}

Future<void> _handlePausePlayback(
    Map<String, dynamic> action, ActionExecutor executor) async {
  await VoiceRecorderPlugin._player.pause();
  final stateKey = action['stateKey'] as String?;
  final scope = (action['scope'] as String?) ?? 'page';
  await _writeState(executor, stateKey, 'paused', scope);
}

Future<void> _handleResumePlayback(
    Map<String, dynamic> action, ActionExecutor executor) async {
  await VoiceRecorderPlugin._player.resume();
  final stateKey = action['stateKey'] as String?;
  final scope = (action['scope'] as String?) ?? 'page';
  await _writeState(executor, stateKey, 'playing', scope);
}

Future<void> _handleSeekPlayback(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final positionRaw = executor.resolveValue(action['position']);
  final positionMs = positionRaw is num ? positionRaw.toInt() : 0;
  // Clamp lower bound — negative seeks confuse AVPlayer on iOS.
  await VoiceRecorderPlugin._player
      .seek(Duration(milliseconds: positionMs < 0 ? 0 : positionMs));
}
