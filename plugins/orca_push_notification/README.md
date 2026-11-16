# orca_push_notification

[Orca Gateway](https://github.com/orca-gateway/orca-gateway) plugin for push notifications — FCM token management, permission handling, and notification display.

## Installation

```yaml
dependencies:
  orca_gateway: ^0.3.0
  orca_push_notification: ^0.2.0
```

Or via the Flutter CLI:

```sh
flutter pub add orca_gateway orca_push_notification
```

## Usage

Initialize the plugin before `runApp`, then register it with your `OrcaApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:orca_gateway/orca_gateway.dart';
import 'package:orca_push_notification/orca_push_notification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationPlugin.initialize(
    onNotificationTap: (payload) {
      // The tapped notification's payload: route it as your app does.
    },
  );
  runApp(
    OrcaApp(
      client: OrcaClient(baseUrl: 'https://your-engine.example.com'),
      appId: 'your-app-id',
      plugins: [PushNotificationPlugin()],
    ),
  );
}
```

The engine can then request the notification permission, read the FCM token, show local notifications and subscribe to FCM topics via server actions.

## Platform setup

Follow the official Firebase setup for [`firebase_messaging`](https://pub.dev/packages/firebase_messaging) and the platform configuration for [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications).

## Native apps (Swift and Kotlin SDKs)

The same plugin exists for the native SDKs, with the same actions, params and defaults, so one
server page sends them to all three. Neither ships in this package:

- iOS, on the Swift SDK: the SwiftPM library `OrcaPushNotification` from
  [orca-push-notification-swift](https://github.com/orca-gateway/orca-push-notification-swift),
  registered as `PushNotificationPlugin()`, with `initialize(onNotificationTap:)` called on it at
  launch and the APNs token forwarded from the app delegate. It brings Firebase Messaging from
  firebase-ios-sdk; the app configures Firebase. See its
  [README](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_push_notification/ios/README.md).
- Android, on the Kotlin SDK: `com.orcagateway:orca-push-notification` from Maven Central,
  registered as `PushNotificationPlugin(applicationContext)`, with
  `initialize(activity, onNotificationTap)` called on it in each activity's `onCreate`. It brings
  firebase-messaging; the app adds its `google-services.json` and the google-services Gradle
  plugin. See its
  [README](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_push_notification/android/README.md).

## License

BSL 1.1 — see [LICENSE](LICENSE).
