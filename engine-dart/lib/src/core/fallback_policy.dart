/// Fallback mode when an unsupported feature is encountered.
enum FallbackMode { graceful, warn, require }

FallbackMode parseFallbackMode(String? s) {
  switch (s) {
    case 'warn':
      return FallbackMode.warn;
    case 'require':
      return FallbackMode.require;
    default:
      return FallbackMode.graceful;
  }
}

/// Declarative policy config.
class FallbackPolicyConfig {
  final FallbackMode defaultMode;
  final Map<String, FallbackMode> features;

  const FallbackPolicyConfig({
    this.defaultMode = FallbackMode.graceful,
    this.features = const {},
  });

  factory FallbackPolicyConfig.fromJson(Map<String, dynamic> json) {
    final features = <String, FallbackMode>{};
    final rawFeatures = json['features'] as Map?;
    if (rawFeatures != null) {
      for (final entry in rawFeatures.entries) {
        features['${entry.key}'] = parseFallbackMode(entry.value as String?);
      }
    }
    return FallbackPolicyConfig(
      defaultMode: parseFallbackMode(json['default'] as String?),
      features: features,
    );
  }
}

/// Interface for policy resolution.
abstract class FallbackPolicyResolver {
  FallbackMode resolve(String featureKey);
}

class StaticPolicyResolver implements FallbackPolicyResolver {
  final FallbackMode _fallback;
  final Map<String, FallbackMode> _features;

  StaticPolicyResolver(FallbackPolicyConfig config)
      : _fallback = config.defaultMode,
        _features = config.features;

  @override
  FallbackMode resolve(String featureKey) {
    return _features[featureKey] ?? _fallback;
  }
}

FallbackPolicyResolver createStaticPolicyResolver([
  FallbackPolicyConfig config = const FallbackPolicyConfig(),
]) {
  return StaticPolicyResolver(config);
}

/// Precedence: require > warn > graceful.
FallbackMode highestSeverity(List<FallbackMode> modes) {
  if (modes.isEmpty) return FallbackMode.graceful;
  if (modes.contains(FallbackMode.require)) return FallbackMode.require;
  if (modes.contains(FallbackMode.warn)) return FallbackMode.warn;
  return FallbackMode.graceful;
}
