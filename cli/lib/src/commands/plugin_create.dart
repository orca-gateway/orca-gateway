import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../utils/engine_resolver.dart';

/// Scaffolds a new Orca Gateway plugin project with the conventional directory
/// structure, manifest template, and starter code.
class PluginCreateCommand extends Command<void> {
  @override
  final name = 'create';

  @override
  final description = 'Scaffold a new Orca Gateway plugin project.';

  @override
  String get invocation => '${runner!.executableName} plugin create <name>';

  PluginCreateCommand() {
    argParser.addOption(
      'preview',
      help:
          'Web preview strategy for this plugin (Epic 38). "declarative" '
          'scaffolds a TypeScript stub file composed of core Orca Gateway widgets '
          'that `orca plugin build` compiles into static JSON — no preview '
          'editor rebuild needed. "web-native" scaffolds a Dart entry that '
          'requires a per-composition preview build (Slice D). "none" opts '
          'out of preview and shows an UnsupportedWidgetPlaceholder instead.',
      allowed: ['declarative', 'web-native', 'none'],
      defaultsTo: 'declarative',
    );
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a plugin name (e.g. my_scanner).');
    }

    final rawName = argResults!.rest.first;
    final previewFlag = argResults!['preview'] as String;
    final packageName = 'orca_$rawName';
    final pascalName = _toPascalCase(rawName);
    final displayName = pascalName;

    final projectDir = Directory(p.join(Directory.current.path, packageName));

    if (projectDir.existsSync()) {
      stderr.writeln('Error: Directory "${projectDir.path}" already exists.');
      exit(1);
    }

    // ------------------------------------------------------------------
    // 1. Create directory structure
    // ------------------------------------------------------------------
    Directory(p.join(projectDir.path, 'lib', 'src')).createSync(recursive: true);
    Directory(p.join(projectDir.path, 'example')).createSync(recursive: true);

    // ------------------------------------------------------------------
    // 2. Generate files
    // ------------------------------------------------------------------

    // pubspec.yaml
    File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync(
      'name: $packageName\n'
      'description: "Orca Gateway plugin for $rawName."\n'
      'version: 0.1.0\n'
      '\n'
      'environment:\n'
      '  sdk: ^3.11.3\n'
      '  flutter: ">=3.24.0"\n'
      '\n'
      'dependencies:\n'
      '  flutter:\n'
      '    sdk: flutter\n'
      '  orca_gateway: ^0.1.0\n'
      '\n'
      'dev_dependencies:\n'
      '  flutter_test:\n'
      '    sdk: flutter\n'
      '  flutter_lints: ^6.0.0\n',
    );

    // orca_plugin.yaml — includes preview + marketplace sections scaffolded
    // per the --preview flag (Epic 38 Slice B). The marketplace section is
    // always scaffolded because every plugin that wants a listing needs
    // icons + screenshots regardless of preview strategy.
    final previewSection = _previewYamlSection(previewFlag);
    File(p.join(projectDir.path, 'orca_plugin.yaml')).writeAsStringSync(
      'name: $packageName\n'
      'display_name: $displayName\n'
      'description: "Orca Gateway plugin for $rawName."\n'
      '\n'
      'platform:\n'
      '  android:\n'
      '    min_sdk: 21\n'
      '    permissions: []\n'
      '  ios:\n'
      '    min_version: "14.0"\n'
      '    plist: []\n'
      '\n'
      '$previewSection'
      '\n'
      '# Marketplace listing — required to publish to the Orca Gateway plugin\n'
      '# catalog. Replace the placeholder PNGs in assets/ with your own. All\n'
      '# three icon sizes are mandatory; at least one screenshot is required.\n'
      'marketplace:\n'
      '  icons:\n'
      '    small: assets/icon-32.png\n'
      '    medium: assets/icon-64.png\n'
      '    large: assets/icon-128.png\n'
      '  screenshots:\n'
      '    - path: assets/screenshot-1.png\n'
      '      caption: "Replace with a real screenshot of your widget"\n'
      '  tagline: "Short tagline shown in the marketplace (<= 120 chars)"\n'
      '\n'
      '# Uncomment and edit to enable TypeScript codegen (orca plugin generate):\n'
      '# schema:\n'
      '#   widgets:\n'
      '#     My${pascalName}Widget:\n'
      '#       kind: primitive\n'
      '#       props:\n'
      '#         label: { type: string, required: true }\n'
      '#         value: { type: number }\n'
      '#       triggers: [onTap, onChange]\n'
      '#   actions:\n'
      '#     my${pascalName}Action:\n'
      '#       params:\n'
      '#         targetId: { type: string, required: true }\n',
    );

    // Scaffold preview starter files per the chosen strategy.
    _scaffoldPreviewFiles(projectDir.path, previewFlag, pascalName);

