// SDK safe-degrade test (Epic 25b, task 25b.9).
//
// The server-side counterpart of this slice — the TS encoder — refuses to
// emit unknown widget types at encode time, which is correct: a trusted
// server should never produce wire format it can't validate. That means this
// path (unknown type → safe-degrade to FallbackPrompt) can't be exercised
// through normal end-to-end flows. Instead we fabricate the wire JSON
// directly, feed it to ComponentRenderer, and assert:
//
//   1. The unknown type renders a FallbackPrompt subtree, not an ErrorWidget
//      or a blank region.
//   2. OrcaTelemetry.onEvent fires exactly once with the unknown type name.
//   3. A second unknown node with the same type in the same session does NOT
//      fire the callback again (dedup).
//   4. resetForTesting() clears the dedup so a subsequent render reports.
//
// The four assertions together are the full safety-net spec in 25b.9.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

void main() {
  group('SDK safe-degrade on unknown component type', () {
    late ComponentRegistry registry;
    late ComponentRenderer renderer;
    late List<Map<String, dynamic>> events;

    setUp(() {
      registry = ComponentRegistry();
      registry.registerDefaults();
      renderer = ComponentRenderer(registry: registry);
      events = <Map<String, dynamic>>[];
      OrcaTelemetry.onEvent = (event, data) {
        events.add(<String, dynamic>{'event': event, 'data': data});
      };
    });

    tearDown(() {
      OrcaTelemetry.onEvent = null;
      OrcaTelemetry.resetForTesting();
    });

    ComponentNode makeUnknown(String id, String type) {
      return ComponentNode(
        id: id,
        type: type,
        kind: 'primitive',
        childMode: 'none',
        props: const <String, dynamic>{},
        children: const <String>[],
        watches: const <String>[],
      );
    }

    testWidgets('renders FallbackPrompt instead of ErrorWidget', (tester) async {
      final nodes = [makeUnknown('root', 'FutureWidget')];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      // The FallbackPrompt builder renders a Column with a title Text and a
      // body Text. Assert the body text contains the unknown type name the
      // renderer substituted in — this proves the synthesized FallbackPrompt
      // node made it to the builder and rendered the safe-degrade message,
      // not the registry's unknown-type branch.
      expect(find.text('Unsupported content'), findsOneWidget);
      expect(
        find.textContaining('"FutureWidget"'),
        findsOneWidget,
        reason: 'body should mention the unknown type that triggered fallback',
      );

      // And the classic "red" ErrorWidget should NOT be in the tree.
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('OrcaTelemetry fires exactly once per unknown type', (tester) async {
      final nodes = [makeUnknown('root', 'FutureWidget')];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(events, hasLength(1));
      expect(events.first['event'], 'unknown_widget_type');
      expect(events.first['data'], <String, dynamic>{'type': 'FutureWidget'});
    });

    testWidgets('repeated unknown types are deduped within a session', (tester) async {
      // Render FutureWidget twice in a row — second render must NOT fire the
      // callback, because session dedup kicks in.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render([makeUnknown('a', 'FutureWidget')]),
        ),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render([makeUnknown('b', 'FutureWidget')]),
        ),
      );

      expect(events, hasLength(1),
          reason: 'second occurrence of the same unknown type must be deduped');

      // A DIFFERENT unknown type should fire a fresh event — dedup is
      // per-type, not global.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render([makeUnknown('c', 'EvenFuturerWidget')]),
        ),
      );

      expect(events, hasLength(2));
      expect(events[1]['data'], <String, dynamic>{'type': 'EvenFuturerWidget'});
    });

    testWidgets('resetForTesting clears dedup state', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render([makeUnknown('a', 'FutureWidget')]),
        ),
      );
      expect(events, hasLength(1));

      OrcaTelemetry.resetForTesting();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render([makeUnknown('b', 'FutureWidget')]),
        ),
      );

      expect(events, hasLength(2),
          reason: 'after reset, the same unknown type should fire again');
    });
  });

  group('SdkCapabilities vector', () {
    test('exposes non-empty capability sets', () {
      // Not a behavior test — just a smoke check that the code-generated
      // capabilities file is actually populated. If gen-sdk-capabilities.ts
      // ever emits an empty vector (e.g. because its scraping regex broke),
      // the rest of the capability negotiation pipeline would silently
      // report "I can render nothing" and the server would always fall back.
      // Failing loudly here makes that regression impossible to miss.
      expect(kSupportedWidgets, contains('FallbackPrompt'));
      expect(kSupportedWidgets, contains('Text'));
      expect(kSupportedValueKinds, contains('static'));
      expect(kSupportedActionKinds, contains('navigate'));
      expect(kSupportedTransformKinds, contains('toString'));
      expect(kSupportedBoolExprOps, contains('eq'));
    });

    test('toVector returns the full capability map', () {
      final v = SdkCapabilities.toVector();
      expect(v['protocolVersion'], kProtocolVersion);
      expect(v['sdkSemver'], kSdkSemver);
      expect(v['widgets'], contains('FallbackPrompt'));
    });
  });
}
