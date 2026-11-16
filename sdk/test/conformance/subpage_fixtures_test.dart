// Conformance runner for `schema/fixtures/subpage/*.json` (native parity
// step 13, cases B13.4-F and B13.5-F).
//
// The contract is the oracle of this family, not the Flutter widget: every
// file is a list of inputs and the outputs the SubPage contract (S1 to S7 in
// the fixture README) gives for them. The runner drives the pure core in
// `lib/src/state/sub_page_core.dart` and nothing else: no widget, no client.
// The Swift and Kotlin cores load the same files and must give the same
// values.
//
// Every file is first checked against `schema/subpage-fixture.schema.json`
// with the small draft-07 subset validator at the bottom of this file, so a
// misspelt key or a missing expectation fails here and not in three runners.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/src/state/sub_page_core.dart';

import 'fixture_paths.dart';

/// Case id (phase-b-tests.md row) per fixture kind, for the test names.
const _caseIds = <String, String>{
  'merge': 'B13.4-F',
  'actions': 'B13.4-F',
  'request': 'B13.4-F',
  'sequence': 'B13.5-F',
};

Map<String, dynamic> _map(Object? v) => Map<String, dynamic>.from(v as Map);

List<String> _sorted(Iterable<String> ids) => ids.toList()..sort();

void main() {
  final files = fixtureFiles('subpage');
  final schema = _map(
    jsonDecode(
      File(
        '${fixturesDir('subpage').parent.parent.path}/subpage-fixture.schema.json',
      ).readAsStringSync(),
    ),
  );

  test('B13.4-F B13.5-F the family is there, every kind of it', () {
    expect(files.length, greaterThanOrEqualTo(12));
    final kinds = {
      for (final f in files) _map(jsonDecode(f.readAsStringSync()))['kind'],
    };
    expect(kinds, {'merge', 'actions', 'request', 'sequence'});
  });

  for (final file in files) {
    final fileName = file.uri.pathSegments.last;
    final fixture = _map(jsonDecode(file.readAsStringSync()));
    final kind = fixture['kind'] as String?;
    final id = _caseIds[kind] ?? 'B13.4-F';

    test('$id $fileName matches subpage-fixture.schema.json', () {
      expect(_validate(schema, fixture, schema, r'$'), isEmpty);
    });

    final cases = (fixture['cases'] as List?) ?? const [];
    for (final raw in cases) {
      final c = _map(raw);
      test('$id $fileName · ${c['name']}', () {
        switch (kind) {
          case 'merge':
            final input = jsonEncode(c['response']);
            final merged = mergeSubPage(
              c['prefix'] as String,
              _map(c['response']),
            );
            final expected = _map(c['expected']);
            expect(merged.nodes, expected['nodes']);
            expect(merged.state, expected['state']);
            expect(
              jsonEncode(c['response']),
              input,
              reason: 'the response is not changed in place',
            );
          case 'actions':
            final input = jsonEncode(c['actions']);
            expect(
              rewriteSubPageActions(
                c['prefix'] as String,
                c['actions'] as List,
              ),
              c['expected'],
            );
            expect(
              jsonEncode(c['actions']),
              input,
              reason: 'the actions are not changed in place',
            );
          case 'request':
            final expected = _map(c['expected']);
            if (c.containsKey('fetch')) {
              final fetch = _map(c['fetch']);
              final request = subPageRequest(
                fetch['pageId'] as String,
                fetch['params'] == null ? null : _map(fetch['params']),
              );
              expect(request.path, expected['path']);
              expect(request.query, expected['query']);
              expect(
                request.location,
                expected['query'] == ''
                    ? expected['path']
                    : '${expected['path']}?${expected['query']}',
              );
            } else {
              final action = _map(c['action']);
              final prefix = subPagePrefixOf(
                List<String>.from(action['prefixes'] as List),
                action['sourceId'] as String?,
              );
              expect(prefix, expected['prefix']);
              expect(
                subPagePostedState(prefix, _map(action['pageState'])),
                expected['pageState'],
              );
            }
          case 'sequence':
            final mounts = SubPageMounts(c['subPageKey'] as String);
            final state = _map(c['pageState']);
            final steps = c['steps'] as List;
            for (var i = 0; i < steps.length; i++) {
              final step = _map(steps[i]);
              final at = 'step $i (${step['op']})';
              var removed = const <String>[];
              if (step['op'] == 'set') {
                state[step['key'] as String] = step['value'];
              } else {
                final change = mounts.apply(
                  step['op'] == 'mount' ? 'replace' : step['mode'] as String,
                  _map(step['response']),
                  state.keys,
                );
                change.removedStateKeys.forEach(state.remove);
                state.addAll(change.seeds);
                removed = change.removedNodeIds;
                // What the step adds is the merge of its response.
                final merged = mergeSubPage(
                  change.prefix,
                  _map(step['response']),
                );
                expect(change.nodes, merged.nodes, reason: at);
                expect(change.seeds, merged.state, reason: at);
              }
              final expected = _map(step['expected']);
              expect(mounts.prefixes, expected['prefixes'], reason: at);
              expect(mounts.roots, expected['roots'], reason: at);
              expect(_sorted(mounts.nodeIds), expected['nodeIds'], reason: at);
              expect(_sorted(removed), expected['removedNodeIds'], reason: at);
              expect(state, expected['state'], reason: at);
            }
          default:
            fail('unknown kind "$kind"');
        }
      });
    }
  }

  test('B13.4-F the prefix of page 0 and of a joined page', () {
    expect(subPagePrefix('detail'), 'detail:');
    expect(subPagePrefix('detail', 0), 'detail:');
    expect(subPagePrefix('detail', 1), 'detail#1:');
    expect(subPagePrefix('outer:inner', 12), 'outer:inner#12:');
  });

  test('B13.4-F the schema check catches a malformed fixture', () {
    final good = _map(jsonDecode(files.first.readAsStringSync()));
    expect(_validate(schema, good, schema, r'$'), isEmpty);
    final badKind = {...good, 'kind': 'sequence'};
    expect(_validate(schema, badKind, schema, r'$'), isNotEmpty);
    final extraKey = {...good, 'note': 'x'};
    expect(_validate(schema, extraKey, schema, r'$'), isNotEmpty);
    final noCases = {...good, 'cases': <dynamic>[]};
    expect(_validate(schema, noCases, schema, r'$'), isNotEmpty);
    final firstCase = _map((good['cases'] as List).first)..remove('expected');
    final noExpected = {
      ...good,
      'cases': [firstCase],
    };
    expect(_validate(schema, noExpected, schema, r'$'), isNotEmpty);
  });
}

