// Trace spec (native parity step 19, C19.1 and C19.2).
//
// Each fixture in schema/fixtures/traces seeds page/app state (merged as the
// renderer and the executor merge them: app first, page over it) and an
// optional event, runs its raw `value` through
// `ValueResolver.resolveWithTrace`, and pins both the resolved value and the
// trace, each step as `TransformTrace.toJson` writes it. The Swift and
// Kotlin SDKs run the same files through their own resolveWithTrace.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

import 'fixture_paths.dart';

void main() {
  final files = fixtureFiles('traces');

  test('the traces folder holds at least one fixture', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    final fx = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final name = file.uri.pathSegments.last;

    test('$name · ${fx['name']}', () {
      final state = fx['state'] as Map<String, dynamic>;
      final event = fx['event'];
      final resolver = ValueResolver(
        state: <String, dynamic>{
          ...Map<String, dynamic>.from((state['app'] as Map?) ?? {}),
          ...Map<String, dynamic>.from((state['page'] as Map?) ?? {}),
        },
        eventData: event is Map ? Map<String, dynamic>.from(event) : null,
      );
      final expected = fx['expected'] as Map<String, dynamic>;

      final (value, trace) = resolver.resolveWithTrace(fx['value']);

      expect(value, equals(expected['value']), reason: 'value');
      expect(
        trace.map((step) => step.toJson()).toList(),
        equals(expected['trace']),
        reason: 'trace',
      );
    });
  }
}
