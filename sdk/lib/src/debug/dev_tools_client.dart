import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:web_socket_channel/web_socket_channel.dart';

class DevToolsClient {
  final int port;
  final String? appName;
  WebSocketChannel? _channel;
  bool _connected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  Timer? _reconnectTimer;
  String? _deviceId;

  DevToolsClient({this.port = 6363, this.appName});

  String? get deviceId => _deviceId;

  static String _detectPlatform() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  Future<void> connect() async {
    _deviceId ??= DateTime.now().millisecondsSinceEpoch.toString();
    try {
      final uri = Uri.parse('ws://localhost:$port');
      final channel = WebSocketChannel.connect(uri);

      // Wait for the WebSocket handshake to actually complete
      await channel.ready;

      _channel = channel;
      _connected = true;
      _reconnectAttempts = 0;

      String deviceModel;
      try {
        deviceModel = Platform.localHostname;
      } catch (_) {
        deviceModel = 'unknown';
      }

      // Send handshake
      send({
        'type': 'device_info',
        'deviceId': _deviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': {
          'platform': _detectPlatform(),
          'appVersion': '1.0.0',
          'deviceModel': deviceModel,
          if (appName != null) 'appName': appName,
        },
      });

      _channel!.stream.listen(
        (_) {},
        onError: (_) => _onDisconnect(),
        onDone: () => _onDisconnect(),
      );
    } catch (_) {
      // Connection failed (dev tools not running) — silently retry later
      _onDisconnect();
    }
  }

  void send(Map<String, dynamic> event) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(event));
    } catch (e) {
      // Only reconnect on connection errors, not serialization errors
      if (e is! JsonUnsupportedObjectError) {
        _onDisconnect();
      }
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _connected = false;
    _channel?.sink.close();
    _channel = null;
  }

  void _onDisconnect() {
    _connected = false;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, connect);
  }
}
