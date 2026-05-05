import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/debug_event.dart';
import '../models/device_session.dart';

class ConnectionManager extends ChangeNotifier {
  final Map<String, DeviceSession> _sessions = {};
  String? _activeDeviceId;
  Timer? _notifyTimer;

  // ─── Stream pause (Phase 1 — toolbar Pause/Resume button) ───
  bool _streamPaused = false;
  // Per-device FIFO buffer of events received while paused.
  final Map<String, Queue<DebugEvent>> _pausedBuffers = {};

  List<String> get deviceIds => _sessions.keys.toList();
  String? get activeDeviceId => _activeDeviceId;

  DeviceSession? get activeSession =>
      _activeDeviceId != null ? _sessions[_activeDeviceId] : null;

  DeviceSession? getSession(String deviceId) => _sessions[deviceId];

  bool get streamPaused => _streamPaused;

  int get bufferedCount =>
      _pausedBuffers.values.fold(0, (sum, q) => sum + q.length);

  int get totalEventCount =>
      _sessions.values.fold(0, (sum, s) => sum + s.events.length);

  void addDevice(String deviceId, Map<String, dynamic> deviceInfo) {
    _sessions[deviceId] =
        DeviceSession(deviceId: deviceId, deviceInfo: deviceInfo);
    _activeDeviceId ??= deviceId;
    notifyListeners();
  }

  void removeDevice(String deviceId) {
    _sessions.remove(deviceId);
    _pausedBuffers.remove(deviceId);
    if (_activeDeviceId == deviceId) {
      _activeDeviceId =
          _sessions.keys.isNotEmpty ? _sessions.keys.first : null;
    }
    notifyListeners();
  }

  void setActiveDevice(String deviceId) {
    if (_sessions.containsKey(deviceId)) {
      _activeDeviceId = deviceId;
      notifyListeners();
    }
  }

  void addEvent(String deviceId, DebugEvent event) {
    if (_streamPaused) {
      // Buffer events rather than drop them; drained on resume.
      final buf = _pausedBuffers.putIfAbsent(deviceId, () => Queue());
      buf.add(event);
      // Keep buffer bounded — reuse the session's 5000 cap to avoid runaway
      // memory if the user leaves pause on for hours.
      while (buf.length > 5000) {
        buf.removeFirst();
      }
      _throttledNotify();
      return;
    }
    _sessions[deviceId]?.addEvent(event);
    _throttledNotify();
  }

  void pauseStream() {
    if (_streamPaused) return;
    _streamPaused = true;
    notifyListeners();
  }

  void resumeStream() {
    if (!_streamPaused) return;
    _streamPaused = false;
    // Drain paused buffers into their sessions in receive order.
    _pausedBuffers.forEach((deviceId, queue) {
      final session = _sessions[deviceId];
      if (session != null) {
        while (queue.isNotEmpty) {
          session.addEvent(queue.removeFirst());
        }
      } else {
        queue.clear();
      }
    });
    notifyListeners();
  }

  void toggleStream() => _streamPaused ? resumeStream() : pauseStream();

  /// Coalesce rapid-fire event notifications into a single rebuild per 100ms window.
  void _throttledNotify() {
    if (_notifyTimer != null) return;
    _notifyTimer = Timer(const Duration(milliseconds: 100), () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    super.dispose();
  }
}
