// C17.5/yaml: plugins/orca_google_map/orca_plugin.yaml has a `schema:`
// section, in the format the CLI's parser reads, describing what the Flutter
// plugin implements: the GoogleMap widget and its seven props (markers a list
// of MapMarker objects), its four triggers with the eventData they fire and the
// moveCamera action with its params. The Swift, Kotlin and TypeScript
// generators read it, so this test pins it against the names the Dart plugin
// registers and reads (lib/src/google_map_plugin.dart), and its notes against
// what Flutter does with a value of the wrong type: change one without the
// other and it fails.

import 'dart:io';

import 'package:orca_gateway_cli/src/manifest/plugin_manifest.dart';
import 'package:orca_gateway_cli/src/manifest/plugin_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The Google Map plugin (tests run from cli/).
final _plugin = p.normalize(p.absolute('..', 'plugins', 'orca_google_map'));
final _manifest = p.join(_plugin, 'orca_plugin.yaml');

/// The Flutter plugin's source, the reference the schema describes.
final _dart = File(
  p.join(_plugin, 'lib', 'src', 'google_map_plugin.dart'),
).readAsStringSync();

/// The SDK source of [path] under sdk/lib/src/, for what its reads do with a
/// value of the wrong type.
String _sdk(String path) => File(
  p.normalize(p.absolute('..', 'sdk', 'lib', 'src', path)),
).readAsStringSync();

/// The yaml type of a Dart type Flutter reads a value as.
const _yamlType = {
  'String': 'string',
  'bool': 'boolean',
  'num': 'number',
  'List': 'array',
};

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

/// The GoogleMap widget as written.
YamlMap _rawWidget() => (_raw()['widgets'] as YamlMap)['GoogleMap'] as YamlMap;

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
  expect(start, isNot(-1), reason: '$name is in google_map_plugin.dart');
  return _dart.substring(start, _dart.indexOf('\n}\n', start));
}

/// [code] with each run of whitespace as one space.
String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

/// The description the yaml gives [map].
String _description(Object? map) =>
    (map as YamlMap)['description'] as String? ?? '';

