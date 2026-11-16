// C17.5/yaml: plugins/orca_voice_recorder/orca_plugin.yaml has a `schema:`
// section, in the format the CLI's parser reads, describing what the Flutter
// plugin implements: the VoiceRecorder widget and its props, its three
// triggers and the nine actions with their params. The Swift, Kotlin and
// TypeScript generators read it, so this test pins it against the names the
// Dart plugin registers and reads (lib/src/voice_recorder_plugin.dart):
// change one without the other and it fails.

import 'dart:io';

import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_gateway_cli/src/manifest/plugin_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The voice recorder plugin (tests run from cli/).
final _plugin = p.normalize(p.absolute('..', 'plugins', 'orca_voice_recorder'));
final _manifest = p.join(_plugin, 'orca_plugin.yaml');

/// The Flutter plugin's source, the reference the schema describes.
final _dart = File(
  p.join(_plugin, 'lib', 'src', 'voice_recorder_plugin.dart'),
).readAsStringSync();

/// The yaml type of a Dart type Flutter reads a prop as.
const _yamlType = {'String': 'string', 'bool': 'boolean'};

/// The schema as the CLI parses it.
PluginSchema _schema() {
  final schema = PluginManifest.fromYamlFile(_manifest).schema;
  expect(schema, isNotNull, reason: 'orca_plugin.yaml has a schema: section');
  return schema!;
}

/// The schema as written, for the notes the CLI ignores (`default`,
/// `description`, `event_data`).
YamlMap _raw() =>
    (loadYaml(File(_manifest).readAsStringSync()) as YamlMap)['schema']
        as YamlMap;

/// The `'<name>': <function>` entries of the plugin's [block] map, in order.
Map<String, String> _registered(String block) {
  final body = RegExp('\\b$block: \\{([^}]*)\\}').firstMatch(_dart)!.group(1)!;
  return {
    for (final m in RegExp(r"'(\w+)': (\w+)").allMatches(body)) m[1]!: m[2]!,
  };
}

/// The top-level function [name], from its signature to its closing brace.
String _function(String name) {
  final start = _dart.indexOf(
    RegExp('^(?:Widget|Future<void>) $name\\(', multiLine: true),
  );
  expect(start, isNot(-1), reason: '$name is in voice_recorder_plugin.dart');
  return _dart.substring(start, _dart.indexOf('\n}\n', start));
}

