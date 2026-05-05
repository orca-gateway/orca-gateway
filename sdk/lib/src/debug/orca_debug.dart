import 'package:flutter/foundation.dart' show debugPrint;
import 'debug_events.dart';
import 'dev_tools_client.dart';

class OrcaDebugConfig {
  final bool enabled;
  final int devToolsPort;
  final bool showOverlay;
  final bool logTimings;
  final bool captureStateChanges;
  final bool captureNetworkRequests;
  final String? appName;

  /// When true the SDK attaches request and response bodies to
  /// [DebugNetworkEvent]s so the DevTools "Body" tab can render them.
  /// Default is `false` — bodies often contain bearer tokens, PII, or other
  /// data that shouldn't leak into a debug stream by accident.
  final bool includeBodies;

  const OrcaDebugConfig({
    this.enabled = false,
    this.devToolsPort = 6363,
    this.showOverlay = false,
    this.logTimings = false,
    this.captureStateChanges = true,
    this.captureNetworkRequests = true,
    this.appName,
    this.includeBodies = false,
  });
}

class OrcaDebug {
  static OrcaDebug? _instance;
  static OrcaDebugConfig _config = const OrcaDebugConfig();
  DevToolsClient? _client;

  OrcaDebug._();

  static void init(OrcaDebugConfig config) {
    _config = config;
    // Dispose previous instance to prevent orphaned WebSocket connections
    _instance?._client?.disconnect();
    _instance = null;
    if (!config.enabled) return;
    _instance = OrcaDebug._();
    _instance!._client = DevToolsClient(
      port: config.devToolsPort,
      appName: config.appName,
    );
    _instance!._client!.connect();
  }

  static bool get isEnabled => _config.enabled;
  static OrcaDebugConfig get config => _config;
  static OrcaDebug? get instance => _instance;

  void reportTiming(DebugTimingEvent event) {
    if (!isEnabled) return;
    _send('timing', event.toJson());
    if (_config.logTimings) {
      debugPrint('[OrcaDebug] Timing: ${event.pageId} - ${event.path}');
    }
  }

  void reportStateChange(DebugStateEvent event) {
    if (!isEnabled || !_config.captureStateChanges) return;
    _send('state_change', event.toJson());
  }

  void reportAction(DebugActionEvent event) {
    if (!isEnabled) return;
    _send('action', event.toJson());
  }

  void reportNetwork(DebugNetworkEvent event) {
    if (!isEnabled || !_config.captureNetworkRequests) return;
    _send('network', event.toJson());
  }

  void reportWidgetRebuild(DebugWidgetRebuildEvent event) {
    if (!isEnabled) return;
    _send('widget_rebuild', event.toJson());
  }

  void reportError(DebugErrorEvent event) {
    if (!isEnabled) return;
    _send('error', event.toJson());
  }

  void _send(String type, Map<String, dynamic> payload) {
    _client?.send({
      'type': type,
      'deviceId': _client?.deviceId ?? 'unknown',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    });
  }

  void dispose() {
    _client?.disconnect();
    _instance = null;
  }
}
