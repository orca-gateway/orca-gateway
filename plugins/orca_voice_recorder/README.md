# orca_voice_recorder

[Orca Gateway](https://github.com/orca-gateway/orca-gateway) plugin for voice recording — start/stop/pause recording with amplitude monitoring and playback.

## Installation

```yaml
dependencies:
  orca_gateway: ^0.3.0
  orca_voice_recorder: ^0.2.0
```

Or via the Flutter CLI:

```sh
flutter pub add orca_gateway orca_voice_recorder
```

## Usage

Register the plugin with your `OrcaApp`:

```dart
import 'package:orca_gateway/orca_gateway.dart';
import 'package:orca_voice_recorder/orca_voice_recorder.dart';

void main() {
  runApp(
    OrcaApp(
      client: OrcaClient(baseUrl: 'https://your-engine.example.com'),
      plugins: [VoiceRecorderPlugin()],
    ),
  );
}
```

The engine can start, pause, and stop recordings, monitor live amplitude, and play back saved audio — all from server-side actions.

## Platform setup

Follow the platform setup for [`record`](https://pub.dev/packages/record) and [`audioplayers`](https://pub.dev/packages/audioplayers) (microphone permissions, iOS background audio, etc.).

## Native apps (Swift and Kotlin SDKs)

The same plugin exists for the native SDKs, with the same widget, triggers, actions, params and
defaults, so one server page records in all three. Neither ships in this package:

- iOS and macOS, on the Swift SDK: the SwiftPM library `OrcaVoiceRecorder` from
  [orca-voice-recorder-swift](https://github.com/orca-gateway/orca-voice-recorder-swift), registered
  as `VoiceRecorderPlugin()`. See its
  [README](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_voice_recorder/ios/README.md).
- Android, on the Kotlin SDK: `com.orcagateway:orca-voice-recorder` from Maven Central, registered
  as `VoiceRecorderPlugin(applicationContext)`. See its
  [README](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_voice_recorder/android/README.md).

## License

BSL 1.1 — see [LICENSE](LICENSE).
