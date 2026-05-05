import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:http/http.dart' as http;
import '../capabilities/generated.dart';
import '../debug/orca_debug.dart';
import '../debug/debug_events.dart';
import '../debug/timing_collector.dart';
import '../models/page_response.dart' show PageResponse, NavConfig, ActionResponse, VersionResponse;
import 'offline_session_store.dart';

/// HTTP client for communicating with the Orca Gateway engine.
class OrcaClient {
  final String baseUrl;
  final String? apiKey;
  final String? environment;
  final http.Client _client;
  final Duration timeout;

  OrcaClient({
    required this.baseUrl,
    this.apiKey,
    this.environment,
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  }) : _client = client ?? http.Client();

  ClientTimingCollector? _lastTimingCollector;
  String? _lastTimingHeader;

  ClientTimingCollector? get lastTimingCollector => _lastTimingCollector;
  String? get lastTimingHeader => _lastTimingHeader;

  Map<String, String>? _cachedDeviceHeaders;
  String? _cachedCapsHash;

  /// Additional widget types contributed by registered plugins. Folded into
  /// the capability vector so the server's fallback policy doesn't strip
  /// plugin widgets from the rendered tree. Populated by OrcaApp during
  /// boot before the first page / config fetch fires.
  final Set<String> _extraWidgets = <String>{};

  /// Additional action kinds contributed by plugins (e.g. `moveCamera` for
  /// an OSM plugin). Server-side capability filter uses this to permit
  /// action groups that reference plugin actions.
  final Set<String> _extraActions = <String>{};

  /// Register plugin-contributed widget types and action kinds. Invalidates
  /// any cached caps hash / device headers so the next request advertises
  /// the updated vector. Idempotent — safe to call multiple times.
  ///
  /// For each action name passed in, we advertise BOTH the bare name AND
  /// the `custom:`-prefixed form. Plugin authors register their Dart
  /// handlers under bare names (e.g. `moveCamera`), but `CustomAction.type`
  /// is TS-typed as `custom:${string}` so the wire-format ships with the
  /// prefix. The server's capability-filter matches `action.type` against
  /// `support.actionKinds` literally, so advertising both forms covers
  /// both wire shapes regardless of whether individual plugins prefix
  /// their action types at serialization time.
  void registerCapabilityExtensions({
    Iterable<String> widgets = const [],
    Iterable<String> actions = const [],
  }) {
    final before = _extraWidgets.length + _extraActions.length;
    _extraWidgets.addAll(widgets);
    for (final action in actions) {
      _extraActions.add(action);
      if (!action.startsWith('custom:')) {
        _extraActions.add('custom:$action');
      }
    }
    final after = _extraWidgets.length + _extraActions.length;
    if (after != before) {
      _cachedCapsHash = null;
      _cachedDeviceHeaders = null;
    }
  }

  /// Build device info headers from the current Flutter environment, merged
  /// with capability negotiation headers (Epic 25b slice 2). Computed once
  /// and cached — both the device environment and the SDK's capability
  /// vector are immutable for the client's lifetime.
  Map<String, String> _deviceHeaders() {
    if (_cachedDeviceHeaders != null) return _cachedDeviceHeaders!;
    _cachedDeviceHeaders = <String, String>{
      ..._computeDeviceHeaders(),
      ..._capabilityHeaders(),
    };
    return _cachedDeviceHeaders!;
  }

  /// Capability negotiation headers (Epic 25b slice 2).
  ///
  /// Every request advertises the SDK's semver + the sha256 hash of its
  /// canonical capability vector. The server uses these to:
  ///   1. Filter the rendered tree via capability-aware policy resolution.
  ///   2. Key its render cache by caps hash so two SDK versions never share
  ///      a cache entry.
  ///
  /// The hash is computed once per client instance and cached — the
  /// capability vector is baked into the SDK at build time and can't change
  /// at runtime, so the hash is effectively a compile-time constant.
  Map<String, String> _capabilityHeaders() {
    final hash = _cachedCapsHash ??= _computeCapsHash();
    return <String, String>{
      'x-orca-sdk-version': kSdkSemver,
      'x-orca-caps-hash': hash,
    };
  }

