import 'dart:io';

import 'package:yaml/yaml.dart';
import 'plugin_schema.dart';

/// A single `<meta-data>` entry for AndroidManifest.xml.
class ManifestMeta {
  final String name;
  final String value;

  ManifestMeta({required this.name, required this.value});

  factory ManifestMeta.fromYaml(YamlMap map) {
    return ManifestMeta(
      name: map['name'] as String,
      value: map['value'] as String,
    );
  }
}

/// A single `<key>/<value>` entry for Info.plist.
///
/// `value` is intentionally [dynamic] rather than [String] — plists support
/// nested structures (`<dict>`, `<array>`) and the YAML author may express
/// those as a nested YamlMap / YamlList. The CLI preserves the raw YAML
/// value here and the [PlistPatcher] is responsible for rendering it to
/// the right XML tag based on [type].
///
/// Scalar types (`string`, `bool`, `integer`) accept a YAML scalar; `dict`
/// accepts a YamlMap (or Map<String, dynamic>); `array` accepts a YamlList
/// of YAML values. See `PlistPatcher._plistValueTag` for the full mapping.
class PlistEntry {
  final String key;
  final dynamic value;
  final String type;

  PlistEntry({required this.key, required this.value, required this.type});

  factory PlistEntry.fromYaml(YamlMap map) {
    return PlistEntry(
      key: map['key'] as String,
      // Preserve the raw value — it may be a String, bool, int, YamlMap, or
      // YamlList. The patcher picks the rendering strategy from `type`.
      value: map['value'],
      type: (map['type'] as String?) ?? 'string',
    );
  }
}

/// An environment variable that a plugin requires.
class EnvVar {
  final String key;
  final String description;
  final bool required;
  final List<String> platforms;

  EnvVar({
    required this.key,
    required this.description,
    required this.required,
    required this.platforms,
  });

