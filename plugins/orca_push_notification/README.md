# orca_push_notification

[Orca Gateway](https://github.com/orca-gateway/orca-gateway) plugin for push notifications — FCM token management, permission handling, and notification display.

## Installation

```yaml
dependencies:
  orca_gateway: ^0.1.0
  orca_push_notification: ^0.1.0
```

Or via the Flutter CLI:

```sh
flutter pub add orca_gateway orca_push_notification
```

## Usage

Register the plugin with your `OrcaApp`:

```dart
import 'package:orca_gateway/orca_gateway.dart';
import 'package:orca_push_notification/orca_push_notification.dart';

void main() {
  runApp(
    OrcaApp(
      client: OrcaClient(baseUrl: 'https://your-engine.example.com'),
      plugins: [OrcaPushNotificationPlugin()],
    ),
  );
}
```

The engine can request permissions, retrieve and refresh FCM tokens, and display local notifications via server actions.

## Platform setup

Follow the official Firebase setup for [`firebase_messaging`](https://pub.dev/packages/firebase_messaging) and the platform configuration for [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications).

## License

BSL 1.1 — see [LICENSE](LICENSE).