  /// Canonical serialization of the SDK's capability vector. MUST match the
  /// server's `canonicalizeVector()` in open-source/engine/src/core/capability-vector-cache.ts
  /// bit-for-bit — a mismatch desyncs the hash and every request perma-412s
  /// into the retry path, burning bandwidth.
  ///
  /// Canonical form (keys in this exact order, arrays sorted ascending):
  ///   { protocolVersion, sdkSemver, widgets, valueKinds, actionKinds,
  ///     transformKinds, boolExprOps }
  String _canonicalCapabilityVectorJson() {
    // Union compile-time core set with any plugin-registered extensions.
    // Sorted ascending to keep the canonical form stable.
    final widgets = (<String>{...kSupportedWidgets, ..._extraWidgets}.toList()
      ..sort());
    final actions =
        (<String>{...kSupportedActionKinds, ..._extraActions}.toList()..sort());
    final canonical = <String, dynamic>{
      'protocolVersion': kProtocolVersion,
      'sdkSemver': kSdkSemver,
      'widgets': widgets,
      'valueKinds': (kSupportedValueKinds.toList()..sort()),
      'actionKinds': actions,
      'transformKinds': (kSupportedTransformKinds.toList()..sort()),
      'boolExprOps': (kSupportedBoolExprOps.toList()..sort()),
    };
    return jsonEncode(canonical);
  }

  String _computeCapsHash() {
    final canonical = _canonicalCapabilityVectorJson();
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// The full capability vector (used in 412 retry bodies). Recomputed each
  /// time — cheap (a handful of list sorts) and called at most once per
  /// client instance, so caching adds complexity for no savings. Must
  /// include plugin-contributed extensions so the server's canonicalization
  /// matches the client's hash byte-for-byte.
  Map<String, dynamic> _capabilityVector() {
    final base = SdkCapabilities.toVector();
    if (_extraWidgets.isEmpty && _extraActions.isEmpty) return base;
    final widgets = <String>{
      ...(base['widgets'] as List).cast<String>(),
      ..._extraWidgets,
    }.toList()
      ..sort();
    final actions = <String>{
      ...(base['actionKinds'] as List).cast<String>(),
      ..._extraActions,
    }.toList()
      ..sort();
    return <String, dynamic>{
      ...base,
      'widgets': widgets,
      'actionKinds': actions,
    };
  }

  /// Send a page render request with 412 retry support (Epic 25b slice 2).
  ///
  /// First attempt: hash-only headers, identical to the pre-25b request
  /// shape (GET for no appState, POST with {appState} body otherwise). If
  /// the server's vector cache has the hash, we're done in one round-trip.
  ///
  /// On 412 `{error: "caps_vector_unknown"}`: retry exactly once with the
  /// full capability vector in a POST body under `_orcaCapsVector`. The
  /// second request is always a POST — even when the first was a GET —
  /// because the vector has to travel in the body.
  ///
  /// Hard invariant: max one retry. A second 412 after we've sent the
  /// vector indicates a bug (canonicalization drift, server-side bug) and
  /// must not be retried further.
  Future<http.Response> _sendPageRequestWithCapsRetry({
    required Uri uri,
    required Map<String, String> baseHeaders,
    required Map<String, dynamic>? appState,
  }) async {
    // First attempt — matches pre-25b shape except for the added caps
    // headers (now merged into _deviceHeaders). The server happily ignores
    // them when negotiation is disabled.
    http.Response response;
    if (appState != null && appState.isNotEmpty) {
      response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', ...baseHeaders},
        body: jsonEncode({'appState': appState}),
      );
    } else {
      response = await _client.get(uri, headers: baseHeaders);
    }

    if (response.statusCode != 412) return response;

    // Inspect the body: we only retry on the specific caps_vector_unknown
    // error. Any other 412 is passed through to the caller unchanged so
    // application-level 412 semantics (If-Match etc.) still work.
    final String? errorField = _parseErrorField(response.body);
    if (errorField != 'caps_vector_unknown') return response;

    // Retry with the full vector in the body. We always POST on retry —
    // the vector must travel somewhere, and query-string encoding a 5KB
    // JSON blob is a footgun.
    final retryBody = <String, dynamic>{
      '_orcaCapsVector': _capabilityVector(),
      if (appState != null && appState.isNotEmpty) 'appState': appState,
    };
    response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json', ...baseHeaders},
      body: jsonEncode(retryBody),
    );

