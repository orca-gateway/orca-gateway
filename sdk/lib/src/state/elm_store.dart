import 'dart:async';
import 'dart:collection' show UnmodifiableMapView;
import 'package:flutter/foundation.dart';
import '../debug/orca_debug.dart';
import '../debug/debug_events.dart';

/// Elm-style state store backed by a flat key-value map.
///
/// Each store holds a `Map<String, dynamic>` and notifies listeners
/// whenever [dispatch] is called with an update.
class ElmStore extends ChangeNotifier {
  Map<String, dynamic> _state;
  String? pageId;
  String scope;

  /// Pending debug state changes to be flushed in the next microtask.
  List<DebugStateEvent>? _pendingDebugEvents;
  bool _debugFlushScheduled = false;

  ElmStore({Map<String, dynamic>? initial, this.pageId, this.scope = 'page'})
      : _state = Map<String, dynamic>.from(initial ?? {});

  /// Current snapshot of the state (unmodifiable — use [dispatch] to mutate).
  Map<String, dynamic> get state => UnmodifiableMapView(_state);

  /// Read a single key from the store.
  dynamic get(String key) => _state[key];

  /// Apply an update map — merges keys into the current state and notifies.
  void dispatch(Map<String, dynamic> update) {
    if (OrcaDebug.isEnabled && pageId != null) {
      for (final entry in update.entries) {
        final oldValue = _state[entry.key];
        if (!identical(oldValue, entry.value)) {
          _pendingDebugEvents ??= [];
          _pendingDebugEvents!.add(DebugStateEvent(
            scope: scope,
            pageId: pageId!,
            key: entry.key,
            oldValue: oldValue,
            newValue: entry.value,
          ));
        }
      }
      _scheduleDebugFlush();
    }
    _state = {..._state, ...update};
    notifyListeners();
  }

  /// Take [keys] out of the state and notify, when any of them is there.
  void removeKeys(Iterable<String> keys) {
    final present = keys.where(_state.containsKey).toSet();
    if (present.isEmpty) return;
    _state = {
      for (final entry in _state.entries)
        if (!present.contains(entry.key)) entry.key: entry.value,
    };
    notifyListeners();
  }

  void _scheduleDebugFlush() {
    if (_debugFlushScheduled || _pendingDebugEvents == null) return;
    _debugFlushScheduled = true;
    scheduleMicrotask(() {
      _debugFlushScheduled = false;
      final events = _pendingDebugEvents;
      _pendingDebugEvents = null;
      if (events == null) return;
      final instance = OrcaDebug.instance;
      if (instance == null) return;
      for (final event in events) {
        instance.reportStateChange(event);
      }
    });
  }
}
