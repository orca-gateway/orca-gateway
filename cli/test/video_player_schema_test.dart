// C17.5/yaml: plugins/orca_video_player/orca_plugin.yaml has a `schema:`
// section, in the format the CLI's parser reads, describing what the Flutter
// plugin implements: the VideoPlayer widget and its six props, its five
// triggers and the five actions with their params. The Swift, Kotlin and
// TypeScript generators read it, so this test pins it against the names the
// Dart plugin registers and reads (lib/src/video_player_plugin.dart):
// change one without the other and it fails.

import 'dart:io';

import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_gateway_cli/src/manifest/plugin_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The video player plugin (tests run from cli/).
final _plugin = p.normalize(p.absolute('..', 'plugins', 'orca_video_player'));
final _manifest = p.join(_plugin, 'orca_plugin.yaml');

/// The Flutter plugin's source, the reference the schema describes.
final _dart = File(
  p.join(_plugin, 'lib', 'src', 'video_player_plugin.dart'),
).readAsStringSync();

/// The yaml type of a Dart type Flutter reads a prop as.
const _yamlType = {'String': 'string', 'bool': 'boolean', 'num': 'number'};

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
  expect(start, isNot(-1), reason: '$name is in video_player_plugin.dart');
  return _dart.substring(start, _dart.indexOf('\n}\n', start));
}

/// The player state's method [name], from its signature to its closing brace.
String _method(String name) {
  final start = _dart.indexOf(RegExp('^  void $name\\(', multiLine: true));
  expect(start, isNot(-1), reason: '$name is in video_player_plugin.dart');
  return _dart.substring(start, _dart.indexOf('\n  }\n', start));
}

/// The description the yaml gives [map].
String _description(Object? map) =>
    (map as YamlMap)['description'] as String? ?? '';

