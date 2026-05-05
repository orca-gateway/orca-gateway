import 'package:shelf/shelf.dart' as shelf;

import '../types/context.dart';

/// Extract RequestInfo from shelf Request x-orca-* headers.
RequestInfo extractRequestInfo(
  shelf.Request req,
  Map<String, String> routeParams,
) {
  String? h(String name) => req.headers[name];
  double? hd(String name) {
    final v = h(name);
    return v != null ? double.tryParse(v) : null;
  }

  // Parse query params from URL.
  final queryParams = <String, String>{};
  for (final entry in req.url.queryParameters.entries) {
    queryParams[entry.key] = entry.value;
  }

  // Capability negotiation headers.
  ClientCapabilitiesRef? caps;
  final sdkVersion = h('x-orca-sdk-version');
  final capsHash = h('x-orca-caps-hash');
  if (sdkVersion != null || capsHash != null) {
    caps = ClientCapabilitiesRef(sdkVersion: sdkVersion, hash: capsHash);
  }

  return RequestInfo(
    // Device
    platform: h('x-orca-platform'),
    osVersion: h('x-orca-os-version'),
    deviceModel: h('x-orca-device-model'),
    appVersion: h('x-orca-app-version'),
    buildNumber: h('x-orca-build-number'),
    // Screen
    screenWidth: hd('x-orca-screen-width'),
    screenHeight: hd('x-orca-screen-height'),
    pixelDensity: hd('x-orca-pixel-density'),
    safeAreaTop: hd('x-orca-safe-area-top'),
    safeAreaBottom: hd('x-orca-safe-area-bottom'),
    safeAreaLeft: hd('x-orca-safe-area-left'),
    safeAreaRight: hd('x-orca-safe-area-right'),
    // Localization
    locale: h('x-orca-locale'),
    timezone: h('x-orca-timezone'),
    language: h('x-orca-language'),
    // Network
    networkType: h('x-orca-network-type'),
    ipAddress: req.headers['x-forwarded-for'] ?? req.headers['x-real-ip'],
    // Route
    routePath: '/${req.url.path}',
    routeParams: routeParams,
    queryParams: queryParams,
    // Auth
    authToken: _extractBearerToken(h('authorization')),
    userId: h('x-orca-user-id'),
    // Capabilities
    clientCapabilities: caps,
  );
}

String? _extractBearerToken(String? auth) {
  if (auth == null) return null;
  if (auth.startsWith('Bearer ')) return auth.substring(7);
  return null;
}
