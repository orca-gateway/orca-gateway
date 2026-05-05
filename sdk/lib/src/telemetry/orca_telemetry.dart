import 'package:flutter/foundation.dart';

/// Minimal telemetry hook for Epic 25b foundation slice.
///
/// The SDK needs to report "I encountered a component type I don't know how
/// to render" to some outer observer (typically the cloud app-server, via
/// an analytics pipeline wired up in a later slice). This file is that hook
/// kept as small as possible:
///
///   - A static callback [onEvent] that the host app sets once at startup.
///     Callers that don't wire a handler (e.g. self-hosters, unit tests)
///     silently no-op.
///   - Session-scope dedup via a static [Set] so the same unknown type
///     doesn't spam the callback a thousand times per page render.
///   - A test hook [resetForTesting] that clears dedup state between tests.
///
/// "Session" is deliberately defined as process lifetime — matching a static
/// field. If a later slice introduces a per-user session concept, it can
/// replace this with an instance-scoped store without breaking the callsite
/// contract: tests and renderer continue to call
/// [reportUnknownWidgetOnce] and don't care how dedup is implemented.
class OrcaTelemetry {
  OrcaTelemetry._();

  /// Host-provided event sink. Leave null to disable telemetry reporting —
  /// the dedup logic still runs so [resetForTesting] semantics are stable.
  ///
  /// Signature: `(event, data) -> void`. Known events so far:
  ///   - `'unknown_widget_type'` — `data == {'type': '<componentType>'}`
  static void Function(String event, Map<String, dynamic> data)? onEvent;

  static final Set<String> _reportedUnknownTypes = <String>{};

  /// Report an unknown component type at most once per session. Subsequent
  /// calls with the same [type] are silently ignored. See Epic 25b task 25b.9.
  static void reportUnknownWidgetOnce(String type) {
    if (_reportedUnknownTypes.add(type)) {
      onEvent?.call('unknown_widget_type', <String, dynamic>{'type': type});
    }
  }

  /// Clear session dedup state. Intended for unit tests only — clearing in
  /// production would cause duplicate reports on the first recurrence of
  /// every unknown type, defeating the point of the dedup.
  @visibleForTesting
  static void resetForTesting() {
    _reportedUnknownTypes.clear();
  }
}
