# orca_video_player

[Orca Gateway](https://github.com/orca-gateway/orca-gateway) plugin for video playback — server-driven video player with play/pause/seek controls and progress events.

## Installation

```yaml
dependencies:
  orca_gateway: ^0.1.0
  orca_video_player: ^0.1.0
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
      plugins: [OrcaVideoPlayerPlugin()],
    ),
  );
}
```

The engine can render a video player, drive play/pause/seek via server actions, and receive progress events in app state.

## Platform setup

Follow the official [`video_player`](https://pub.dev/packages/video_player) setup for iOS, Android, and web.

## License

BSL 1.1 — see [LICENSE](LICENSE).
