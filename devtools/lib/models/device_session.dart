import 'dart:convert';
import 'debug_event.dart';

class DeviceSession {
  final String deviceId;
  final Map<String, dynamic> deviceInfo;
  final List<DebugEvent> _events = [];
  static const int _maxEvents = 5000;

  /// Cached filtered lists, invalidated on each new event.
  Map<String, List<DebugEvent>>? _eventsByTypeCache;

  DeviceSession({required this.deviceId, required this.deviceInfo});

  List<DebugEvent> get events => List.unmodifiable(_events);

  List<DebugEvent> eventsByType(String type) {
    _eventsByTypeCache ??= {};
    return _eventsByTypeCache!.putIfAbsent(
      type,
      () => _events.where((e) => e.type == type).toList(),
    );
  }

  void addEvent(DebugEvent event) {
    if (_events.length >= _maxEvents) {
      _events.removeAt(0);
    }
    _events.add(event);
    _eventsByTypeCache = null; // invalidate cache
  }

  String toExportJson() => const JsonEncoder.withIndent('  ').convert({
    'deviceId': deviceId,
    'deviceInfo': deviceInfo,
    'events': _events.map((e) => e.toJson()).toList(),
  });
}
