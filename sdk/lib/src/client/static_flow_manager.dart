import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/page_response.dart';

/// Manages local caching of static flow data for offline support.
///
/// Uses an in-memory cache for hot-path lookups (page navigation)
/// and SharedPreferences as cold storage for persistence across app restarts.
class StaticFlowManager {
  static const _configKey = 'orca_nav_config';
  static const _versionsKey = 'orca_flow_versions';
  static const _pagesPrefix = 'orca_pages_';

  final SharedPreferencesAsync _prefs;

  // ── In-memory caches (hot path) ─────────────────────────
  final Map<String, Map<String, PageResponse>> _pageCache = {};
  Map<String, int>? _versionsCache;
  Set<String>? _dynamicPaths;

  /// Create a StaticFlowManager. Optionally inject a SharedPreferencesAsync for testing.
  StaticFlowManager({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  /// Pre-compute the set of dynamic route paths from the given flows.
  /// Call once after config is loaded to avoid per-navigation allocation.
  void initDynamicPaths(List<NavFlow> flows) {
    _dynamicPaths = {};
    for (final flow in flows) {
      if (!flow.isStatic) continue;
      _collectDynamicPaths(flow.routes, _dynamicPaths!);
    }
  }

  void _collectDynamicPaths(List<NavRoute> routes, Set<String> out) {
    for (final route in routes) {
      if (route.isDynamic) {
        // Normalize: strip leading slash for consistent matching
        final path = route.path.startsWith('/') ? route.path.substring(1) : route.path;
        out.add(path);
      }
      if (route.children.isNotEmpty) {
        _collectDynamicPaths(route.children, out);
      }
    }
  }

  /// Save the raw NavConfig JSON string to local storage.
  /// Accepts the raw JSON string directly to avoid a redundant encode cycle.
  Future<void> saveConfigRaw(String rawJson) async {
    await _prefs.setString(_configKey, rawJson);
  }

  /// Load cached NavConfig from local storage.
  Future<NavConfig?> loadConfig() async {
    final raw = await _prefs.getString(_configKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return NavConfig.fromJson(json);
  }

  /// Save pre-rendered pages for a static flow.
  /// Also populates the in-memory cache.
  Future<void> saveFlowPages(
    String flowName,
    Map<String, PageResponse> pages,
  ) async {
    _pageCache[flowName] = pages;
    final encoded = pages.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.setString('$_pagesPrefix$flowName', jsonEncode(encoded));
  }

  /// Load cached pages for a flow. Returns from memory if available.
  Future<Map<String, PageResponse>?> loadFlowPages(String flowName) async {
    final mem = _pageCache[flowName];
    if (mem != null) return mem;

    final raw = await _prefs.getString('$_pagesPrefix$flowName');
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final pages = map.map(
      (k, v) => MapEntry(k, PageResponse.fromJson(v as Map<String, dynamic>)),
    );
    _pageCache[flowName] = pages;
    return pages;
  }

  /// Get locally stored flow versions. Returns from memory if available.
  Future<Map<String, int>> getLocalVersions() async {
    if (_versionsCache != null) return _versionsCache!;
    final raw = await _prefs.getString(_versionsKey);
    if (raw == null) return {};
    _versionsCache = (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, v as int));
    return _versionsCache!;
  }

  /// Save flow versions locally.
  Future<void> saveVersions(Map<String, int> versions) async {
    _versionsCache = versions;
    await _prefs.setString(_versionsKey, jsonEncode(versions));
  }

  /// Get a cached PageResponse for a specific path.
  /// Uses in-memory cache — no JSON deserialization on the hot path.
  /// Returns null for dynamic routes (they always fetch fresh).
  Future<PageResponse?> getCachedPage(
    String path,
    List<NavFlow> flows,
  ) async {
    // O(1) check for dynamic routes using pre-computed set
    if (_dynamicPaths != null && _dynamicPaths!.contains(path)) return null;

    for (final flow in flows) {
      if (!flow.isStatic) continue;
      final pages = await loadFlowPages(flow.name);
      if (pages != null && pages.containsKey(path)) {
        return pages[path];
      }
    }
    return null;
  }

  /// Save all static flows from a NavConfig response and clean up removed ones.
  /// Writes are parallelized for minimal latency.
  Future<void> cacheStaticFlows(NavConfig config) async {
    final currentFlowNames = <String>{};
    final versions = <String, int>{};
    final futures = <Future>[];

    for (final flow in config.flows) {
      currentFlowNames.add(flow.name);
      if (flow.version != null) {
        versions[flow.name] = flow.version!;
      }
      if (flow.isStatic && flow.pages != null) {
        futures.add(saveFlowPages(flow.name, flow.pages!));
      }
    }

    // Clean up page caches for flows removed from server
    final oldVersions = await getLocalVersions();
    for (final oldFlowName in oldVersions.keys) {
      if (!currentFlowNames.contains(oldFlowName)) {
        _pageCache.remove(oldFlowName);
        futures.add(_prefs.remove('$_pagesPrefix$oldFlowName'));
      }
    }

    futures.add(saveVersions(versions));
    await Future.wait(futures);
  }

  /// Clear all cached data (memory + disk).
  Future<void> clearAll() async {
    _pageCache.clear();
    _versionsCache = null;
    _dynamicPaths = null;

    final keys = await _prefs.getKeys();
    final futures = keys
        .where((k) => k.startsWith(_pagesPrefix))
        .map((k) => _prefs.remove(k))
        .toList();
    futures.add(_prefs.remove(_configKey));
    futures.add(_prefs.remove(_versionsKey));
    await Future.wait(futures);
  }
}
