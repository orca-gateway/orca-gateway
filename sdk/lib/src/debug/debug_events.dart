import 'timing_collector.dart';

class DebugTimingEvent {
  final String pageId;
  final String path;
  final CombinedTimingData timing;

  DebugTimingEvent(
      {required this.pageId, required this.path, required this.timing});

  Map<String, dynamic> toJson() => {
        'pageId': pageId,
        'path': path,
        ...timing.toJson(),
      };
}

class DebugStateEvent {
  final String scope;
  final String pageId;
  final String key;
  final dynamic oldValue;
  final dynamic newValue;

  DebugStateEvent(
      {required this.scope,
      required this.pageId,
      required this.key,
      this.oldValue,
      this.newValue});

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'pageId': pageId,
        'key': key,
        'oldValue': oldValue,
        'newValue': newValue,
      };
}

/// Coarse classification used by the DevTools Actions panel. Added in
/// protocol v2 so the UI no longer needs to infer it from [actionType].
/// Valid values: `navigation`, `state`, `ui-feedback`, `data`, `lifecycle`,
/// `custom`.
String inferActionFamily(String actionType) {
  const exact = {
    'setState': 'state',
    'navigate': 'navigation',
    'goBack': 'navigation',
    'switchTab': 'navigation',
    'showSnackbar': 'ui-feedback',
    'showToast': 'ui-feedback',
    'openDrawer': 'ui-feedback',
    'serverAction': 'data',
    'actionGroup': 'lifecycle',
    'conditionalAction': 'data',
    'openUrl': 'ui-feedback',
    'copyToClipboard': 'ui-feedback',
    'share': 'ui-feedback',
    'updateComponent': 'state',
    'deleteComponent': 'state',
    'addComponent': 'state',
    'replaceComponent': 'state',
  };
  if (exact.containsKey(actionType)) return exact[actionType]!;
  final upper = actionType.toUpperCase();
  if (upper.startsWith('NAVIGATE') ||
      upper.startsWith('GO_') ||
      upper.contains('ROUTE')) {
    return 'navigation';
  }
  if (upper.startsWith('SET_') ||
      upper.startsWith('UPDATE_') ||
      upper.startsWith('TOGGLE_')) {
    return 'state';
  }
  if (upper.contains('TOAST') ||
      upper.contains('SNACKBAR') ||
      upper.contains('MODAL') ||
      upper.contains('ALERT') ||
      upper.contains('SCROLL')) {
    return 'ui-feedback';
  }
  if (upper.startsWith('APP_') ||
      upper.contains('LIFECYCLE') ||
      upper.contains('AUTH_')) {
    return 'lifecycle';
  }
  if (upper.contains('FETCH') ||
      upper.contains('LOAD') ||
      upper.contains('CART') ||
      upper.contains('SUBMIT') ||
      upper.contains('APPLY_')) {
    return 'data';
  }
  return 'custom';
}

class DebugActionEvent {
  final String actionType;
  final String family;
  final Map<String, dynamic>? actionData;
  final String pageId;
  final double durationMs;
  final List<Map<String, dynamic>>? transformTrace;
  final List<Map<String, dynamic>>? affectedWidgets;

  DebugActionEvent({
    required this.actionType,
    required this.pageId,
    required this.durationMs,
    String? family,
    this.actionData,
    this.transformTrace,
    this.affectedWidgets,
  }) : family = family ?? inferActionFamily(actionType);

  Map<String, dynamic> toJson() => {
        'actionType': actionType,
        'family': family,
        'pageId': pageId,
        'data': actionData,
        'durationMs': durationMs,
        if (transformTrace != null && transformTrace!.isNotEmpty)
          'transformTrace': transformTrace,
        if (affectedWidgets != null && affectedWidgets!.isNotEmpty)
          'affectedWidgets': affectedWidgets,
      };
}

/// One measured phase of a network request. Added in protocol v2.
/// Standard phase names follow the browser-devtools convention:
/// `dns`, `connect`, `tls`, `request`, `wait`, `download`. Unmeasured
/// phases are simply omitted; DevTools renders whichever phases arrive.
class NetworkPhase {
  final String phase;
  final double durationMs;

  const NetworkPhase({required this.phase, required this.durationMs});

  Map<String, dynamic> toJson() => {
        'phase': phase,
        'durationMs': durationMs,
      };
}

class DebugNetworkEvent {
  final String method;
  final String url;
  final int statusCode;
  final double durationMs;
  final int? requestSizeBytes;
  final int? responseSizeBytes;
  final Map<String, String>? requestHeaders;
  final Map<String, String>? responseHeaders;

  /// Per-phase timings (protocol v2). Empty if the SDK couldn't measure.
  final List<NetworkPhase>? phases;

  /// Request body, populated only when [OrcaDebugConfig.includeBodies] is set.
  final dynamic requestBody;

  /// Response body, populated only when [OrcaDebugConfig.includeBodies] is set.
  final dynamic responseBody;

  DebugNetworkEvent({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.durationMs,
    this.requestSizeBytes,
    this.responseSizeBytes,
    this.requestHeaders,
    this.responseHeaders,
    this.phases,
    this.requestBody,
    this.responseBody,
  });

  Map<String, dynamic> toJson() => {
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'durationMs': durationMs,
        if (requestSizeBytes != null) 'requestSizeBytes': requestSizeBytes,
        if (responseSizeBytes != null) 'responseSizeBytes': responseSizeBytes,
        if (requestHeaders != null && requestHeaders!.isNotEmpty)
          'requestHeaders': requestHeaders,
        if (responseHeaders != null && responseHeaders!.isNotEmpty)
          'responseHeaders': responseHeaders,
        if (phases != null && phases!.isNotEmpty)
          'phases': [for (final p in phases!) p.toJson()],
        if (requestBody != null) 'requestBody': requestBody,
        if (responseBody != null) 'responseBody': responseBody,
      };
}

class DebugWidgetRebuildEvent {
  final String widgetId;
  final String widgetType;
  final List<String> watches;
  final Map<String, List<Map<String, dynamic>>> propTraces;

  DebugWidgetRebuildEvent({
    required this.widgetId,
    required this.widgetType,
    required this.watches,
    required this.propTraces,
  });

  Map<String, dynamic> toJson() => {
        'widgetId': widgetId,
        'widgetType': widgetType,
        'watches': watches,
        'propTraces': propTraces,
      };
}

class DebugErrorEvent {
  final String message;
  final String? stackTrace;
  final String? context;

  DebugErrorEvent({required this.message, this.stackTrace, this.context});

  Map<String, dynamic> toJson() => {
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (context != null) 'context': context,
      };
}
