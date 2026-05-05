import 'dart:developer' as developer;

/// Monitor interface for observability events.
abstract class Monitor {
  void onFlowStart(Map<String, dynamic> data) {}
  void onFlowEnd(Map<String, dynamic> data) {}
  void onPageRender(Map<String, dynamic> data) {}
  void onServerActionCall(Map<String, dynamic> data) {}
  void onError(Map<String, dynamic> data) {}
  void onSessionStart(Map<String, dynamic> data) {}
  void onSessionEnd(Map<String, dynamic> data) {}
}

/// Emitter that fans out events to registered monitors.
class MonitorEmitter {
  final _monitors = <Monitor>[];

  void register(Monitor monitor) => _monitors.add(monitor);

  void emit(String event, Map<String, dynamic> data) {
    for (final m in _monitors) {
      switch (event) {
        case 'onFlowStart':
          m.onFlowStart(data);
        case 'onFlowEnd':
          m.onFlowEnd(data);
        case 'onPageRender':
          m.onPageRender(data);
        case 'onServerActionCall':
          m.onServerActionCall(data);
        case 'onError':
          m.onError(data);
        case 'onSessionStart':
          m.onSessionStart(data);
        case 'onSessionEnd':
          m.onSessionEnd(data);
      }
    }
  }
}

/// Simple console monitor for dev mode.
class ConsoleMonitor extends Monitor {
  @override
  void onFlowStart(Map<String, dynamic> data) =>
      developer.log('[flow:start] ${data['path']}', name: 'orca');

  @override
  void onFlowEnd(Map<String, dynamic> data) => developer.log(
    '[flow:end] ${data['path']} (${data['durationMs']}ms)',
    name: 'orca',
  );

  @override
  void onPageRender(Map<String, dynamic> data) => developer.log(
    '[render] ${data['pageId']} (${data['durationMs']}ms)',
    name: 'orca',
  );

  @override
  void onError(Map<String, dynamic> data) => developer.log(
    '[error] ${data['stage']}: ${data['error']}',
    name: 'orca',
  );
}
