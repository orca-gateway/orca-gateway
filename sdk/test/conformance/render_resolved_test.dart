// Client-side resolution spec (Epic 23b, 23b.6).
//
// Render fixtures carry the wire nodes with their Values unresolved plus the
// page/app state they were authored against. A fixture with a `resolved`
// map pins what the client resolver must produce for each listed prop.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

import 'fixture_paths.dart';

void main() {
  var covered = 0;
  for (final file in fixtureFiles('render')) {
    final fx = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final resolved = fx['resolved'];
    if (resolved is! Map) continue;
    covered++;
    final name = file.uri.pathSegments.last;

    test('$name · resolved props', () {
      final context = fx['context'] as Map<String, dynamic>;
      final state = <String, dynamic>{
        ...Map<String, dynamic>.from((context['appState'] as Map?) ?? {}),
        ...Map<String, dynamic>.from((context['pageState'] as Map?) ?? {}),
      };
      final resolver = ValueResolver(state: state);
      final nodes = {for (final n in fx['expected'] as List) n['id']: n};
      for (final entry in resolved.entries) {
        final node = nodes[entry.key] as Map?;
        expect(node, isNotNull, reason: 'node ${entry.key} missing');
        final props = Map<String, dynamic>.from(node!['props'] as Map);
        for (final prop in (entry.value as Map).entries) {
          final got = resolver.resolveDeep(props[prop.key]);
          expect(got, equals(prop.value), reason: '${entry.key}.${prop.key}');
        }
      }
    });
  }

  test('at least one render fixture carries a resolved map', () {
    expect(covered, greaterThan(0));
  });
}