    // Scaffold a placeholder assets directory so authors have a clear target
    // to drop their real PNGs into. We don't write binary files here — the
    // generator stays text-only — so doctor will flag the missing assets on
    // the first run, which is exactly the nudge we want.
    Directory(p.join(projectDir.path, 'assets')).createSync(recursive: true);
    File(p.join(projectDir.path, 'assets', 'README.md')).writeAsStringSync(
      '# Marketplace assets\n\n'
      'Drop the following PNG files into this directory before running\n'
      '`orca plugin doctor` or publishing to the marketplace:\n\n'
      '- `icon-32.png` — 32x32 PNG (small icon, shown in search results)\n'
      '- `icon-64.png` — 64x64 PNG (medium icon, shown in the install card)\n'
      '- `icon-128.png` — 128x128 PNG (large icon, shown on the detail page)\n'
      '- `screenshot-1.png` — at least one screenshot of the widget in use\n\n'
      'Only PNG is accepted; exact pixel dimensions for icons are enforced\n'
      'by `orca plugin doctor` so marketplace listings render consistently.\n',
    );

    // lib/orca_<name>.dart
    File(p.join(projectDir.path, 'lib', '$packageName.dart')).writeAsStringSync(
      'library $packageName;\n'
      '\n'
      "export 'src/${rawName}_plugin.dart';\n",
    );

    // lib/src/<name>_plugin.dart
    File(p.join(projectDir.path, 'lib', 'src', '${rawName}_plugin.dart')).writeAsStringSync(
      "import 'package:orca_gateway/orca_gateway.dart';\n"
      '\n'
      'class ${pascalName}Plugin extends OrcaPlugin {\n'
      '  ${pascalName}Plugin() : super(\n'
      "    name: '${pascalName}Plugin',\n"
      '    widgets: {\n'
      "      // 'MyWidget': _buildMyWidget,\n"
      '    },\n'
      '    actions: {\n'
      "      // 'myAction': _handleMyAction,\n"
      '    },\n'
      '    triggers: {\n'
      "      // 'MyWidget': [\n"
      "      //   TriggerDefinition(name: 'onCustomEvent', dataType: 'String'),\n"
      '      // ],\n'
      '    },\n'
      '  );\n'
      '}\n'
      '\n'
      '// Widget _buildMyWidget(OrcaComponentContext ctx) {\n'
      '//   return Container();\n'
      '// }\n'
      '\n'
      '// Future<void> _handleMyAction(\n'
      '//     Map<String, dynamic> action, ActionExecutor executor) async {\n'
      '//   // Action implementation\n'
      '// }\n',
    );

    // example/usage.dart
    File(p.join(projectDir.path, 'example', 'usage.dart')).writeAsStringSync(
      '// Example usage of $packageName plugin\n'
      '//\n'
      "// import 'package:$packageName/$packageName.dart';\n"
      '//\n'
      '// OrcaApp(\n'
      '//   plugins: [${pascalName}Plugin()],\n'
      '//   ...\n'
      '// )\n',
    );

