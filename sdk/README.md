# orca_gateway

Flutter SDK for [Orca Gateway](https://github.com/orca-gateway/orca-gateway) — renders server-driven UI natively.

## Installation

```yaml
dependencies:
  orca_gateway: ^0.1.0
```

Or via the Flutter CLI:

```sh
flutter pub add orca_gateway
```

## Quick Start

```dart
import 'package:orca_gateway/orca_gateway.dart';

final client = OrcaClient(
  baseUrl: 'http://localhost:8080',
  apiKey: 'your-api-key',
);

// Full app with navigation
OrcaApp(
  client: client,
  appId: 'my-app',
);

// Single page
OrcaPage(
  client: client,
  appId: 'my-app',
  path: '/home',
);
```

## Features

- Native Flutter rendering of server-defined screens
- Elm-style state management with selective rebuilds
- 40+ built-in component builders
- Plugin system for custom widgets via `OrcaPlugin`
- Offline support with static flows and session sync
- Capability negotiation with safe degradation
- Animation support (tweens, sequences)

## Plugins

Extend the SDK with official plugins:

- `orca_google_map` — Google Maps
- `orca_push_notification` — Push notifications
- `orca_video_player` — Video playback
- `orca_voice_recorder` — Audio recording

## Documentation

See the [Orca Gateway repository](https://github.com/orca-gateway/orca-gateway) for full documentation.

## License

See [LICENSE](../LICENSE) in the repository root.
