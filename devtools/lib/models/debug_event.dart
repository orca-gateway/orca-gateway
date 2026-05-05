class DebugEvent {
  final String type;
  final String deviceId;
  final int timestamp;
  final Map<String, dynamic> payload;

  DebugEvent({required this.type, required this.deviceId, required this.timestamp, required this.payload});

  Map<String, dynamic> toJson() => {'type': type, 'deviceId': deviceId, 'timestamp': timestamp, 'payload': payload};
}