// ── A draft-07 subset validator ─────────────────────────────
//
// Supports what subpage-fixture.schema.json uses: type, required, properties,
// additionalProperties, items, minItems, enum, const, pattern, oneOf and
// local `#/definitions/X` refs. Returns the list of violations, empty when
// the value conforms.
List<String> _validate(
  Map<String, dynamic> schema,
  Object? value,
  Map<String, dynamic> root,
  String path,
) {
  final errors = <String>[];
  final ref = schema[r'$ref'];
  if (ref is String) {
    const local = '#/definitions/';
    if (!ref.startsWith(local)) return ['$path: unsupported ref $ref'];
    final target = (root['definitions'] as Map)[ref.substring(local.length)];
    if (target == null) return ['$path: unknown ref $ref'];
    return _validate(_map(target), value, root, path);
  }

  final type = schema['type'];
  if (type != null) {
    final types = type is List ? type : [type];
    if (!types.any((t) => _isType(t as String, value))) {
      return ['$path: expected $type'];
    }
  }
  if (schema.containsKey('const') &&
      jsonEncode(schema['const']) != jsonEncode(value)) {
    errors.add('$path: expected ${jsonEncode(schema['const'])}');
  }
  final allowed = schema['enum'];
  if (allowed is List && !allowed.contains(value)) {
    errors.add('$path: not one of $allowed');
  }
  final pattern = schema['pattern'];
  if (pattern is String &&
      value is String &&
      !RegExp(pattern).hasMatch(value)) {
    errors.add('$path: does not match $pattern');
  }

  if (value is Map) {
    for (final key in (schema['required'] as List?) ?? const []) {
      if (!value.containsKey(key)) errors.add('$path: missing "$key"');
    }
    final properties = (schema['properties'] as Map?) ?? const {};
    final additional = schema['additionalProperties'];
    for (final entry in value.entries) {
      final at = '$path.${entry.key}';
      if (properties.containsKey(entry.key)) {
        errors.addAll(
          _validate(_map(properties[entry.key]), entry.value, root, at),
        );
      } else if (additional == false) {
        errors.add('$at: not allowed');
      } else if (additional is Map) {
        errors.addAll(_validate(_map(additional), entry.value, root, at));
      }
    }
  }
  if (value is List) {
    final min = schema['minItems'];
    if (min is int && value.length < min) {
      errors.add('$path: fewer than $min items');
    }
    final items = schema['items'];
    if (items is Map) {
      for (var i = 0; i < value.length; i++) {
        errors.addAll(_validate(_map(items), value[i], root, '$path[$i]'));
      }
    }
  }

  final oneOf = schema['oneOf'];
  if (oneOf is List) {
    final failures = [
      for (final branch in oneOf) _validate(_map(branch), value, root, path),
    ];
    final passed = failures.where((f) => f.isEmpty).length;
    if (passed != 1) {
      errors.add('$path: matches $passed of ${oneOf.length} shapes');
      // The branch that came closest says what is wrong.
      failures.sort((a, b) => a.length.compareTo(b.length));
      if (passed == 0) errors.addAll(failures.first);
    }
  }
  return errors;
}

bool _isType(String type, Object? value) => switch (type) {
  'object' => value is Map,
  'array' => value is List,
  'string' => value is String,
  'boolean' => value is bool,
  'number' => value is num,
  'integer' => value is int,
  'null' => value == null,
  _ => false,
};
