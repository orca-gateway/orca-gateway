# orca_google_map

[Orca Gateway](https://github.com/orca-gateway/orca-gateway) plugin for Google Maps — server-driven map rendering with markers, camera control, and gesture events.

## Installation

```yaml
dependencies:
  orca_gateway: ^0.1.0
  orca_google_map: ^0.1.0
```

Or via the Flutter CLI:

```sh
flutter pub add orca_gateway orca_google_map
```

## Usage

Register the plugin with your `OrcaApp`:

```dart
import 'package:orca_gateway/orca_gateway.dart';
import 'package:orca_google_map/orca_google_map.dart';

void main() {
  runApp(
    OrcaApp(
      client: OrcaClient(baseUrl: 'https://your-engine.example.com'),
      plugins: [OrcaGoogleMapPlugin()],
    ),
  );
}
```

The engine can then render `GoogleMap` widgets, set markers, control the camera, and react to user gestures — all driven from the server.

## Platform setup

Follow the official [`google_maps_flutter`](https://pub.dev/packages/google_maps_flutter) setup for API keys on iOS and Android.

## License

BSL 1.1 — see [LICENSE](LICENSE).
