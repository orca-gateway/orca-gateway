// C17.5/yaml: plugins/orca_push_notification/orca_plugin.yaml has a `schema:`
// section, in the format the CLI's parser reads, describing what the Flutter
// plugin implements: no widget and so no trigger, and the five actions with
// the params their handlers read. The Swift, Kotlin and TypeScript generators
// read it, so this test pins it against the names the Dart plugin registers
// and reads (lib/src/push_notification_plugin.dart), and its notes against
// how Flutter reads each param (raw, or resolved as a value) and what each
// action writes: change one without the other and it fails.

import 'dart:io';

import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_gateway_cli/src/manifest/plugin_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The push notification plugin (tests run from cli/).
final _plugin = p.normalize(
  p.absolute('..', 'plugins', 'orca_push_notification'),
);
final _manifest = p.join(_plugin, 'orca_plugin.yaml');

/// The Flutter plugin's source, the reference the schema describes.
final _dart = File(
  p.join(_plugin, 'lib', 'src', 'push_notification_plugin.dart'),
).readAsStringSync();

/// The SDK's action executor, for what its resolveString and setState do.
final _executor = File(
  p.normalize(
    p.absolute('..', 'sdk', 'lib', 'src', 'state', 'action_executor.dart'),
  ),
).readAsStringSync();

/// The schema as the CLI parses it.
PluginSchema _schema() {
  final schema = PluginManifest.fromYamlFile(_manifest).schema;
  expect(schema, isNotNull, reason: 'orca_plugin.yaml has a schema: section');
  return schema!;
}

/// The schema as written, for the notes the CLI ignores (`default`,
/// `description`).
YamlMap _raw() {
  final schema =
      (loadYaml(File(_manifest).readAsStringSync()) as YamlMap)['schema'];
  expect(schema, isA<YamlMap>(), reason: 'orca_plugin.yaml has a schema: map');
  return schema as YamlMap;
}

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
    RegExp('^Future<void> $name\\(', multiLine: true),
  );
  expect(start, isNot(-1), reason: '$name is in push_notification_plugin.dart');
  return _dart.substring(start, _dart.indexOf('\n}\n', start));
}

/// The part of [source] from [signature] to the next [end], found by the
/// signature so that a rewrite keeping the key expressions still passes.
String _slice(String source, String signature, String end) {
  final start = source.indexOf(signature);
  expect(start, isNot(-1), reason: signature);
  final stop = source.indexOf(end, start);
  expect(stop, isNot(-1), reason: '$signature ends');
  return source.substring(start, stop);
}

/// [code] with each run of whitespace as one space.
String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

/// The description the yaml gives [map].
String _description(Object? map) =>
    (map as YamlMap)['description'] as String? ?? '';

/// How a handler reads a param.
enum _Read {
  /// `action['x'] as String?`: a non-string throws, failing the action.
  raw,

  /// `executor.resolveString(action['x'] ?? '')`.
  resolved,

  /// `action['x'] != null ? executor.resolveString(action['x']) : null`.
  resolvedIfPresent,
}

/// The one read of param [name] in handler [body]: how, into which local and
/// with which literal fallback.
({_Read how, String local, String? fallback}) _read(String body, String name) {
  final read = RegExp.escape("action['$name']");
  final forms = {
    _Read.raw: RegExp(
      "final (\\w+) = $read as String\\?(?: \\?\\? '([^']*)')?;",
    ),
    _Read.resolved: RegExp(
      "final (\\w+) = executor\\.resolveString\\($read \\?\\? '([^']*)'\\);",
    ),
    _Read.resolvedIfPresent: RegExp(
      "final (\\w+) = $read != null \\? "
      "executor\\.resolveString\\($read\\) : null;",
    ),
  };
  final flat = _flat(body);
  final found = [
    for (final MapEntry(key: how, value: form) in forms.entries)
      if (form.firstMatch(flat) case final m?)
        (how: how, local: m[1]!, fallback: m.groupCount > 1 ? m[2] : null),
  ];
  expect(found, hasLength(1), reason: '$name is read one known way');
  return found.single;
}