void main() {
  test('C17.5/yaml the widget is GoogleMap with Flutter\'s props', () {
    final widgets = _registered('widgets');
    expect(_schema().widgets.keys.toList(), widgets.keys.toList());

    final widget = _schema().widgets['GoogleMap']!;
    final notes = _rawWidget()['props'] as YamlMap;
    expect(widget.kind, 'primitive');

    // `final x = (ctx.prop<num>('name'))?.toDouble() ?? fallback;`,
    // `final x = ctx.prop<T>('name');` or `ctx.propOr<T>('name', fallback);`.
    final build = _function(widgets['GoogleMap']!);
    final reads = RegExp(
      r"final (\w+) = \(?ctx\.prop(?:Or)?<(\w+)>\('(\w+)'(?:, ([^)]+))?\)\)?"
      r'(?:\?\.toDouble\(\))?(?:\s*\?\?\s*([^;]+))?;',
    ).allMatches(build).toList();
    expect(widget.props.keys.toList(), [for (final m in reads) m[3]]);

    // OrcaComponentContext.prop and propOr cast what they resolve `as T?`,
    // with no type check: a value of another type throws in the build.
    final context = _sdk(p.join('rendering', 'component_context.dart'));
    for (final method in [
      'T? prop<T>(String key)',
      'T propOr<T>(String key,',
    ]) {
      final start = context.indexOf(method);
      expect(start, isNot(-1), reason: method);
      final body = context.substring(start, context.indexOf('\n  }\n', start));
      expect(body, contains(' as T?'), reason: method);
      expect(body, isNot(matches(RegExp(r'\bis!? T\b'))), reason: method);
    }

    for (final m in reads) {
      final local = m[1]!;
      final name = m[3]!;
      final note = notes[name] as YamlMap;
      expect(widget.props[name]!.type, _yamlType[m[2]], reason: name);
      expect(
        _description(note).toLowerCase(),
        contains("a non-${_yamlType[m[2]]} fails the map's build"),
        reason: '$name of another type',
      );
      // Every read has a fallback or is null-checked: none is required.
      expect(widget.props[name]!.required, isFalse, reason: '$name required');

      final fallback = m[4] ?? m[5];
      if (fallback != null) {
        expect(
          note['default'],
          loadYaml(fallback),
          reason: '$name has Flutter\'s default',
        );
      } else if (m[2] == 'String') {
        // mapType: a switch whose cases are the enum, `_` the default.
        final body = RegExp(
          'switch \\($local\\) \\{([^}]*)\\}',
        ).firstMatch(build)!.group(1)!;
        final cases = RegExp(
          r"'(\w+)' => MapType\.(\w+),",
        ).allMatches(body).toList();
        for (final c in cases) {
          expect(c[2], c[1], reason: "'${c[1]}' draws MapType.${c[1]}");
        }
        final otherwise = RegExp(r'_ => MapType\.(\w+),').firstMatch(body)![1]!;
        expect(widget.props[name]!.enumValues, [
          otherwise,
          for (final c in cases) c[1],
        ], reason: '$name is one of Flutter\'s cases');
        expect(note['default'], otherwise, reason: '$name default');
        // Any other string; a non-string throws in prop's cast first.
        expect(_description(note), contains('any other string'), reason: name);
        expect(_description(note), contains(otherwise), reason: name);
      } else {
        // markers: a list walked only when present, no default.
        expect(m[2], 'List', reason: name);
        expect(build, contains('if ($local != null) {'), reason: name);
        expect(note['default'], isNull, reason: '$name has no default');
      }
    }

    // latitude, longitude and zoom go only into the initial camera; after the
    // map is created only moveCamera moves it.
    expect(
      _flat(build),
      contains(
        'initialCameraPosition: CameraPosition( target: LatLng(lat, lng), '
        'zoom: zoom, ),',
      ),
    );
    for (final name in ['latitude', 'longitude', 'zoom']) {
      expect(_description(notes[name]), contains('initial camera'));
      expect(_description(notes[name]), contains('moveCamera'));
    }
  });

  test('C17.5/yaml markers are MapMarker objects with the fields Flutter '
      'reads', () {
    final markers = _schema().widgets['GoogleMap']!.props['markers']!;
    final notes = _rawWidget()['props']['markers'] as YamlMap;
    expect(markers.type, 'array');
    expect(markers.items!.type, 'object');
    expect(markers.items!.objectName, 'MapMarker');
    final fields = markers.items!.objectProps!;
    final fieldNotes = (notes['items'] as YamlMap)['props'] as YamlMap;

    final build = _function('_buildGoogleMap');
    expect(build, contains('for (final m in rawMarkers) {'));
    expect(build, contains('if (m is! Map) continue;'));
    final names = RegExp(
      r"m\['(\w+)'\]",
    ).allMatches(build).map((m) => m[1]!).toList();
    expect(fields.keys.toList(), names);

    // The marker is skipped when one of these is null.
    final skip = RegExp(r'if \(([^)]*)\) continue;').allMatches(build);
    final skipIf = skip.map((m) => m[1]!).join(' || ');
    final skippedNames = <String>[];

    for (final name in names) {
      final where = 'MapMarker.$name';
      final note = fieldNotes[name] as YamlMap;
      // `m['id']?.toString() ?? ''`, `(m['x'] as num?)?.toDouble()` or
      // `m['x'] as String? ?? ''`.
      final read = RegExp(
        "(?:final (\\w+) = )?\\(?m\\['$name'\\]"
        r'(\?\.toString\(\)| as (\w+)\?)\)?(?:\?\.toDouble\(\))?'
        r"(?: \?\? ('[^']*'))?",
      ).firstMatch(build);
      expect(read, isNotNull, reason: '$where is read');
      final type = read![2] == '?.toString()' ? 'string' : _yamlType[read[3]];
      expect(fields[name]!.type, type, reason: where);
      if (read[2] == '?.toString()') {
        // Any value is taken as its text.
        expect(
          _description(note),
          contains('a non-string is used as its text'),
          reason: '$where of another type',
        );
      } else {
        // `as T?` throws on a value of another type, in the map's build.
        expect(
          _description(note),
          contains("a non-$type fails the map's build"),
          reason: '$where of another type',
        );
      }

      final local = read[1];
      final skipped = local != null && skipIf.contains('$local == null');
      expect(fields[name]!.required, skipped, reason: '$where required');
      if (skipped) {
        skippedNames.add(name);
        expect(type, 'number', reason: '$where is skipped when null');
        expect(note['default'], isNull, reason: '$where has no default');
        expect(_description(notes), contains(name), reason: where);
      } else if (read[4] != null) {
        expect(
          note['default'],
          loadYaml(read[4]!),
          reason: '$where has Flutter\'s default',
        );
      } else {
        expect(note['default'], isNull, reason: '$where has no default');
      }
    }
    expect(_description(notes), contains('skipped'));
    // Only a null one skips the marker; a non-number one throws in its
    // `as num?` cast first.
    final either = skippedNames.join(' or ');
    expect(
      _description(notes),
      contains('An entry that is not an object, or lacks $either, is skipped'),
    );
    expect(
      _description(notes),
      contains("a non-number $either fails the map's build"),
    );

    // The id names the marker in onMarkerTap; title and snippet fill the
    // info window.
    expect(build, contains('markerId: MarkerId(id),'));
    expect(_description(fieldNotes['id']), contains('markerId'));
    expect(_flat(build), contains("infoWindow: InfoWindow( title: m['title']"));
    expect(_flat(build), contains("snippet: m['snippet'] as String?, ),"));
    for (final name in ['title', 'snippet']) {
      expect(_description(fieldNotes[name]), contains('info window'));
    }
  });

  test('C17.5/yaml the triggers are Flutter\'s, with the eventData each '
      'fires', () {
    final widget = _schema().widgets['GoogleMap']!;
    final events = _rawWidget()['event_data'] as YamlMap;

    final declared = RegExp(
      r"TriggerDefinition\(\s*name: '(\w+)'",
    ).allMatches(_dart).map((m) => m[1]!).toList();
    expect(widget.triggers, declared);
    expect(events.keys.toList(), declared);

    // The eventData entries of each `fireAction('<trigger>', eventData:
    // {...})`, key to the Dart expression it fires.
    final fired = <String, Map<String, String>>{
      for (final m in RegExp(
        r"fireAction\('(\w+)'(?:, eventData: \{([^}]*)\})?\)",
      ).allMatches(_dart))
        m[1]!: {
          for (final k in RegExp(r"'(\w+)': ([^,]+)").allMatches(m[2] ?? ''))
            k[1]!: k[2]!.trim(),
        },
    };
    expect(fired.keys, unorderedEquals(declared));

    for (final trigger in declared) {
      expect(
        RegExp("fireAction\\('$trigger'").allMatches(_dart),
        hasLength(1),
        reason: '$trigger fires from one place',
      );
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
        if (expr == 'id') {
          // The marker's id, as read for the marker.
          expect(_dart, contains("final id = m['id']?.toString() ?? '';"));
          expect(prop.type, 'string', reason: where);
        } else {
          // LatLng's latitude and longitude, CameraPosition's zoom: doubles.
          expect(expr, endsWith('.$key'), reason: where);
          expect(prop.type, 'number', reason: where);
        }
        expect(_description(props[key]), isNotEmpty, reason: where);
      }
    }

    // onTap, onLongPress and onCameraMove are the map's own callbacks of the
    // same name; onCameraMove fires the camera's target and zoom.
    for (final trigger in ['onTap', 'onLongPress', 'onCameraMove']) {
      expect(
        _dart,
        matches(
          RegExp("\\b$trigger: \\(\\w+\\) => ctx\\.fireAction\\('$trigger'"),
        ),
        reason: trigger,
      );
    }
    expect(fired['onCameraMove']!['latitude'], 'position.target.latitude');
    expect(
      _description(events['onCameraMove']),
      contains('while the camera moves'),
    );

    // onMarkerTap is the marker's onTap; the tap is not consumed, so the map
    // also opens the marker's info window.
    expect(_dart, contains("onTap: () => ctx.fireAction('onMarkerTap'"));
    expect(_dart, isNot(contains('consumeTapEvents')));
    expect(_description(events['onMarkerTap']), contains('info window'));
  });

  test('C17.5/yaml the moveCamera action and the params Flutter\'s handler '
      'reads', () {
    final handlers = _registered('actions');
    final actions = _schema().actions;
    final notes = _raw()['actions'] as YamlMap;
    expect(handlers, hasLength(1));
    expect(actions.keys.toList(), handlers.keys.toList());

    final body = _function(handlers['moveCamera']!);
    expect(
      body,
      isNot(contains('fireAction')),
      reason: 'moveCamera fires none',
    );
    final reads = RegExp(
      r"action\['(\w+)'\]",
    ).allMatches(body).map((m) => m[1]!).toList();
    final params = actions['moveCamera']!.params;
    final paramNotes = (notes['moveCamera'] as YamlMap)['params'] as YamlMap;
    expect(params.keys.toList(), reads);

    // The handler returns without acting when one of these holds.
    final returnIf = RegExp(
      r'if \(([^)]*)\) return;',
    ).allMatches(body).map((m) => m[1]!).join(' || ');

    for (final name in reads) {
      final where = 'moveCamera.$name';
      final read = RegExp.escape("action['$name']");
      final note = paramNotes[name] as YamlMap;
      if (body.contains("executor.resolveString(action['$name'] ?? '')")) {
        // The map node's id: the map registers its controller under it when
        // created; an empty or unknown id finds none and does nothing.
        expect(
          _dart,
          contains('GoogleMapPlugin._controllers[ctx.node.id] = controller;'),
        );
        expect(
          body,
          contains('final controller = GoogleMapPlugin._controllers[$name];'),
        );
        expect(returnIf, contains('controller == null'), reason: where);
        expect(params[name]!.type, 'string', reason: where);
        expect(params[name]!.required, isTrue, reason: '$where required');
        expect(note['default'], isNull, reason: '$where has no default');
        expect(_description(note), contains('node\'s id'), reason: where);
        expect(_description(note), contains('does nothing'), reason: where);
        // resolveString takes any resolved value as its text.
        final executor = _sdk(p.join('state', 'action_executor.dart'));
        const method = 'String resolveString(dynamic raw)';
        final start = executor.indexOf(method);
        expect(start, isNot(-1), reason: method);
        final resolve = executor.substring(
          start,
          executor.indexOf('\n  }\n', start),
        );
        expect(resolve, contains('?.toString()'), reason: method);
        expect(
          _description(note),
          contains('a non-string is used as its text'),
          reason: '$where of another type',
        );
        continue;
      }

      // `final x = (executor.resolveValue(action['x']) as num?)?.toDouble();`
      final number = RegExp(
        'final (\\w+) = \\(executor\\.resolveValue\\($read\\) '
        'as num\\?\\)\\?\\.toDouble\\(\\);',
      ).firstMatch(body);
      expect(number, isNotNull, reason: '$where is read as a number');
      final local = number![1]!;
      expect(params[name]!.type, 'number', reason: where);
      // `as num?` throws on anything else.
      expect(_description(note), contains('non-number fails'), reason: where);

      if (returnIf.contains('$local == null')) {
        // Without it Flutter does nothing, and it has no default.
        expect(params[name]!.required, isTrue, reason: '$where required');
        expect(note['default'], isNull, reason: '$where has no default');
        expect(_description(note), contains('missing does nothing'));
      } else {
        // `x ?? fallback` where the camera is built.
        final fallback = RegExp('\\b$local \\?\\? ([\\w.]+)').firstMatch(body);
        expect(fallback, isNotNull, reason: '$where has a fallback');
        expect(params[name]!.required, isFalse, reason: '$where required');
        expect(
          note['default'],
          loadYaml(fallback![1]!),
          reason: '$where has Flutter\'s default',
        );
      }
    }

    // It animates the camera there.
    expect(body, contains('controller.animateCamera('));
    expect(_description(notes['moveCamera']), contains('Animates'));
  });
}