  factory EnvVar.fromYaml(YamlMap map) {
    return EnvVar(
      key: map['key'] as String,
      description: (map['description'] as String?) ?? '',
      required: (map['required'] as bool?) ?? true,
      platforms: (map['platforms'] as YamlList?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Android-specific configuration from the manifest.
class AndroidConfig {
  final int? minSdk;
  final List<String> permissions;
  final List<ManifestMeta> manifestMeta;
  final List<String> gradleDependencies;

  AndroidConfig({
    this.minSdk,
    this.permissions = const [],
    this.manifestMeta = const [],
    this.gradleDependencies = const [],
  });

  factory AndroidConfig.fromYaml(YamlMap map) {
    return AndroidConfig(
      minSdk: map['min_sdk'] as int?,
      permissions: (map['permissions'] as YamlList?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      manifestMeta: (map['manifest_meta'] as YamlList?)
              ?.map((e) => ManifestMeta.fromYaml(e as YamlMap))
              .toList() ??
          [],
      gradleDependencies: (map['gradle_dependencies'] as YamlList?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// iOS-specific configuration from the manifest.
class IosConfig {
  final String? minVersion;
  final List<PlistEntry> plist;
  final List<String> entitlements;
  final List<String> frameworks;

  IosConfig({
    this.minVersion,
    this.plist = const [],
    this.entitlements = const [],
    this.frameworks = const [],
  });

  factory IosConfig.fromYaml(YamlMap map) {
    return IosConfig(
      minVersion: map['min_version']?.toString(),
      plist: (map['plist'] as YamlList?)
              ?.map((e) => PlistEntry.fromYaml(e as YamlMap))
              .toList() ??
          [],
      entitlements: (map['entitlements'] as YamlList?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      frameworks: (map['frameworks'] as YamlList?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Flutter Web preview strategy declared by a plugin (Epic 38 Slice B).
///
/// Three mutually-exclusive modes:
///
///   * `declarative` — the plugin ships a TypeScript stub file composed of
///     core Orca Gateway widgets. `orca plugin build` runs it through the engine's
///     `flatten()` and writes a static ComponentNode[] JSON. The stock
///     preview editor renders the compiled JSON with no per-plugin rebuild.
///   * `webNative` — the plugin ships real Dart that runs inside a
///     per-composition preview editor build. Slice D wires this up.
///   * `none` — the plugin opts out of preview entirely; the renderer
///     substitutes the UnsupportedWidgetPlaceholder card instead.
enum PreviewKind { declarative, webNative, none }

/// Preview-section config parsed from `orca_plugin.yaml`.
class PreviewConfig {
  final PreviewKind kind;

  /// Path (relative to plugin root) of the TypeScript stub file. Only
  /// meaningful when [kind] is [PreviewKind.declarative]. Defaults to
  /// `preview/stub.ts` when absent.
  final String stubPath;

  /// Path (relative to plugin root) of the compiled JSON artifact emitted by
  /// `orca plugin build`. Committed into the plugin repo so consumers don't
  /// need a build step. Defaults to `preview/stub.compiled.json`.
  final String compiledStubPath;

  /// Path of the Dart entry for [PreviewKind.webNative] mode. Null otherwise.
  final String? entry;

  const PreviewConfig({
    required this.kind,
    this.stubPath = 'preview/stub.ts',
    this.compiledStubPath = 'preview/stub.compiled.json',
    this.entry,
  });

  factory PreviewConfig.fromYaml(YamlMap map) {
    final rawKind = map['kind'] as String?;
    if (rawKind == null) {
      throw FormatException(
        'preview.kind is required (declarative | web_native | none)',
      );
    }
    final kind = switch (rawKind) {
      'declarative' => PreviewKind.declarative,
      'web_native' => PreviewKind.webNative,
      'none' => PreviewKind.none,
      _ => throw FormatException(
          'preview.kind must be one of declarative, web_native, none '
          '(got "$rawKind")',
        ),
    };
    return PreviewConfig(
      kind: kind,
      stubPath: (map['stub'] as String?) ?? 'preview/stub.ts',
      compiledStubPath:
          (map['compiledStub'] as String?) ?? 'preview/stub.compiled.json',
      entry: map['entry'] as String?,
    );
  }
}

/// Marketplace icon set — all three sizes required for a marketplace-eligible
/// plugin listing.
class MarketplaceIcons {
  /// 32x32 PNG.
  final String small;

  /// 64x64 PNG.
  final String medium;

  /// 128x128 PNG.
  final String large;

  const MarketplaceIcons({
    required this.small,
    required this.medium,
    required this.large,
  });

  factory MarketplaceIcons.fromYaml(YamlMap map) {
    return MarketplaceIcons(
      small: map['small'] as String,
      medium: map['medium'] as String,
      large: map['large'] as String,
    );
  }
}

/// Single marketplace screenshot with an optional caption and YouTube link.
class MarketplaceScreenshot {
  final String path;
  final String? caption;
  final String? youtubeUrl;

  const MarketplaceScreenshot({
    required this.path,
    this.caption,
    this.youtubeUrl,
  });

  factory MarketplaceScreenshot.fromYaml(YamlMap map) {
    return MarketplaceScreenshot(
      path: map['path'] as String,
      caption: map['caption'] as String?,
      youtubeUrl: map['youtube_url'] as String? ?? map['youtubeUrl'] as String?,
    );
  }
}

/// Marketplace listing metadata — icons, screenshots, tagline (Epic 38 task
/// 38.8 / 38.9). At least one screenshot is required so the listing has
/// something visual to show.
class MarketplaceConfig {
  final MarketplaceIcons icons;
  final List<MarketplaceScreenshot> screenshots;
  final String? tagline;

  const MarketplaceConfig({
    required this.icons,
    required this.screenshots,
    this.tagline,
  });

  factory MarketplaceConfig.fromYaml(YamlMap map) {
    final iconsMap = map['icons'];
    if (iconsMap is! YamlMap) {
      throw FormatException('marketplace.icons is required');
    }
    final screensList = map['screenshots'];
    if (screensList is! YamlList || screensList.isEmpty) {
      throw FormatException(
        'marketplace.screenshots must include at least one entry',
      );
    }
    return MarketplaceConfig(
      icons: MarketplaceIcons.fromYaml(iconsMap),
      screenshots: screensList
          .map((e) => MarketplaceScreenshot.fromYaml(e as YamlMap))
          .toList(),
      tagline: map['tagline'] as String?,
    );
  }
}

/// Parsed representation of an `orca_plugin.yaml` manifest file.
class PluginManifest {
  final String name;
  final String displayName;
  final String description;
  final AndroidConfig? android;
  final IosConfig? ios;
  final List<EnvVar> env;
  final List<String> setupSteps;
  final PluginSchema? schema;
  final PreviewConfig? preview;
  final MarketplaceConfig? marketplace;

  PluginManifest({
    required this.name,
    required this.displayName,
    required this.description,
    this.android,
    this.ios,
    this.env = const [],
    this.setupSteps = const [],
    this.schema,
    this.preview,
    this.marketplace,
  });

  /// Reads and parses an `orca_plugin.yaml` file at the given [path].
  factory PluginManifest.fromYamlFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Plugin manifest not found', path);
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;

    final platformMap = yaml['platform'] as YamlMap?;

    return PluginManifest(
      name: yaml['name'] as String,
      displayName: (yaml['display_name'] as String?) ?? yaml['name'] as String,
      description: (yaml['description'] as String?) ?? '',
      android: platformMap != null && platformMap['android'] != null
          ? AndroidConfig.fromYaml(platformMap['android'] as YamlMap)
          : null,
      ios: platformMap != null && platformMap['ios'] != null
          ? IosConfig.fromYaml(platformMap['ios'] as YamlMap)
          : null,
      env: (yaml['env'] as YamlList?)
              ?.map((e) => EnvVar.fromYaml(e as YamlMap))
              .toList() ??
          [],
      setupSteps: (yaml['setup_steps'] as YamlList?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      schema: yaml['schema'] != null
          ? PluginSchema.fromYaml(yaml['schema'] as YamlMap)
          : null,
      preview: yaml['preview'] is YamlMap
          ? PreviewConfig.fromYaml(yaml['preview'] as YamlMap)
          : null,
      marketplace: yaml['marketplace'] is YamlMap
          ? MarketplaceConfig.fromYaml(yaml['marketplace'] as YamlMap)
          : null,
    );
  }
}
