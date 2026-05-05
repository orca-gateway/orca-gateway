/// Context for the value resolver during pipeline execution.
class ValueResolverContext {
  final Map<String, dynamic> pageState;
  final Map<String, dynamic> appState;
  final dynamic infoData;
  final Map<String, dynamic> requestInfo;
  final Map<String, dynamic> config;

  const ValueResolverContext({
    this.pageState = const {},
    this.appState = const {},
    this.infoData,
    this.requestInfo = const {},
    this.config = const {},
  });

  factory ValueResolverContext.fromJson(Map<String, dynamic> json) {
    return ValueResolverContext(
      pageState: _asMap(json['pageState']),
      appState: _asMap(json['appState']),
      infoData: json['infoData'],
      requestInfo: _asMap(json['requestInfo']),
      config: _asMap(json['config']),
    );
  }
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

/// Capability vector advertised by the client SDK (Epic 25b).
class CapabilityVector {
  final String protocolVersion;
  final String sdkSemver;
  final List<String> widgets;
  final List<String> valueKinds;
  final List<String> actionKinds;
  final List<String> transformKinds;
  final List<String> boolExprOps;

  const CapabilityVector({
    required this.protocolVersion,
    required this.sdkSemver,
    required this.widgets,
    required this.valueKinds,
    required this.actionKinds,
    required this.transformKinds,
    required this.boolExprOps,
  });

  factory CapabilityVector.fromJson(Map<String, dynamic> json) {
    return CapabilityVector(
      protocolVersion: json['protocolVersion'] as String? ?? '1.0.0',
      sdkSemver: json['sdkSemver'] as String? ?? '0.0.0',
      widgets: List<String>.from(json['widgets'] as List? ?? []),
      valueKinds: List<String>.from(json['valueKinds'] as List? ?? []),
      actionKinds: List<String>.from(json['actionKinds'] as List? ?? []),
      transformKinds: List<String>.from(json['transformKinds'] as List? ?? []),
      boolExprOps: List<String>.from(json['boolExprOps'] as List? ?? []),
    );
  }
}

/// Client capabilities reference extracted from request headers.
class ClientCapabilitiesRef {
  final String? sdkVersion;
  final String? hash;
  CapabilityVector? vector;

  ClientCapabilitiesRef({this.sdkVersion, this.hash, this.vector});
}

/// Device, screen, locale, network, route, and auth information
/// extracted from x-orca-* headers.
class RequestInfo {
  // Device
  final String? platform;
  final String? osVersion;
  final String? deviceModel;
  final String? appVersion;
  final String? buildNumber;

  // Screen
  final double? screenWidth;
  final double? screenHeight;
  final double? pixelDensity;
  final double? safeAreaTop;
  final double? safeAreaBottom;
  final double? safeAreaLeft;
  final double? safeAreaRight;

  // Localization
  final String? locale;
  final String? timezone;
  final String? language;

  // Network
  final String? networkType;
  final String? ipAddress;

  // Route
  final String routePath;
  final Map<String, String> routeParams;
  final Map<String, String> queryParams;

  // Auth
  final String? authToken;
  final String? userId;

  // Capabilities
  final ClientCapabilitiesRef? clientCapabilities;

  const RequestInfo({
    this.platform,
    this.osVersion,
    this.deviceModel,
    this.appVersion,
    this.buildNumber,
    this.screenWidth,
    this.screenHeight,
    this.pixelDensity,
    this.safeAreaTop,
    this.safeAreaBottom,
    this.safeAreaLeft,
    this.safeAreaRight,
    this.locale,
    this.timezone,
    this.language,
    this.networkType,
    this.ipAddress,
    this.routePath = '/',
    this.routeParams = const {},
    this.queryParams = const {},
    this.authToken,
    this.userId,
    this.clientCapabilities,
  });

  /// Convert to a flat map for use as requestInfo in ValueResolverContext.
  Map<String, dynamic> toResolverMap() => {
        if (platform != null) 'platform': platform,
        if (osVersion != null) 'osVersion': osVersion,
        if (deviceModel != null) 'deviceModel': deviceModel,
        if (appVersion != null) 'appVersion': appVersion,
        if (buildNumber != null) 'buildNumber': buildNumber,
        if (screenWidth != null) 'screenWidth': screenWidth,
        if (screenHeight != null) 'screenHeight': screenHeight,
        if (pixelDensity != null) 'pixelDensity': pixelDensity,
        if (safeAreaTop != null) 'safeAreaTop': safeAreaTop,
        if (safeAreaBottom != null) 'safeAreaBottom': safeAreaBottom,
        if (safeAreaLeft != null) 'safeAreaLeft': safeAreaLeft,
        if (safeAreaRight != null) 'safeAreaRight': safeAreaRight,
        if (locale != null) 'locale': locale,
        if (timezone != null) 'timezone': timezone,
        if (language != null) 'language': language,
        if (networkType != null) 'networkType': networkType,
        if (ipAddress != null) 'ipAddress': ipAddress,
        'routePath': routePath,
        'routeParams': routeParams,
        'queryParams': queryParams,
        if (authToken != null) 'authToken': authToken,
        if (userId != null) 'userId': userId,
      };
}

/// Context passed to page lifecycle methods.
class PageContext {
  final RequestInfo requestInfo;
  final String pageId;
  final String routePath;
  final Map<String, String> routeParams;
  final Map<String, dynamic> pageState;
  final Map<String, dynamic> appState;

  const PageContext({
    required this.requestInfo,
    required this.pageId,
    required this.routePath,
    this.routeParams = const {},
    this.pageState = const {},
    this.appState = const {},
  });
}

/// Context passed to server action execute() handlers.
class ActionContext {
  final RequestInfo requestInfo;
  final Map<String, dynamic> pageState;
  final Map<String, dynamic> appState;
  final Map<String, dynamic> actionParams;

  const ActionContext({
    required this.requestInfo,
    this.pageState = const {},
    this.appState = const {},
    this.actionParams = const {},
  });
}
