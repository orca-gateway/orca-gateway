# orca_google_map

[Orca Gateway](https://github.com/orca-gateway/orca-gateway) plugin for Google Maps — server-driven map rendering with markers, camera control, and gesture events.

## Installation

```yaml
dependencies:
  orca_gateway: ^0.3.0
  orca_google_map: ^0.2.0
```

Or via the Flutter CLI:

```sh
flutter pub add orca_gateway orca_google_map
```

## Usage

Register the plugin with your `OrcaApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:orca_gateway/orca_gateway.dart';
import 'package:orca_google_map/orca_google_map.dart';

void main() {
  runApp(
    OrcaApp(
      client: OrcaClient(baseUrl: 'https://your-engine.example.com'),
      appId: 'your-app-id',
      plugins: [GoogleMapPlugin()],
    ),
  );
}
```

The engine can then render `GoogleMap` widgets, set markers, control the camera, and react to user gestures — all driven from the server.

## Platform setup

Follow the official [`google_maps_flutter`](https://pub.dev/packages/google_maps_flutter) setup for API keys on iOS and Android.

## Native apps (Swift and Kotlin SDKs)

The same plugin exists for the native SDKs, with the same widget, triggers, action, params and
defaults, so one server page shows a map in all three. Neither ships in this package:

- iOS and macOS, on the Swift SDK: the SwiftPM library `OrcaGoogleMap` from
  [orca-google-map-swift](https://github.com/orca-gateway/orca-google-map-swift), registered as
  `GoogleMapPlugin()`. It draws Apple's map with MapKit, so it needs no Google key. See its
  [README](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_google_map/ios/README.md).
- Android, on the Kotlin SDK: `com.orcagateway:orca-google-map` from Maven Central, registered as
  `GoogleMapPlugin()`. It draws Google's map with Maps Compose, with the app's Maps API key. See
  its [README](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_google_map/android/README.md).

## License

BSL 1.1 — see [LICENSE](LICENSE).
