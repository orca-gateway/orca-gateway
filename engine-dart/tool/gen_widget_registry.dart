// ignore_for_file: avoid_print
/// Generates lib/src/core/widget_registry.g.dart from
/// open-source/schema/widget-registry.json.
///
/// Run: dart run tool/gen_widget_registry.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final registryPath =
      '${scriptDir.parent.parent.path}/schema/widget-registry.json';
  final outputPath =
      '${scriptDir.parent.path}/lib/src/core/widget_registry.g.dart';

  final registryFile = File(registryPath);
  if (!registryFile.existsSync()) {
    print('ERROR: widget-registry.json not found at $registryPath');
    exit(1);
  }

  final json = jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
  final widgets = json['widgets'] as List;

  if (widgets.isEmpty) {
    print('ERROR: no widgets found in registry');
    exit(1);
  }

  final buf = StringBuffer();
  buf.writeln('// GENERATED FILE — DO NOT EDIT');
  buf.writeln('// Source: open-source/schema/widget-registry.json');
  buf.writeln('// Run: dart run tool/gen_widget_registry.dart');
  buf.writeln();
  buf.writeln('class WidgetRegistryEntry {');
  buf.writeln('  final String type;');
  buf.writeln('  final String kind;');
  buf.writeln('  final String childMode;');
  buf.writeln('  final List<String> slots;');
  buf.writeln('  final String introducedIn;');
  buf.writeln('  final String? removedIn;');
  buf.writeln('  final bool frozen;');
  buf.writeln('  final bool isSupportedOnWeb;');
  buf.writeln();
  buf.writeln('  const WidgetRegistryEntry({');
  buf.writeln('    required this.type,');
  buf.writeln('    required this.kind,');
  buf.writeln('    required this.childMode,');
  buf.writeln('    this.slots = const [],');
  buf.writeln("    this.introducedIn = '1.0.0',");
  buf.writeln('    this.removedIn,');
  buf.writeln('    this.frozen = false,');
  buf.writeln('    this.isSupportedOnWeb = true,');
  buf.writeln('  });');
  buf.writeln('}');
  buf.writeln();
  buf.writeln('const Map<String, WidgetRegistryEntry> widgetRegistry = {');

  for (final w in widgets) {
    final type = w['type'] as String;
    final kind = w['kind'] as String;
    final childMode = w['childMode'] as String;
    final slots = (w['slots'] as List?)?.cast<String>() ?? [];
    final introducedIn = w['introducedIn'] as String? ?? '1.0.0';
    final removedIn = w['removedIn'] as String?;
    final frozen = w['frozen'] as bool? ?? false;
    final isSupportedOnWeb = w['isSupportedOnWeb'] as bool? ?? true;

    buf.write("  '$type': WidgetRegistryEntry(");
    buf.write("type: '$type', ");
    buf.write("kind: '$kind', ");
    buf.write("childMode: '$childMode'");

    if (slots.isNotEmpty) {
      final slotsStr = slots.map((s) => "'$s'").join(', ');
      buf.write(', slots: [$slotsStr]');
    }
    if (introducedIn != '1.0.0') {
      buf.write(", introducedIn: '$introducedIn'");
    }
    if (removedIn != null) {
      buf.write(", removedIn: '$removedIn'");
    }
    if (frozen) {
      buf.write(', frozen: true');
    }
    if (!isSupportedOnWeb) {
      buf.write(', isSupportedOnWeb: false');
    }

    buf.writeln('),');
  }

  buf.writeln('};');

  final outputFile = File(outputPath);
  outputFile.writeAsStringSync(buf.toString());

  print('Generated ${widgets.length} widget entries → $outputPath');
}