void main() {
  test('C17.5/yaml no widget and no trigger, the five actions in Flutter\'s '
      'order', () {
    final schema = _schema();
    expect(_registered('widgets'), isEmpty);
    expect(_dart, isNot(contains('TriggerDefinition')));
    expect(_dart, isNot(contains('fireAction')));
    expect(schema.widgets, isEmpty);
    expect(_raw().keys.toList(), ['actions'], reason: 'actions only');

    final handlers = _registered('actions');
    expect(handlers, hasLength(5));
    expect(schema.actions.keys.toList(), handlers.keys.toList());
    for (final type in handlers.keys) {
      expect(
        _description((_raw()['actions'] as YamlMap)[type]),
        isNotEmpty,
        reason: '$type says what it does',
      );
    }
  });

  test('C17.5/yaml the params each handler reads, raw or resolved, with '
      'Flutter\'s defaults', () {
    final handlers = _registered('actions');
    final actions = _schema().actions;
    final notes = _raw()['actions'] as YamlMap;

    // resolveString takes any resolved value as its text.
    final resolve = _slice(
      _executor,
      'String resolveString(dynamic raw)',
      '\n  }\n',
    );
    expect(resolve, contains('?.toString()'));

    // setState writes app state for "app" and page state for anything else.
    final setState = _slice(_executor, "_handlers['setState'] =", '\n    };\n');
    expect(
      setState,
      matches(
        RegExp(
          r"if \(scope == 'app'\) \{[^}]*setAppState[^}]*\} else \{"
          r'[^}]*setPageState',
        ),
      ),
    );

    for (final MapEntry(key: type, value: handler) in handlers.entries) {
      final body = _function(handler);
      final reads = RegExp(
        r"action\['(\w+)'\]",
      ).allMatches(body).map((m) => m[1]!).toSet().toList();
      final params = actions[type]!.params;
      final paramNotes = (notes[type] as YamlMap)['params'] as YamlMap;
      expect(params.keys.toList(), reads, reason: '$type reads these');

      // The handler returns without acting when one of these holds.
      final returnIf = RegExp(
        r'if \(([^)]*)\) return;',
      ).allMatches(body).map((m) => m[1]!).join(' || ');

      for (final name in reads) {
        final where = '$type.$name';
        final param = params[name]!;
        final note = paramNotes[name] as YamlMap;
        final description = _description(note).toLowerCase();
        final (:how, :local, :fallback) = _read(body, name);
        expect(param.type, 'string', reason: where);

        switch (how) {
          case _Read.raw:
            // `as String?` throws on any other type.
            expect(description, contains('read raw'), reason: where);
            expect(
              description,
              contains('a non-string fails the action'),
              reason: '$where of another type',
            );
            // Absent, Flutter takes the fallback or skips what it is for.
            expect(param.required, isFalse, reason: '$where required');
            expect(note['default'], fallback, reason: '$where default');
            if (fallback == null) {
              expect(body, contains('$local != null'), reason: where);
              expect(description, contains('absent'), reason: where);
            }
          case _Read.resolved:
            expect(description, contains('resolved as a value'));
            expect(
              description,
              contains('a non-string is used as its text'),
              reason: '$where of another type',
            );
            final doesNothing = returnIf.contains('$local.isEmpty');
            expect(param.required, doesNothing, reason: '$where required');
            if (doesNothing) {
              expect(note['default'], isNull, reason: '$where default');
              expect(description, contains('empty does nothing'));
            } else {
              expect(note['default'], fallback, reason: '$where default');
            }
          case _Read.resolvedIfPresent:
            expect(description, contains('resolved as a value'));
            expect(
              description,
              contains('a non-string is used as its text'),
              reason: '$where of another type',
            );
            expect(param.required, isFalse, reason: '$where required');
            expect(note['default'], isNull, reason: '$where default');
            expect(description, contains('absent'), reason: where);
        }

        // A scope goes to setState as is.
        if (body.contains("'scope': $local,")) {
          expect(param.enumValues, ['page', 'app'], reason: where);
          expect(description, contains('page for any other string'));
        } else {
          expect(param.enumValues, isNull, reason: where);
        }
      }
    }
  });

  test('C17.5/yaml each action says what it writes, and in which scope', () {
    final handlers = _registered('actions');
    final notes = _raw()['actions'] as YamlMap;
    final setState = RegExp(
      r"executor\.execute\(\{ 'type': 'setState', 'key': (\w+), "
      r"'value': ([^,]+), 'scope': (\w+), \}\);",
    );

    for (final MapEntry(key: type, value: handler) in handlers.entries) {
      final body = _function(handler);
      final flat = _flat(body);
      final description = _description(notes[type]);
      final writes = setState.allMatches(flat).toList();
      expect(
        RegExp(r'executor\.execute\(').allMatches(body),
        hasLength(writes.length),
        reason: '$type executes only setState',
      );
      if (writes.isEmpty) {
        expect(description, contains('Writes no state'), reason: type);
        continue;
      }

      for (final w in writes) {
        // Its key and scope are params the handler reads.
        String param(String local) =>
            RegExp("final $local = action\\['(\\w+)'\\]").firstMatch(body)![1]!;
        final key = param(w[1]!);
        final scope = param(w[3]!);
        expect(description, contains(key), reason: '$type writes $key');
        expect(description, contains('in $scope'), reason: type);

        switch (w[2]!.trim()) {
          case "granted ? 'granted' : 'denied'":
            expect(description, contains('granted or denied to $key'));
          case 'token':
            expect(flat, contains('FirebaseMessaging.instance.getToken()'));
            expect(description, contains('FCM token'), reason: type);
            if (flat.contains('if (granted && $key != null)')) {
              expect(description, contains('when granted'), reason: type);
            }
            if (flat.contains('if (token != null) {')) {
              expect(description, contains('no token writes nothing'));
            } else {
              expect(description, contains('null when there is none'));
            }
          default:
            fail('$type writes ${w[2]}, which the yaml does not say');
        }
      }
    }

    // A tap on the notification hands its payload to the host's
    // onNotificationTap, given to initialize.
    expect(_dart, contains('onNotificationTap?.call(response.payload);'));
    final show = _function(handlers['showLocalNotification']!);
    expect(show, contains('payload: payload,'));
    expect(
      _description(notes['showLocalNotification']),
      contains('onNotificationTap'),
    );

    // The topic actions are Firebase's.
    for (final (type, call, verb) in [
      ('subscribeToTopic', 'subscribeToTopic(topic)', 'Subscribes'),
      ('unsubscribeFromTopic', 'unsubscribeFromTopic(topic)', 'Unsubscribes'),
    ]) {
      expect(
        _function(handlers[type]!),
        contains('FirebaseMessaging.instance.$call'),
      );
      expect(_description(notes[type]), startsWith(verb), reason: type);
      expect(_description(notes[type]), contains('FCM topic'), reason: type);
    }
  });

  test('C17.5/yaml absent, showLocalNotification\'s payload is tapped as "", '
      'not null', () {
    // Flutter shows the notification with the payload it read, null when
    // absent, and flutter_local_notifications 18.0.1 sends
    // `'payload': payload ?? ''` in each show call, so the tap hands "".
    final show = _function(_registered('actions')['showLocalNotification']!);
    expect(show, contains('payload: payload,'));
    final notes = _raw()['actions'] as YamlMap;
    final params = (notes['showLocalNotification'] as YamlMap)['params'];
    final payload = _description((params as YamlMap)['payload']);
    expect(payload, contains('Absent, the tap hands "" (an empty string).'));
    expect(payload, isNot(contains('null')));
  });
}