    // ------------------------------------------------------------------
    // 3. Print success message
    // ------------------------------------------------------------------
    stdout.writeln('Created plugin project "$packageName" at ${projectDir.path}');
    stdout.writeln('');
    stdout.writeln('Next steps:');
    stdout.writeln('  1. cd $packageName');
    stdout.writeln('  2. Edit orca_plugin.yaml to declare permissions, plist entries, and env vars');
    stdout.writeln('  3. Implement your plugin in lib/src/${rawName}_plugin.dart');
    stdout.writeln('  4. Run "flutter pub get" to fetch dependencies');
    stdout.writeln('');
    stdout.writeln('Done.');
  }

  /// Converts a snake_case [name] to PascalCase.
  ///
  /// Example: `my_scanner` -> `MyScanner`
  String _toPascalCase(String name) {
    return name
        .split('_')
        .map((part) => part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
        .join();
  }

  /// Returns the `preview:` section that gets inlined into the scaffolded
  /// `orca_plugin.yaml`. Each strategy documents itself in the YAML so the
  /// plugin author can read the file and understand what to edit next.
  String _previewYamlSection(String flag) {
    switch (flag) {
      case 'declarative':
        return '# Preview strategy (Epic 38). `declarative` ships a TypeScript stub\n'
            '# composed of core Orca Gateway widgets. `orca plugin build` flattens it\n'
            '# into preview/stub.compiled.json which the stock Flutter Web\n'
            '# preview editor renders without a rebuild.\n'
            'preview:\n'
            '  kind: declarative\n'
            '  stub: preview/stub.ts\n'
            '  compiledStub: preview/stub.compiled.json\n';
      case 'web-native':
        return '# Preview strategy (Epic 38). `web_native` ships real Dart that runs\n'
            '# inside a per-composition preview editor build. Installing the\n'
            '# plugin triggers a new preview build in Slice D.\n'
            'preview:\n'
            '  kind: web_native\n'
            '  entry: lib/src/preview_stub.dart\n';
      case 'none':
      default:
        return '# Preview strategy (Epic 38). `none` opts out of preview rendering —\n'
            '# every widget in this plugin shows up as an UnsupportedWidgetPlaceholder\n'
            '# card in the Flutter Web preview editor.\n'
            'preview:\n'
            '  kind: none\n';
    }
  }

  /// Writes the starter preview files for the selected strategy into the
  /// newly scaffolded plugin directory.
  void _scaffoldPreviewFiles(String projectDir, String flag, String pascalName) {
    switch (flag) {
      case 'declarative':
        final previewDir = p.join(projectDir, 'preview');
        Directory(previewDir).createSync(recursive: true);

        // Compute a relative import path from preview/stub.ts to the engine
        // source tree. If the plugin lives inside a orca-gateway monorepo this
        // resolves via the upward-walk; otherwise we emit a clearly-broken
        // absolute-path comment so the author sees exactly what to fix.
        final enginePath = findEnginePath(projectDir);
        final String engineComponentsImport;
        if (enginePath != null) {
          final engineComponentsFile =
              p.join(enginePath, 'src', 'components', 'index.ts');
          final rel = p
              .relative(engineComponentsFile, from: previewDir)
              .replaceAll(r'\', '/');
          engineComponentsImport = rel.startsWith('.') ? rel : './$rel';
        } else {
          // Fallback — the stub will not run until the author fixes this
          // import. We'd rather have a clearly wrong starting point than
          // have `orca plugin build` fail with a cryptic error later.
          engineComponentsImport =
              'REPLACE_WITH_RELATIVE_PATH_TO/open-source/engine/src/components';
        }

        File(p.join(previewDir, 'stub.ts')).writeAsStringSync(
          "// Declarative preview stub (Epic 38, Slice B).\n"
          "//\n"
          "// Each key is a widget type this plugin provides. Each value is a\n"
          "// Orca Gateway engine Widget tree built from CORE widgets only — plugin\n"
          "// widgets referencing other plugins are rejected by `orca plugin\n"
          "// doctor`, because the whole point of 'declarative' mode is that\n"
          "// the compiled JSON renders in the stock preview editor with no\n"
          "// extra plugins installed.\n"
          "//\n"
          "// Run `orca plugin build` after editing this file to regenerate\n"
          "// preview/stub.compiled.json — commit both files so installs do\n"
          "// not require a build step.\n"
          "\n"
          "import {\n"
          "  Column,\n"
          "  Container,\n"
          "  Text,\n"
          "  Icon,\n"
          "  SizedBox,\n"
          "  EdgeInsets,\n"
          "  BoxDecoration,\n"
          "  Color,\n"
          "} from \"$engineComponentsImport\";\n"
          "import type { Widget } from \"${engineComponentsImport.replaceFirst('components', 'types/widget')}\";\n"
          "\n"
          "const stubs: Record<string, Widget> = {\n"
          "  My${pascalName}Widget: Container.new({\n"
          "    padding: EdgeInsets.all(16),\n"
          "    decoration: BoxDecoration.new({ color: Color.hex(\"#F3F4F6\") }),\n"
          "    child: Column.new({\n"
          "      children: [\n"
          "        Icon.new({ name: \"extension\" }),\n"
          "        SizedBox.new({ height: 8 }),\n"
          "        Text.new({ data: \"${pascalName} preview stub\" }),\n"
          "      ],\n"
          "    }),\n"
          "  }),\n"
          "};\n"
          "\n"
          "export default stubs;\n",
        );
        break;
      case 'web-native':
        File(p.join(projectDir, 'lib', 'src', 'preview_stub.dart'))
            .writeAsStringSync(
          "import 'package:flutter/widgets.dart';\n"
          "import 'package:orca_gateway/orca_gateway.dart';\n"
          "\n"
          "// Web-native preview stub (Epic 38, Slice B).\n"
          "//\n"
          "// Slice D will compile this into a per-composition Flutter Web\n"
          "// preview build. Until then, this file is a placeholder — calls\n"
          "// from the preview runtime will fall through to the\n"
          "// UnsupportedWidgetPlaceholder card.\n"
          "\n"
          "Map<String, ComponentBuilder> ${pascalName}PreviewStubs() {\n"
          "  return <String, ComponentBuilder>{\n"
          "    // 'My${pascalName}Widget': (ctx) => const Placeholder(),\n"
          "  };\n"
          "}\n",
        );
        break;
      case 'none':
      default:
        break;
    }
  }
}
