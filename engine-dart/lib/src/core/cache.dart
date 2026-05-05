import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Cache provider interface.
abstract class CacheProvider {
  Future<String?> get(String key);
  Future<void> set(String key, String value, [int? ttlSeconds]);
  Future<void> del(String key);
  Future<void> flush();
}

/// In-memory cache with TTL support.
class InMemoryCacheProvider implements CacheProvider {
  final _store = <String, _CacheEntry>{};

  @override
  Future<String?> get(String key) async {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.expiresAt != null &&
        DateTime.now().isAfter(entry.expiresAt!)) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  @override
  Future<void> set(String key, String value, [int? ttlSeconds]) async {
    _store[key] = _CacheEntry(
      value: value,
      expiresAt: ttlSeconds != null
          ? DateTime.now().add(Duration(seconds: ttlSeconds))
          : null,
    );
  }

  @override
  Future<void> del(String key) async => _store.remove(key);

  @override
  Future<void> flush() async => _store.clear();
}

class _CacheEntry {
  final String value;
  final DateTime? expiresAt;
  const _CacheEntry({required this.value, this.expiresAt});
}

/// No-op cache for policy: "none".
class NoOpCache implements CacheProvider {
  @override
  Future<String?> get(String key) async => null;
  @override
  Future<void> set(String key, String value, [int? ttlSeconds]) async {}
  @override
  Future<void> del(String key) async {}
  @override
  Future<void> flush() async {}
}

/// Resolved cache configuration.
class ResolvedCacheConfig {
  final bool enabled;
  final int ttl;
  final List<String>? requestInfoKeys;
  final List<String>? pageStateKeys;
  final List<String>? appStateKeys;

  const ResolvedCacheConfig({
    this.enabled = false,
    this.ttl = 60,
    this.requestInfoKeys,
    this.pageStateKeys,
    this.appStateKeys,
  });
}

/// Generate an ETag from a response body.
String generateETag(String body) {
  final hash = md5.convert(utf8.encode(body)).toString();
  return '"$hash"';
}

/// Build a cache key from page ID, policy, and request sources.
String buildCacheKey({
  required String pageId,
  Map<String, dynamic>? requestInfo,
  Map<String, dynamic>? pageState,
  Map<String, dynamic>? appState,
  String? capsHash,
}) {
  final parts = <String>[pageId];
  if (requestInfo != null && requestInfo.isNotEmpty) {
    parts.add('ri:${_hashMap(requestInfo)}');
  }
  if (pageState != null && pageState.isNotEmpty) {
    parts.add('ps:${_hashMap(pageState)}');
  }
  if (appState != null && appState.isNotEmpty) {
    parts.add('as:${_hashMap(appState)}');
  }
  if (capsHash != null) parts.add('caps:$capsHash');
  return parts.join('|');
}

String _hashMap(Map<String, dynamic> m) {
  final json = jsonEncode(m);
  return md5.convert(utf8.encode(json)).toString().substring(0, 8);
}