    // If the retry itself returns 412, fall through to the caller. The
    // caller's existing "if statusCode != 200 throw" branch will turn it
    // into an OrcaClientException with the server's error body attached —
    // which is the right surface for surfacing a canonicalization bug.
    return response;
  }

  /// Best-effort parse of a JSON error body shaped `{"error": "..."}`.
  /// Returns null when the body isn't JSON or doesn't have an `error` field.
  static String? _parseErrorField(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is String) return err;
      }
    } catch (_) {}
    return null;
  }

  Map<String, String> _computeDeviceHeaders() {
    final headers = <String, String>{};
    try {
      headers['x-orca-platform'] = Platform.isIOS ? 'iOS' : 'Android';
      headers['x-orca-os-version'] = Platform.operatingSystemVersion;
    } catch (_) {
      headers['x-orca-platform'] = 'iOS';
    }
    try {
      final binding = WidgetsBinding.instance;
      final view = binding.platformDispatcher.views.first;
      final size = view.physicalSize;
      final ratio = view.devicePixelRatio;
      final padding = view.padding;
      headers['x-orca-screen-width'] = (size.width / ratio).toStringAsFixed(0);
      headers['x-orca-screen-height'] = (size.height / ratio).toStringAsFixed(0);
      headers['x-orca-pixel-density'] = ratio.toStringAsFixed(1);
      headers['x-orca-safe-top'] = (padding.top / ratio).toStringAsFixed(0);
      headers['x-orca-safe-bottom'] = (padding.bottom / ratio).toStringAsFixed(0);
      headers['x-orca-safe-left'] = (padding.left / ratio).toStringAsFixed(0);
      headers['x-orca-safe-right'] = (padding.right / ratio).toStringAsFixed(0);
    } catch (_) {}
    try {
      final locale = PlatformDispatcher.instance.locale;
      headers['x-orca-locale'] = '${locale.languageCode}_${locale.countryCode ?? ''}';
      headers['x-orca-timezone'] = DateTime.now().timeZoneName;
    } catch (_) {}
    if (apiKey != null) {
      headers['Authorization'] = 'Bearer ${apiKey!}';
    }
    if (environment != null) {
      headers['X-Orca-Env'] = environment!;
    }
    return headers;
  }

  /// Fetch a rendered page from the engine.
  Future<PageResponse> fetchPage(
    String appId,
    String path, {
    Map<String, dynamic>? appState,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/app/$appId/page/$path');
    // _deviceHeaders() already includes capability negotiation headers
    // (Epic 25b slice 2): x-orca-sdk-version + x-orca-caps-hash.
    final device = _deviceHeaders();

    ClientTimingCollector? timingCollector;
    final debugHeaders = <String, String>{};
    if (OrcaDebug.isEnabled) {
      timingCollector = ClientTimingCollector();
      timingCollector.mark('requestStart');
      debugHeaders['X-Orca-Debug'] = 'true';
    }

    final requestMethod = (appState != null && appState.isNotEmpty) ? 'POST' : 'GET';
    final requestHeaders = <String, String>{...device, ...debugHeaders};

    // Send the request. If the server returns 412 caps_vector_unknown, retry
    // exactly once with the full capability vector in the body so the server
    // can populate its vector cache. A second 412 means something is broken
    // (canonicalization drift or server bug) — passing the second response
    // through lets the caller's error-handling branch surface the problem
    // instead of looping.
    http.Response response;
    try {
      response = await _sendPageRequestWithCapsRetry(
        uri: uri,
        baseHeaders: requestHeaders,
        appState: appState,
      );
    } catch (error, stack) {
      _reportFailedRequest(
        uri: uri,
        method: requestMethod,
        requestHeaders: requestHeaders,
        appState: appState,
        timingCollector: timingCollector,
        error: error,
        stack: stack,
      );
      rethrow;
    }

    timingCollector?.mark('responseReceived');

    if (response.statusCode != 200) {
      _reportHttpErrorResponse(
        uri: uri,
        method: requestMethod,
        requestHeaders: requestHeaders,
        response: response,
        appState: appState,
        timingCollector: timingCollector,
      );
      throw OrcaClientException(
        'Failed to fetch page: ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    timingCollector?.mark('parseComplete');

    _lastTimingCollector = timingCollector;
    _lastTimingHeader = response.headers['x-orca-timing'];

    if (OrcaDebug.isEnabled && OrcaDebug.config.captureNetworkRequests) {
      final waitMs = timingCollector!.toData().responseReceivedMs;
      final includeBodies = OrcaDebug.config.includeBodies;
      OrcaDebug.instance?.reportNetwork(DebugNetworkEvent(
        method: requestMethod,
        url: uri.toString(),
        statusCode: response.statusCode,
        durationMs: waitMs,
        responseSizeBytes: response.contentLength,
        requestHeaders: _sanitizeHeaders(requestHeaders),
        responseHeaders: _sanitizeHeaders(response.headers),
        // Until we switch to `dart:io`'s HttpClient we can only measure the
        // aggregate time between issuing the request and receiving the
        // headers. DevTools renders whatever phases arrive, so a single
        // `wait` bar is honest and still useful.
        phases: [NetworkPhase(phase: 'wait', durationMs: waitMs)],
        requestBody: includeBodies ? appState : null,
        responseBody: includeBodies ? json : null,
      ));
    }

    return PageResponse.fromJson(json);
  }

  // ─── Debug error / failed-request reporting ────────────────────────
  //
  // When the transport itself fails (server down, DNS error, TLS handshake
  // failure, …) or when the server returns a non-200, the SDK emits both a
  // `network` event (with `statusCode: 0` for transport failures) so the
  // request still shows up in the DevTools Network tab, and an `error`
  // event so the Errors tab populates too.

  void _reportFailedRequest({
    required Uri uri,
    required String method,
    required Map<String, String> requestHeaders,
    required Map<String, dynamic>? appState,
    required ClientTimingCollector? timingCollector,
    required Object error,
    required StackTrace stack,
  }) {
    if (!OrcaDebug.isEnabled) return;
    final waitMs = timingCollector?.toData().responseReceivedMs ?? 0;
    if (OrcaDebug.config.captureNetworkRequests) {
      OrcaDebug.instance?.reportNetwork(DebugNetworkEvent(
        method: method,
        url: uri.toString(),
        statusCode: 0, // sentinel: transport-level failure
        durationMs: waitMs,
        requestHeaders: _sanitizeHeaders(requestHeaders),
        phases: [NetworkPhase(phase: 'wait', durationMs: waitMs)],
        requestBody: OrcaDebug.config.includeBodies ? appState : null,
      ));
    }
    OrcaDebug.instance?.reportError(DebugErrorEvent(
      message: 'Network request failed: $error',
      context: '$method ${uri.toString()}',
      stackTrace: stack.toString(),
    ));
  }

  void _reportHttpErrorResponse({
    required Uri uri,
    required String method,
    required Map<String, String> requestHeaders,
    required http.Response response,
    required Map<String, dynamic>? appState,
    required ClientTimingCollector? timingCollector,
  }) {
    if (!OrcaDebug.isEnabled) return;
    final waitMs = timingCollector?.toData().responseReceivedMs ?? 0;
    if (OrcaDebug.config.captureNetworkRequests) {
      OrcaDebug.instance?.reportNetwork(DebugNetworkEvent(
        method: method,
        url: uri.toString(),
        statusCode: response.statusCode,
        durationMs: waitMs,
        responseSizeBytes: response.contentLength,
        requestHeaders: _sanitizeHeaders(requestHeaders),
        responseHeaders: _sanitizeHeaders(response.headers),
        phases: [NetworkPhase(phase: 'wait', durationMs: waitMs)],
        requestBody: OrcaDebug.config.includeBodies ? appState : null,
        responseBody:
            OrcaDebug.config.includeBodies ? _tryDecodeJson(response.body) : null,
      ));
    }
    OrcaDebug.instance?.reportError(DebugErrorEvent(
      message: 'HTTP ${response.statusCode} ${uri.path}',
      context: '$method ${uri.toString()}',
      stackTrace: response.body,
    ));
  }

  static Map<String, String> _sanitizeHeaders(Map<String, String> raw) {
    // Drop credentials and cookies from both directions so debug streams
    // don't leak secrets onto a shared DevTools port.
    const redact = {
      'authorization',
      'cookie',
      'set-cookie',
      'x-api-key',
      'proxy-authorization',
    };
    final out = <String, String>{};
    raw.forEach((k, v) {
      out[k] = redact.contains(k.toLowerCase()) ? '<redacted>' : v;
    });
    return out;
  }

  static dynamic _tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  /// Fetch navigation configuration for an app.
  Future<NavConfig> fetchConfig(String appId) async {
    final uri = Uri.parse('$baseUrl/api/v1/app/$appId/config');
    final response = await _client.get(uri, headers: _deviceHeaders());

    if (response.statusCode != 200) {
      throw OrcaClientException(
        'Failed to fetch config: ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return NavConfig.fromJson(json, rawBody: response.body);
  }

  /// Execute a server action and return the response actions.
  Future<ActionResponse> executeAction(
    String appId, {
    required String action,
    Map<String, dynamic>? params,
    Map<String, dynamic>? pageState,
    Map<String, dynamic>? appState,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/app/$appId/action');
    final body = <String, dynamic>{
      'action': action,
      'params': ?params,
      'pageState': ?pageState,
      'appState': ?appState,
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json', ..._deviceHeaders()},
      body: jsonEncode(body),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw OrcaClientException(
        json['error'] as String? ?? 'Server action failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return ActionResponse.fromJson(json);
  }

  OfflineSessionStore? _offlineSessionStore;

  /// Set the offline session store for persisting sessions when offline.
  void setOfflineSessionStore(OfflineSessionStore store) {
    _offlineSessionStore = store;
  }

  /// Notify the engine that a session has started (app opened).
  /// Falls back to offline storage if the request fails.
  Future<void> sendSessionStart(String appId, {String? deviceId}) async {
    final uri = Uri.parse('$baseUrl/api/v1/app/$appId/session');
    final body = <String, dynamic>{
      'type': 'start',
      'deviceId': ?deviceId,
    };
    try {
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', ..._deviceHeaders()},
        body: jsonEncode(body),
      );
    } catch (_) {
      await _offlineSessionStore?.save('start');
    }
  }

  /// Notify the engine that a session has ended (app closed / backgrounded).
  /// Falls back to offline storage if the request fails.
  Future<void> sendSessionEnd(String appId, {String? deviceId}) async {
    final uri = Uri.parse('$baseUrl/api/v1/app/$appId/session');
    final body = <String, dynamic>{
      'type': 'end',
      'deviceId': ?deviceId,
    };
    try {
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', ..._deviceHeaders()},
        body: jsonEncode(body),
      );
    } catch (_) {
      await _offlineSessionStore?.save('end');
    }
  }

  /// Flush any offline sessions to the engine. Call when connectivity is restored.
  /// Returns true if flush succeeded (or nothing to flush), false on failure.
  Future<bool> flushOfflineSessions(String appId, {required String deviceId}) async {
    final store = _offlineSessionStore;
    if (store == null) return true;

    final records = await store.load();
    if (records.isEmpty) return true;

    final uri = Uri.parse('$baseUrl/api/v1/app/$appId/session/offline');
    final body = <String, dynamic>{
      'deviceId': deviceId,
      'sessions': records.map((r) => r.toJson()).toList(),
    };

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', ..._deviceHeaders()},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        await store.clear();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch flow version info from the engine.
  Future<VersionResponse> fetchVersion(String appId) async {
    final uri = Uri.parse('$baseUrl/api/v1/app/$appId/version');
    final response = await _client.get(uri, headers: _deviceHeaders());

    if (response.statusCode != 200) {
      throw OrcaClientException(
        'Failed to fetch version: ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return VersionResponse.fromJson(json);
  }

  void dispose() {
    _client.close();
  }
}

class OrcaClientException implements Exception {
  final String message;
  final int statusCode;
  final String body;

  const OrcaClientException(
    this.message, {
    required this.statusCode,
    required this.body,
  });

  @override
  String toString() => 'OrcaClientException($statusCode): $message';
}
