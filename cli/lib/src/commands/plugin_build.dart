import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../manifest/plugin_manifest.dart';
import '../utils/engine_resolver.dart';

/// Compiles a plugin's declarative preview stub into static JSON (Epic 38
/// Slice B).
///
/// The command is only meaningful for plugins whose manifest declares
/// `preview.kind: declarative`. For other kinds it reports and exits 0 so
/// running it from CI or monorepo hooks is safe across every plugin.
///
/// High-level flow:
///
///   1. Locate `orca_plugin.yaml` in the current working directory and
///      parse it via [PluginManifest.fromYamlFile].
///   2. Short-circuit for non-declarative modes.
///   3. Write a tiny TypeScript harness to a temp file. The harness imports
///      the plugin's stub file, runs every widget value through the engine's
///      `flatten()` encoder, and writes a JSON object keyed by widget type to
///      stdout. Per-widget output is the same `ComponentNode[]` wire format
///      the preview editor already speaks — so the compiled artifact can be
///      rendered by the stock Flutter Web preview with zero extra plumbing.
///   4. Spawn `bun run <harness>` with cwd set to the plugin directory.
///      `bun` handles TypeScript natively — no tsc pass. Stdout is captured,
///      stderr is streamed to the terminal so stack traces from broken stubs
///      surface without the CLI having to re-parse them.
///   5. Write the JSON to `preview/stub.compiled.json` (or the path the
///      manifest specifies via `preview.compiledStub`).
///
/// Design notes:
///
/// * The harness is written fresh on every run rather than being a static
///   asset shipped with the CLI. That way any future change to what we
///   extract (actions, watches, info requirements) lives in one Dart string
///   here and does not require a CLI release to roll out.
/// * Bun is assumed to be on PATH. This matches the precedent set by
///   `bun run schema/gen-widget-registry.ts` — the CLI's other build
///   steps already require bun. A missing bun prints an actionable error.
/// * The compiled output is deliberately pretty-printed (2-space JSON) so
///   diffs are readable in code review. Plugin authors commit the compiled
///   file into their repo.
class PluginBuildCommand extends Command<void> {
  @override
  final name = 'build';

  @override
  final description =
      'Compile a plugin\'s declarative preview stub into static JSON.';

  @override
  String get invocation => '${runner!.executableName} plugin build';

  @override
  Future<void> run() async {
    final pluginRoot = Directory.current.path;
    final manifestPath = p.join(pluginRoot, 'orca_plugin.yaml');

    if (!File(manifestPath).existsSync()) {
      stderr.writeln(
        'Error: orca_plugin.yaml not found in the current directory.',
      );
      stderr.writeln(
        'Run this command from the root of a plugin package.',
      );
      exit(1);
    }

    final PluginManifest manifest;
    try {
      manifest = PluginManifest.fromYamlFile(manifestPath);
    } on FormatException catch (e) {
      stderr.writeln('Error parsing orca_plugin.yaml: ${e.message}');
      exit(1);
    }

    final preview = manifest.preview;
    if (preview == null) {
      stdout.writeln(
        'No `preview:` section in orca_plugin.yaml — nothing to build.',
      );
      return;
    }

    switch (preview.kind) {
      case PreviewKind.none:
        stdout.writeln(
          'preview.kind = none — plugin opts out of preview rendering.',
        );
        return;

      case PreviewKind.webNative:
        stdout.writeln(
          'preview.kind = web_native — compiled at preview build time by '
          'the per-composition pipeline (Slice D), not here.',
        );
        return;

      case PreviewKind.declarative:
        await _buildDeclarative(pluginRoot, preview);
    }
  }