void main() {
  test('C17.5/yaml the widget is VideoPlayer with Flutter\'s props', () {
    final widgets = _registered('widgets');
    expect(_schema().widgets.keys.toList(), widgets.keys.toList());

    final widget = _schema().widgets['VideoPlayer']!;
    final notes =
        (_raw()['widgets'] as YamlMap)['VideoPlayer']['props'] as YamlMap;
    expect(widget.kind, 'primitive');

    // `ctx.prop<T>('name')`, `ctx.propOr<T>('name', default)` or
    // `ctx.prop<T>('name') ?? fallback`.
    final reads = RegExp(
      r"ctx\.prop(?:Or)?<(\w+)>\('(\w+)'(?:, ([^)]+))?\)\)?(?:\s*\?\?\s*([^;]+))?",
    ).allMatches(_function(widgets['VideoPlayer']!)).toList();
    expect(widget.props.keys.toList(), [for (final m in reads) m[2]]);

    for (final m in reads) {
      final name = m[2]!;
      final note = notes[name] as YamlMap;
      expect(widget.props[name]!.type, _yamlType[m[1]], reason: name);
      expect(widget.props[name]!.required, isFalse, reason: '$name required');

      final fallback = m[3] ?? m[4];
      if (fallback == null) {
        // aspectRatio: none, the build falls back to the video's own.
        expect(note['default'], isNull, reason: '$name has no default');
        expect(
          _dart,
          contains('widget.$name ?? _controller.value.$name'),
          reason: '$name falls back to the video\'s',
        );
        expect(_description(note), contains('video\'s own'), reason: name);
      } else if (fallback == 'ctx.node.id') {
        // playerId falls back to the node's id, which no literal says.
        expect(note['default'], isNull, reason: '$name has no literal default');
        expect(_description(note), contains('node\'s id'), reason: name);
      } else {
        expect(
          note['default'],
          loadYaml(fallback),
          reason: '$name has Flutter\'s default',
        );
      }
    }
  });

  test(
    'C17.5/yaml the triggers are Flutter\'s, onPlay and onPause from the tap only',
    () {
      final widget = _schema().widgets['VideoPlayer']!;
      final events =
          (_raw()['widgets'] as YamlMap)['VideoPlayer']['event_data']
              as YamlMap;

      final declared = RegExp(
        r"TriggerDefinition\(\s*name: '(\w+)'",
      ).allMatches(_dart).map((m) => m[1]!).toList();
      expect(widget.triggers, declared);
      expect(events.keys.toList(), declared);

      // The eventData entries of each `fireAction('<trigger>'[, eventData:
      // {...}])`, key to the Dart expression it fires.
      final fired = <String, Map<String, String>>{
        for (final m in RegExp(
          r"fireAction\('(\w+)'(?:, eventData: \{([^}]*)\})?\)",
        ).allMatches(_dart))
          m[1]!: {
            for (final k in RegExp(r"'(\w+)': ([^,]+),").allMatches(m[2] ?? ''))
              k[1]!: k[2]!.trim(),
          },
      };
      expect(fired.keys, unorderedEquals(declared));

      for (final trigger in declared) {
        final props = (events[trigger] as YamlMap)['props'] as YamlMap?;
        final data = fired[trigger]!;
        expect(
          props?.keys.toList() ?? [],
          data.keys.toList(),
          reason: '$trigger fires with Flutter\'s eventData',
        );
        for (final MapEntry(key: key, value: expr) in data.entries) {
          final where = '$trigger.$key';
          final prop = PropSchema.fromYaml(props![key]);
          if (expr.endsWith('.toString()')) {
            expect(prop.type, 'string', reason: where);
          } else {
            expect(expr, contains('.inMilliseconds'), reason: where);
            expect(prop.type, 'number', reason: where);
          }
          // A bare `<duration>.inMilliseconds` is a time in ms.
          if (RegExp(r'^[\w.]+\.inMilliseconds$').hasMatch(expr)) {
            expect(_description(props[key]), contains('ms'), reason: where);
          }
        }
      }

      // onPlay and onPause fire once each in the source, in the toggle; the
      // toggle runs only from the overlay's tap, which showControls shows; the
      // actions and autoPlay play and pause without firing them.
      final toggle = _method('_togglePlayPause');
      for (final trigger in ['onPlay', 'onPause']) {
        expect(
          RegExp("fireAction\\('$trigger'").allMatches(_dart),
          hasLength(1),
          reason: trigger,
        );
        expect(toggle, contains("fireAction('$trigger')"), reason: trigger);
        final note = _description(events[trigger]);
        expect(note, contains('overlay tap'), reason: trigger);
        expect(note, contains('showControls'), reason: trigger);
        expect(note, contains('never'), reason: trigger);
      }
      expect(RegExp(r'\b_togglePlayPause\b').allMatches(_dart), hasLength(2));
      expect(_dart, contains('onTap: _togglePlayPause'));
      expect(_dart, contains('if (!widget.showControls) return video;'));
      expect(_description(events['onPlay']), contains('playVideo'));
      expect(_description(events['onPlay']), contains('autoPlay'));
      expect(_description(events['onPause']), contains('pauseVideo'));
    },
  );

  test(
    'C17.5/yaml the five actions and the params Flutter\'s handlers read',
    () {
      final handlers = _registered('actions');
      final actions = _schema().actions;
      final notes = _raw()['actions'] as YamlMap;
      expect(handlers, hasLength(5));
      expect(actions.keys.toList(), handlers.keys.toList());

      for (final MapEntry(key: type, value: handler) in handlers.entries) {
        final body = _function(handler);
        expect(body, isNot(contains('fireAction')), reason: '$type fires none');
        final reads = RegExp(
          r"action\['(\w+)'\]",
        ).allMatches(body).map((m) => m[1]!).toSet();
        final params = actions[type]!.params;
        expect(params.keys.toList(), reads.toList(), reason: type);

        for (final name in reads) {
          final where = '$type.$name';
          final read = RegExp.escape("action['$name']");
          final note =
              ((notes[type] as YamlMap)['params'] as YamlMap)[name] as YamlMap;
          if (body.contains("executor.resolveString(action['$name'] ?? '')")) {
            // An empty or unknown id finds no player: the action does nothing.
            expect(body, contains('VideoPlayerPlugin._controllers[$name]'));
            expect(params[name]!.type, 'string', reason: where);
          } else {
            // `final x = (executor.resolveValue(action['x']) as num?)
            // ?.toInt();` then `if (... || x == null) return;`.
            final number = RegExp(
              'final (\\w+) = \\(executor\\.resolveValue\\($read\\) '
              'as num\\?\\)\\?\\.to(?:Int|Double)\\(\\);',
            ).firstMatch(body);
            expect(number, isNotNull, reason: '$where is read as a number');
            expect(
              body,
              contains('|| ${number![1]} == null) return;'),
              reason: '$where missing does nothing',
            );
            expect(params[name]!.type, 'number', reason: where);
          }
          // Without it Flutter does nothing, and it has no default.
          expect(params[name]!.required, isTrue, reason: '$where required');
          expect(note['default'], isNull, reason: '$where has no default');
        }
      }

      // What the handlers do with the values, as the notes say.
      String param(String type, String name) =>
          _description(((notes[type] as YamlMap)['params'] as YamlMap)[name]);
      expect(
        _function(handlers['seekVideo']!),
        contains('Duration(milliseconds: positionMs)'),
      );
      expect(param('seekVideo', 'position'), contains('ms'));
      expect(
        _function(handlers['setVolume']!),
        contains('volume.clamp(0.0, 1.0)'),
      );
      expect(param('setVolume', 'volume'), contains('clamped to 0...1'));
      expect(
        _function(handlers['setPlaybackSpeed']!),
        contains('controller.setPlaybackSpeed(speed)'),
      );
      expect(param('setPlaybackSpeed', 'speed'), contains('<= 0 is an error'));
    },
  );
}
