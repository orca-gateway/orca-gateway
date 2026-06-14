import 'dart:async';

import 'package:flutter/foundation.dart';

import '../client/orca_client.dart';

/// Sends a batch of events; returns true on success. [OrcaClient.sendEvents]
/// satisfies this — the typedef keeps [OrcaAnalytics] decoupled from the client
/// for testing.
typedef EventSender = Future<bool> Function(List<Map<String, dynamic>> events);

/// Buffered, batched analytics emitter (Epic 47.4).
///
/// [track] appends to an in-memory buffer; the buffer flushes to the cloud
/// events endpoint when it reaches [batchSize] or every [flushInterval],
/// whichever comes first. Flushes are best-effort — a failed send re-queues the
/// batch so a transient connectivity blip doesn't lose data, bounded by
/// [maxBuffer] so a permanently-down endpoint can't grow memory without limit
/// (oldest events are dropped first).
///
/// Wire it once at app start with [OrcaAnalytics.forClient], call [track] from
/// your UI, and [dispose] on teardown.
class OrcaAnalytics {
  OrcaAnalytics({
    required EventSender sender,
    this.batchSize = 20,
    this.flushInterval = const Duration(seconds: 10),
    this.maxBuffer = 500,
    DateTime Function()? clock,
  })  : _send = sender,
        _now = clock ?? DateTime.now;

  /// Build an emitter that sends through an [OrcaClient] for the given app.
  factory OrcaAnalytics.forClient(
    OrcaClient client,
    String appId, {
    int batchSize = 20,
    Duration flushInterval = const Duration(seconds: 10),
    int maxBuffer = 500,
  }) {
    return OrcaAnalytics(
      sender: (events) => client.sendEvents(appId, events),
      batchSize: batchSize,
      flushInterval: flushInterval,
      maxBuffer: maxBuffer,
    );
  }

  final EventSender _send;
  final DateTime Function() _now;

  /// Flush once this many events are buffered.
  final int batchSize;

  /// Flush at least this often while events are pending.
  final Duration flushInterval;

  /// Hard cap on buffered events; oldest are dropped beyond it.
  final int maxBuffer;

  final List<Map<String, dynamic>> _buffer = [];
  Timer? _timer;
  bool _flushing = false;

  /// Queue an event. [type] is the event name (e.g. 'screen_view'); [payload]
  /// is arbitrary JSON-serializable context. Stamped with a client timestamp.
  void track(String type, {Map<String, dynamic>? payload}) {
    _buffer.add(<String, dynamic>{
      'type': type,
      'ts': _now().toUtc().toIso8601String(),
      'payload': ?payload,
    });
    _trim();
    _timer ??= Timer(flushInterval, () {
      // ignore: discarded_futures — fire-and-forget periodic flush
      flush();
    });
    if (_buffer.length >= batchSize) {
      // ignore: discarded_futures
      flush();
    }
  }

  /// Send buffered events now. Overlapping calls are coalesced (a flush already
  /// in flight is a no-op). Returns true when nothing needed sending or the
  /// send succeeded.
  Future<bool> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_flushing || _buffer.isEmpty) return true;
    _flushing = true;
    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    try {
      final ok = await _send(batch);
      if (!ok) {
        // Re-queue at the front so order is preserved, then re-trim.
        _buffer.insertAll(0, batch);
        _trim();
      }
      return ok;
    } finally {
      _flushing = false;
    }
  }

  /// Flush and stop. Call from the host app's lifecycle teardown.
  Future<void> dispose() async {
    await flush();
    _timer?.cancel();
    _timer = null;
  }

  /// Drop the oldest events once the buffer exceeds [maxBuffer].
  void _trim() {
    if (_buffer.length > maxBuffer) {
      _buffer.removeRange(0, _buffer.length - maxBuffer);
    }
  }

  @visibleForTesting
  int get bufferedCount => _buffer.length;
}