  Future<void> _buildDeclarative(
    String pluginRoot,
    PreviewConfig preview,
  ) async {
    final stubFile = File(p.join(pluginRoot, preview.stubPath));
    if (!stubFile.existsSync()) {
      stderr.writeln(
        'Error: declarative stub file not found at ${preview.stubPath}.',
      );
      stderr.writeln(
        'Create it, or set `preview.stub` in orca_plugin.yaml to point at '
        'the correct path.',
      );
      exit(1);
    }

    // 1. Locate the engine. Relative imports from the generated harness are
    //    the simplest way to avoid any package-resolution setup — we discover
    //    the engine by walking upward from the plugin (honoring
    //    ORCA_ENGINE_PATH as an override) and compute the relative path from
    //    the harness file to the engine's `src/` directory.
    final enginePath = findEnginePath(pluginRoot);
    if (enginePath == null) {
      stderr.writeln(
        'Error: could not find the Orca Gateway engine from this plugin.',
      );
      stderr.writeln(
        'The build walks upward from the plugin directory looking for a '
        'sibling `engine` folder with `"name": "orcagateway-engine"` in its '
        'package.json. For plugins outside the monorepo, set '
        '`ORCA_ENGINE_PATH=/path/to/open-source/engine`.',
      );
      exit(1);
    }

    // 2. Write the harness next to the stub. Placing it inside the plugin
    //    directory (rather than in /tmp) means bun's relative imports from
    //    the stub file work unchanged — the stub sees the same relative
    //    layout whether it is being run by the harness or edited in-place.
    //    We clean it up regardless of success/failure.
    final harnessPath = p.join(
      pluginRoot,
      'preview',
      '.orca-build-harness.ts',
    );
    Directory(p.dirname(harnessPath)).createSync(recursive: true);

    // The stub import is a relative path from the harness back to the stub
    // file. Using the manifest-configured path means a plugin author who
    // moves their stub elsewhere (e.g. `src/preview/stub.ts`) keeps working
    // without us hardcoding `./stub.ts`.
    final stubImportPath = p
        .relative(stubFile.path, from: p.dirname(harnessPath))
        .replaceAll(r'\', '/');
    final stubImport =
        stubImportPath.startsWith('.') ? stubImportPath : './$stubImportPath';

    // Relative path from the harness to the engine's widget module. The
    // engine is a TS source tree, so we point bun directly at the TypeScript
    // file — bun handles the rest without a build step.
    final engineWidgetModule =
        p.join(enginePath, 'src', 'types', 'widget.ts');
    final engineWidgetImportPath = p
        .relative(engineWidgetModule, from: p.dirname(harnessPath))
        .replaceAll(r'\', '/');
    final engineWidgetImport = engineWidgetImportPath.startsWith('.')
        ? engineWidgetImportPath
        : './$engineWidgetImportPath';

    final harness = _harnessSource(
      stubImport: stubImport,
      engineWidgetImport: engineWidgetImport,
    );
    File(harnessPath).writeAsStringSync(harness);

    try {
      final result = await Process.run(
        'bun',
        ['run', harnessPath],
        workingDirectory: pluginRoot,
      );

      if (result.exitCode != 0) {
        stderr.writeln(
          'Error: bun exited with code ${result.exitCode} while compiling '
          'the declarative stub.',
        );
        final errOut = (result.stderr as String).trim();
        if (errOut.isNotEmpty) {
          stderr.writeln(errOut);
        }
        stderr.writeln(
          '\nTips:\n'
          '  * Make sure `bun` is installed and on PATH.\n'
          '  * Make sure `orcagateway-engine` is resolvable from this plugin '
          '(check package.json / workspace setup).\n'
          '  * Make sure the stub only imports from "orcagateway-engine/components" '
          'and returns Widget instances from each map entry.',
        );
        exit(1);
      }

      // stdout is one JSON document — the map of widget type → compiled
      // ComponentNode[]. Pretty-print it into the committed artifact so
      // diffs in code review stay readable.
      final payload = _parseHarnessOutput(result.stdout as String);
      final compiledPath = p.join(pluginRoot, preview.compiledStubPath);
      Directory(p.dirname(compiledPath)).createSync(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      File(compiledPath).writeAsStringSync('${encoder.convert(payload)}\n');

      final widgetCount = payload.length;
      stdout.writeln(
        'Compiled $widgetCount widget stub${widgetCount == 1 ? '' : 's'} → '
        '${preview.compiledStubPath}',
      );
    } on ProcessException catch (e) {
      stderr.writeln(
        'Error running bun: ${e.message}. Is bun installed and on PATH?',
      );
      exit(1);
    } finally {
      // Always clean up the harness file so it does not pollute the plugin
      // repo. If the build failed, the error message above is enough to
      // debug with — keeping the harness around would just leak an internal
      // detail into the plugin's tree.
      try {
        File(harnessPath).deleteSync();
      } catch (_) {
        // Best effort — never let cleanup failures surface as build failures.
      }
    }
  }

  /// Parses the harness output. Bun may print warnings or other noise to
  /// stdout before the JSON (e.g. deprecation notices). We scan for the first
  /// `{` that's on a line by itself preceded by our sentinel so the parser is
  /// resilient to that noise.
  Map<String, dynamic> _parseHarnessOutput(String stdout) {
    const sentinel = '---ORCA-BUILD-JSON---';
    final idx = stdout.indexOf(sentinel);
    if (idx < 0) {
      throw FormatException(
        'harness output did not contain the expected JSON sentinel. '
        'stdout was:\n$stdout',
      );
    }
    final jsonText = stdout.substring(idx + sentinel.length).trim();
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'harness output was not a JSON object. stdout was:\n$stdout',
      );
    }
    return decoded;
  }

  /// Builds the TypeScript harness. Imports the plugin's stub file and the
  /// engine's `flatten()` via relative paths computed by the caller, iterates
  /// the exported map, runs each value through `flatten()`, and prints one
  /// sentinel line followed by the JSON result on stdout.
  String _harnessSource({
    required String stubImport,
    required String engineWidgetImport,
  }) {
    final stubSpec = stubImport.replaceAll('"', r'\"');
    final engineSpec = engineWidgetImport.replaceAll('"', r'\"');
    return '''
// Auto-generated by `orca plugin build`. Do not edit.
// Removed after each run.

import { flatten } from "$engineSpec";
import stubs from "$stubSpec";

const compiled: Record<string, unknown> = {};
for (const [type, widget] of Object.entries(stubs as Record<string, unknown>)) {
  compiled[type] = flatten(widget as any);
}

console.log("---ORCA-BUILD-JSON---");
console.log(JSON.stringify(compiled));
''';
  }
}
