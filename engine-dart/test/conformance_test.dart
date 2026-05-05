import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:orca_engine/src/types/context.dart';
import 'package:orca_engine/src/core/json_tree_encoder.dart';
import 'package:orca_engine/src/core/capability_filter.dart';
import 'package:orca_engine/src/core/fallback_policy.dart';
import 'package:orca_engine/src/core/widget_registry.g.dart';

const _engineName = 'dart';

void main() {
  // Resolve fixtures relative to the package root (engine-dart/).
  // dart test runs from the package root, so Directory.current works.
  final packageRoot = Directory.current.path;
  final fixturesDir = p.normalize(
    p.join(packageRoot, '..', 'schema', 'fixtures', 'render'),
  );

  final dir = Directory(fixturesDir);
  if (!dir.existsSync()) {
    fail('Fixtures directory not found: $fixturesDir');
  }

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    fail('No fixtures in $fixturesDir');
  }

  for (final file in files) {
    final raw = file.readAsStringSync();
    final fx = jsonDecode(raw) as Map<String, dynamic>;
    final name = p.basenameWithoutExtension(file.path);

    final skipEngines = (fx['skipEngines'] as List?)?.cast<String>() ?? [];
    if (skipEngines.contains(_engineName)) {
      test('conformance: $name (skipped on $_engineName)', () {},
          skip: 'skipped on $_engineName');
      continue;
    }

    test('conformance: $name', () {
      // Build options with plugin widgets if present.
      JsonTreeEncoderOptions? options;
      final pluginWidgets = fx['pluginWidgets'] as List?;
      if (pluginWidgets != null && pluginWidgets.isNotEmpty) {
        final extraWidgets = <String, WidgetRegistryEntry>{};
        for (final pw in pluginWidgets) {
          final entry = pw as Map<String, dynamic>;
          if (entry['removedIn'] != null) continue;
          final type = entry['type'] as String;
          extraWidgets[type] = WidgetRegistryEntry(
            type: type,
            kind: entry['kind'] as String,
            childMode: entry['childMode'] as String,
            slots: (entry['slots'] as List?)?.cast<String>() ?? [],
            introducedIn: entry['introducedIn'] as String? ?? '1.0.0',
          );
        }
        options = JsonTreeEncoderOptions(extraWidgets: extraWidgets);
      }

      final input = fx['input'] as Map<String, dynamic>;
      final ctx = ValueResolverContext.fromJson(
        fx['context'] as Map<String, dynamic>,
      );

      var got = encodeJsonTree(input, ctx, options);

      // Capability filtering
      final capsJson = fx['clientCapabilities'] as Map<String, dynamic>?;
      if (capsJson != null) {
        final caps = CapabilityVector.fromJson(capsJson);
        final policyJson = fx['fallbackPolicy'] as Map<String, dynamic>?;
        final resolver = createStaticPolicyResolver(
          policyJson != null
              ? FallbackPolicyConfig.fromJson(policyJson)
              : const FallbackPolicyConfig(),
        );
        final filtered = filterByCapabilities(got, caps, resolver);
        got = filtered.components;
      }

      // Normalize via JSON round-trip
      final normalize = (dynamic v) => jsonDecode(jsonEncode(v));
      final gotJson = normalize(got.map((n) => n.toJson()).toList());
      final expectedJson = normalize(fx['expected']);

      expect(gotJson, equals(expectedJson));
    });
  }
}
