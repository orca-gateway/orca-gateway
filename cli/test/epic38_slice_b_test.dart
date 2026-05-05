// Slice B coverage for Epic 38 — manifest parser + helper utilities.
//
// The CLI previously had no Dart test runner. This file adds targeted tests
// for the three pieces most likely to regress:
//
//   1. PluginManifest.fromYamlFile parses the new `preview:` and
//      `marketplace:` sections into typed models with the right defaults
//      and the right enum mapping.
//
//   2. readPngDimensions correctly identifies valid PNG files, reports the
//      exact pixel dimensions, and returns null for missing files and files
//      that are not PNGs (signature check).
//
//   3. collectStubWidgetTypes walks a compiled stub JSON and returns every
//      referenced widget type — the function powering the "declarative
//      stubs may only reference core widgets" validation in plugin doctor.
//
// End-to-end tests (`orca plugin build` compiling a real stub, `orca plugin
// doctor` passing every check on the orca_google_map reference plugin) are
// covered by manual validation during Slice B and by the reference plugin
// being committed to the repo — a broken compile step would fail CI on the
// compiled JSON diff.

import 'dart:io';

import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_gateway_cli/src/utils/core_widget_types.dart';
import 'package:orca_gateway_cli/src/utils/png_reader.dart';
import 'package:test/test.dart';

void main() {
  group('PluginManifest — Epic 38 Slice B sections', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('orca_cli_manifest_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    File writeManifest(String contents) {
      final file = File('${tempDir.path}/orca_plugin.yaml');
      file.writeAsStringSync(contents);
      return file;
    }

    test('parses declarative preview with default paths', () {
      final file = writeManifest('''
name: orca_test
display_name: Test
description: Test plugin
preview:
  kind: declarative
''');
      final manifest = PluginManifest.fromYamlFile(file.path);
      expect(manifest.preview, isNotNull);
      expect(manifest.preview!.kind, PreviewKind.declarative);
      expect(manifest.preview!.stubPath, 'preview/stub.ts');
      expect(manifest.preview!.compiledStubPath, 'preview/stub.compiled.json');
      expect(manifest.preview!.entry, isNull);
    });

    test('parses declarative preview with custom paths', () {
      final file = writeManifest('''
name: orca_test
display_name: Test
description: Test plugin
preview:
  kind: declarative
  stub: src/preview/stub.ts
  compiledStub: build/stub.json
''');
      final manifest = PluginManifest.fromYamlFile(file.path);
      expect(manifest.preview!.stubPath, 'src/preview/stub.ts');
      expect(manifest.preview!.compiledStubPath, 'build/stub.json');
    });

    test('parses web_native preview with entry', () {
      final file = writeManifest('''
name: orca_test
display_name: Test
description: Test plugin
preview:
  kind: web_native
  entry: lib/src/preview_stub.dart
''');
      final manifest = PluginManifest.fromYamlFile(file.path);
      expect(manifest.preview!.kind, PreviewKind.webNative);
      expect(manifest.preview!.entry, 'lib/src/preview_stub.dart');
    });

    test('parses none preview as opt-out', () {
      final file = writeManifest('''
name: orca_test
display_name: Test
description: Test plugin
preview:
  kind: none
''');
      final manifest = PluginManifest.fromYamlFile(file.path);
      expect(manifest.preview!.kind, PreviewKind.none);
    });

    test('throws FormatException on unknown preview kind', () {
      final file = writeManifest('''
name: orca_test
display_name: Test
description: Test plugin
preview:
  kind: magic
''');
      expect(
        () => PluginManifest.fromYamlFile(file.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses marketplace icons and screenshots', () {
      final file = writeManifest('''
name: orca_test
display_name: Test
description: Test plugin
marketplace:
  icons:
    small: assets/icon-32.png
    medium: assets/icon-64.png
    large: assets/icon-128.png
  screenshots:
    - path: assets/screen-1.png
      caption: First view
      youtube_url: https://youtube.com/watch?v=abc
    - path: assets/screen-2.png
  tagline: "Short tagline"
''');
      final manifest = PluginManifest.fromYamlFile(file.path);
      final market = manifest.marketplace;
      expect(market, isNotNull);
      expect(market!.icons.small, 'assets/icon-32.png');
      expect(market.icons.medium, 'assets/icon-64.png');
      expect(market.icons.large, 'assets/icon-128.png');
      expect(market.screenshots, hasLength(2));
      expect(market.screenshots[0].path, 'assets/screen-1.png');
      expect(market.screenshots[0].caption, 'First view');
      expect(market.screenshots[0].youtubeUrl, 'https://youtube.com/watch?v=abc');
      expect(market.screenshots[1].caption, isNull);
      expect(market.tagline, 'Short tagline');
    });

    test('throws when marketplace has no screenshots', () {
      final file = writeManifest('''
name: orca_test
display_name: Test
description: Test plugin
marketplace:
  icons:
    small: a.png
    medium: b.png
    large: c.png
  screenshots: []
''');
      expect(
        () => PluginManifest.fromYamlFile(file.path),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('readPngDimensions', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('orca_cli_png_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns null for a missing file', () {
      expect(readPngDimensions('${tempDir.path}/does_not_exist.png'), isNull);
    });

    test('returns null for a file that is not a PNG', () {
      final file = File('${tempDir.path}/fake.png');
      file.writeAsBytesSync([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17]);
      expect(readPngDimensions(file.path), isNull);
    });

    test('parses width and height from a real PNG file', () {
      // Uses the 32x32 icon generated by the reference plugin's asset
      // setup. If the reference assets ever move, update this path.
      final iconPath = _resolveRepoPath(
        'plugins/orca_google_map/assets/icon-32.png',
      );
      final dims = readPngDimensions(iconPath);
      expect(dims, isNotNull);
      expect(dims!.width, 32);
      expect(dims.height, 32);
    });
  });

  group('collectStubWidgetTypes', () {
    test('collects every type across every compiled entry', () {
      final compiled = <String, dynamic>{
        'GoogleMap': [
          {'id': '0', 'type': 'Container'},
          {'id': '1', 'type': 'Column'},
          {'id': '2', 'type': 'Text'},
        ],
        'GoogleMapMarker': [
          {'id': '0', 'type': 'Icon'},
          {'id': '1', 'type': 'Text'},
        ],
      };
      final types = collectStubWidgetTypes(compiled);
      expect(types, {'Container', 'Column', 'Text', 'Icon'});
    });

    test('returns empty set for an empty compiled map', () {
      expect(collectStubWidgetTypes(<String, dynamic>{}), isEmpty);
    });

    test('skips malformed entries without throwing', () {
      final compiled = <String, dynamic>{
        'GoogleMap': 'not-a-list',
        'OtherWidget': [
          {'id': '0'}, // no type key
          {'id': '1', 'type': 'Text'},
        ],
      };
      expect(collectStubWidgetTypes(compiled), {'Text'});
    });
  });
}

/// Resolves a path relative to the repo root regardless of where the test
/// runner sets CWD. Walks up from the test's script directory until the
/// `cli/` ancestor is found, then joins the remaining segments.
String _resolveRepoPath(String relative) {
  var dir = Directory.current;
  while (true) {
    final candidate = Directory('${dir.path}/cli');
    if (candidate.existsSync()) {
      return '${dir.path}/$relative';
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${Directory.current.path}');
    }
    dir = parent;
  }
}
