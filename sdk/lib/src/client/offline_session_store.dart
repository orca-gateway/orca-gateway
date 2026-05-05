import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single offline session event (start or end) with its timestamp.
class OfflineSessionRecord {
  final String type; // "start" or "end"
  final int timestamp; // milliseconds since epoch

  const OfflineSessionRecord({required this.type, required this.timestamp});

  Map<String, dynamic> toJson() => {'type': type, 'timestamp': timestamp};

  factory OfflineSessionRecord.fromJson(Map<String, dynamic> json) {
    return OfflineSessionRecord(
      type: json['type'] as String,
      timestamp: json['timestamp'] as int,
    );
  }
}

/// Stores session events locally when the device is offline.
/// Persists via SharedPreferences so data survives app restarts.
class OfflineSessionStore {
  static const _key = 'orca_offline_sessions';
  final SharedPreferencesAsync _prefs;

  OfflineSessionStore({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  /// Append a session event to the offline queue.
  Future<void> save(String type) async {
    final records = await load();
    records.add(OfflineSessionRecord(
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    await _prefs.setString(_key, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  /// Load all queued offline session events.
  Future<List<OfflineSessionRecord>> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => OfflineSessionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear the offline queue after successful flush.
  Future<void> clear() async {
    await _prefs.setString(_key, '[]');
  }

  /// Whether there are pending offline sessions.
  Future<bool> get hasPending async {
    final records = await load();
    return records.isNotEmpty;
  }
}
