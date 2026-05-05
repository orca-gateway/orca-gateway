import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'connection_manager.dart';
import 'event_parser.dart';

class DevToolsWsServer {
  final ConnectionManager connectionManager;
  final int port;
  HttpServer? _server;

  int _activePort;
  DevToolsWsServer({required this.connectionManager, this.port = 6363})
    : _activePort = port;

  int get activePort => _activePort;

  Future<void> start() async {
    _activePort = port;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _activePort);
    debugPrint('DevTools WebSocket server listening on port $port');
    _server!.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        debugPrint(
          'WebSocket upgrade request from ${request.connectionInfo?.remoteAddress.address}',
        );
        final socket = await WebSocketTransformer.upgrade(request);
        _handleConnection(socket);
      } else {
        // Not a WebSocket request — respond with 200 so clients don't hang
        request.response
          ..statusCode = HttpStatus.ok
          ..write('Orca DevTools WebSocket Server')
          ..close();
      }
    });
  }

  void _handleConnection(WebSocket socket) {
    debugPrint('WebSocket client connected');
    String? deviceId;
    socket.listen(
      (data) {
        if (data is String) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final event = EventParser.parse(json);
            if (event == null) return;

            if (event.type == 'device_info') {
              deviceId = event.deviceId;
              connectionManager.addDevice(deviceId!, event.payload);
              debugPrint(
                'Device registered: $deviceId (${event.payload['platform']})',
              );
            } else if (deviceId != null) {
              connectionManager.addEvent(deviceId!, event);
            }
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        }
      },
      onDone: () {
        debugPrint('WebSocket client disconnected: $deviceId');
        if (deviceId != null) {
          connectionManager.removeDevice(deviceId!);
        }
      },
      onError: (e) {
        debugPrint('WebSocket error: $e');
        if (deviceId != null) {
          connectionManager.removeDevice(deviceId!);
        }
      },
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> restart(int newPort) async {
    await stop();
    _activePort = newPort;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _activePort);
    debugPrint('DevTools WebSocket server restarted on port $_activePort');
    _server!.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _handleConnection(socket);
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('Orca DevTools WebSocket Server')
          ..close();
      }
    });
  }
}
