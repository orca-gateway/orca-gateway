import '../models/debug_event.dart';

class EventParser {
  static DebugEvent? parse(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final deviceId = json['deviceId'] as String?;
    final timestamp = json['timestamp'] as int?;
    final payload = json['payload'] as Map<String, dynamic>?;
    if (type == null || deviceId == null || timestamp == null || payload == null) return null;
    return DebugEvent(type: type, deviceId: deviceId, timestamp: timestamp, payload: payload);
  }
}
