// T3.5, DevTools side: every event in schema/fixtures/devtools parses, and
// carries the payload fields schema/devtools-events.schema.json requires for
// its type. The SDKs build these same files in their own tests, so a field
// DevTools needs cannot drift out of either side without a red test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway_devtools/server/event_parser.dart';

/// `schema/<rest>` found by walking up from the working directory
/// (`flutter test` runs from devtools/).
File _schemaFile(String rest) {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File('${dir.path}/schema/$rest');
    if (candidate.existsSync()) return candidate;
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  throw StateError('schema/$rest not found above ${Directory.current.path}');
}

void main() {
  final schema = jsonDecode(_schemaFile('devtools-events.schema.json').readAsStringSync())
      as Map<String, dynamic>;
  final definitions = schema['definitions'] as Map<String, dynamic>;
  final types = ((schema['properties'] as Map)['type'] as Map)['enum'] as List;

  /// Event type to its payload definition, read from the schema's if/then.
  final payloadDefinition = <String, Map<String, dynamic>>{
    for (final rule in schema['allOf'] as List)
      ((rule['if']['properties']['type']['const']) as String): definitions[
          ((rule['then']['properties']['payload'][r'$ref']) as String).split('/').last]
          as Map<String, dynamic>,
  };

  final fixtures = Directory(_schemaFile('fixtures/devtools/action.json').parent.path)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the schema maps every event type to a payload', () {
    expect(payloadDefinition.keys.toSet(), types.toSet());
  });

  test('every event type has a fixture', () {
    final seen = {for (final f in fixtures) jsonDecode(f.readAsStringSync())['type']};
    expect(seen, types.toSet());
  });

  for (final file in fixtures) {
    final name = file.uri.pathSegments.last;
    test('$name parses with the fields its type requires', () {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final event = EventParser.parse(json);
      expect(event, isNotNull);
      expect(event!.type, json['type']);
      expect(event.deviceId, 'fixture-device');
      expect(event.toJson(), json);

      final required = (payloadDefinition[event.type]!['required'] as List).cast<String>();
      for (final key in required) {
        expect(event.payload.containsKey(key), isTrue, reason: '$name: payload.$key');
      }
    });
  }

  test('an event missing part of the envelope is dropped', () {
    expect(EventParser.parse({'type': 'error', 'deviceId': 'd', 'payload': <String, dynamic>{}}), isNull);
  });
}
