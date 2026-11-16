# orca_video_player

[Orca Gateway](https://github.com/orca-gateway/orca-gateway) plugin for video playback — server-driven video player with play/pause/seek controls and progress events.

## Installation

```yaml
dependencies:
  orca_gateway: ^0.3.0
  orca_video_player: ^0.2.0
```

Or via the Flutter CLI:

```sh
flutter pub add orca_gateway orca_video_player
```

## Usage

Register the plugin with your `OrcaApp`:

```dart
import 'package:orca_gateway/orca_gateway.dart';
import 'package:orca_video_player/orca_video_player.dart';

void main() {
  runApp(
    OrcaApp(
      client: OrcaClient(baseUrl: 'https://your-engine.example.com'),
      plugins: [VideoPlayerPlugin()],
    ),
  );
}
```

The engine can render a video player, drive play/pause/seek via server actions, and receive progress events in app state.

## Platform setup

Follow the official [`video_player`](https://pub.dev/packages/video_player) setup for iOS, Android, and web.

## Native apps (Swift and Kotlin SDKs)

The same plugin exists for the native SDKs, with the same widget, triggers, actions, params and
defaults, so one server page plays a video in all three. Neither ships in this package:

- iOS and macOS, on the Swift SDK: the SwiftPM library `OrcaVideoPlayer` from
  [orca-video-player-swift](https://github.com/orca-gateway/orca-video-player-swift), registered
  as `VideoPlayerPlugin()`. See its
  [README](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_video_player/ios/README.md).
- Android, on the Kotlin SDK: `com.orcagateway:orca-video-player` from Maven Central, registered
  as `VideoPlayerPlugin()`. See its
  [README](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_video_player/android/README.md).

## License

BSL 1.1 — see [LICENSE](LICENSE).