void main() {
  test('C17.5/yaml the widget is VoiceRecorder with Flutter\'s props', () {
    final widgets = _registered('widgets');
    expect(_schema().widgets.keys.toList(), widgets.keys.toList());

    final widget = _schema().widgets['VoiceRecorder']!;
    final notes =
        (_raw()['widgets'] as YamlMap)['VoiceRecorder']['props'] as YamlMap;
    expect(widget.kind, 'primitive');

    // `ctx.prop<T>('name')` or `ctx.propOr<T>('name', default)`.
    final reads = RegExp(
      r"ctx\.prop(?:Or)?<(\w+)>\('(\w+)'(?:, ([^)]+))?\)",
    ).allMatches(_function(widgets['VoiceRecorder']!)).toList();
    expect(widget.props.keys.toList(), [for (final m in reads) m[2]]);
    for (final m in reads) {
      final name = m[2]!;
      expect(widget.props[name]!.type, _yamlType[m[1]], reason: name);
      expect(
        (notes[name] as YamlMap)['default'],
        m[3] == null ? isNull : loadYaml(m[3]!),
        reason: '$name has Flutter\'s default',
      );
    }
    // recorderId falls back to the node's id, which no literal default says.
    expect(_dart, contains("ctx.prop<String>('recorderId') ?? ctx.node.id"));
  });

  test(
    'C17.5/yaml the triggers are Flutter\'s, onRecordingComplete never fired',
    () {
      final widget = _schema().widgets['VoiceRecorder']!;
      final events =
          (_raw()['widgets'] as YamlMap)['VoiceRecorder']['event_data']
              as YamlMap;

      final declared = RegExp(
        r"TriggerDefinition\(\s*name: '(\w+)'",
      ).allMatches(_dart).map((m) => m[1]!).toList();
      expect(widget.triggers, declared);
      expect(events.keys.toList(), declared);

      // The eventData keys of each `fireAction('<trigger>', eventData: {...})`.
      final fired = {
        for (final m in RegExp(
          r"fireAction\('(\w+)', eventData: \{([^}]*)\}",
        ).allMatches(_dart))
          m[1]!: [for (final k in RegExp(r"'(\w+)':").allMatches(m[2]!)) k[1]],
      };
      for (final trigger in declared) {
        final props = (events[trigger] as YamlMap)['props'] as YamlMap?;
        expect(
          props?.keys.toList() ?? [],
          fired[trigger] ?? [],
          reason: '$trigger fires with Flutter\'s eventData',
        );
      }
      expect(fired.keys, isNot(contains('onRecordingComplete')));
      expect(
        (events['onRecordingComplete'] as YamlMap)['description'],
        contains('never fired'),
      );

      // The states the recorder takes: its initial one and each it is set to.
      final states = RegExp(
        r"state = ValueNotifier\('(\w+)'\)|state\.value = '(\w+)'",
      ).allMatches(_dart).map((m) => m[1] ?? m[2]!).toSet();
      final state = PropSchema.fromYaml(
        ((events['onStateChange'] as YamlMap)['props'] as YamlMap)['state'],
      );
      expect(state.type, 'string');
      expect(state.enumValues, unorderedEquals(states));
    },
  );

  test(
    'C17.5/yaml the nine actions and the params Flutter\'s handlers read',
    () {
      final handlers = _registered('actions');
      final actions = _schema().actions;
      final notes = _raw()['actions'] as YamlMap;
      expect(handlers, hasLength(9));
      expect(actions.keys.toList(), handlers.keys.toList());

      for (final MapEntry(key: type, value: handler) in handlers.entries) {
        final body = _function(handler);
        final reads = RegExp(
          r"action\['(\w+)'\]",
        ).allMatches(body).map((m) => m[1]!).toSet();
        final params = actions[type]!.params;
        expect(params.keys, unorderedEquals(reads), reason: type);

        for (final name in reads) {
          final read = RegExp.escape("action['$name']");
          final String wantType;
          Object? wantDefault;
          if (RegExp('$read as String\\?').hasMatch(body)) {
            wantType = 'string';
            wantDefault = RegExp(
              "$read as String\\?\\)?\\s*\\?\\?\\s*'([^']*)'",
            ).firstMatch(body)?.group(1);
          } else if (body.contains("resolveString(action['$name']")) {
            wantType = 'string';
          } else {
            // `final raw = executor.resolveValue(action['x']);` then
            // `raw is num ? raw.toInt() : <default>`.
            final number = RegExp(
              'final (\\w+) = executor\\.resolveValue\\($read\\);\\s*'
              'final \\w+ = \\1 is num \\? \\1\\.toInt\\(\\) : (\\d+);',
            ).firstMatch(body);
            expect(
              number,
              isNotNull,
              reason: '$type.$name is read as a number',
            );
            wantType = 'number';
            wantDefault = int.parse(number!.group(2)!);
          }
          final where = '$type.$name';
          expect(params[name]!.type, wantType, reason: where);
          // Flutter does nothing when a param it reads with `?? ''` is empty.
          expect(
            params[name]!.required,
            body.contains("resolveString(action['$name'] ?? '')"),
            reason: '$where required',
          );
          expect(
            ((notes[type] as YamlMap)['params'] as YamlMap)[name]['default'],
            wantDefault,
            reason: '$where has Flutter\'s default',
          );
        }
      }
    },
  );
}
