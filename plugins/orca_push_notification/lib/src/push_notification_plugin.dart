import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orca_gateway/orca_gateway.dart';

/// Orca Gateway plugin for push notifications via Firebase Cloud Messaging.
///
/// ## Actions:
/// - `requestNotificationPermission` — requests notification permission, sets token to state
/// - `getNotificationToken` — fetches the current FCM token into state
/// - `showLocalNotification` — displays a local notification with `title`, `body`, `payload`
/// - `subscribeToTopic` — subscribes to an FCM topic
/// - `unsubscribeFromTopic` — unsubscribes from an FCM topic
///
/// ## Setup:
/// Call `PushNotificationPlugin.initialize()` in your app's `main()` before
/// `runApp()` to set up foreground message handling.
class PushNotificationPlugin extends OrcaPlugin {
  PushNotificationPlugin()
      : super(
          name: 'PushNotificationPlugin',
          widgets: {},
          actions: {
            'requestNotificationPermission': _handleRequestPermission,
            'getNotificationToken': _handleGetToken,
            'showLocalNotification': _handleShowNotification,
            'subscribeToTopic': _handleSubscribe,
            'unsubscribeFromTopic': _handleUnsubscribe,
          },
        );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize FCM and local notifications.
  /// Call this in `main()` before `runApp()`.
  static Future<void> initialize({
    /// Called when a notification is tapped while the app is in foreground/background.
    void Function(String? payload)? onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;

    // Local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    // Handle foreground FCM messages as local notifications
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'orca_default_channel',
            'Notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    });
  }
}

Future<void> _handleRequestPermission(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final settings = await FirebaseMessaging.instance.requestPermission();
  final granted = settings.authorizationStatus == AuthorizationStatus.authorized;

  final statusKey = action['statusKey'] as String?;
  final tokenKey = action['tokenKey'] as String?;
  final scope = action['scope'] as String? ?? 'app';

  if (statusKey != null) {
    await executor.execute({
      'type': 'setState',
      'key': statusKey,
      'value': granted ? 'granted' : 'denied',
      'scope': scope,
    });
  }

  if (granted && tokenKey != null) {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await executor.execute({
        'type': 'setState',
        'key': tokenKey,
        'value': token,
        'scope': scope,
      });
    }
  }
}

Future<void> _handleGetToken(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final tokenKey = action['tokenKey'] as String? ?? 'fcmToken';
  final scope = action['scope'] as String? ?? 'app';

  final token = await FirebaseMessaging.instance.getToken();
  await executor.execute({
    'type': 'setState',
    'key': tokenKey,
    'value': token,
    'scope': scope,
  });
}

Future<void> _handleShowNotification(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final title = executor.resolveString(action['title'] ?? '');
  final body = executor.resolveString(action['body'] ?? '');
  final payload = action['payload'] != null
      ? executor.resolveString(action['payload'])
      : null;

  await PushNotificationPlugin._localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'orca_default_channel',
        'Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: payload,
  );
}

Future<void> _handleSubscribe(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final topic = executor.resolveString(action['topic'] ?? '');
  if (topic.isEmpty) return;
  await FirebaseMessaging.instance.subscribeToTopic(topic);
}

Future<void> _handleUnsubscribe(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final topic = executor.resolveString(action['topic'] ?? '');
  if (topic.isEmpty) return;
  await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}
