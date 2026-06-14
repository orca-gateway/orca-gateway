// SDK tests for the batched analytics emitter (Epic 47.4).

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/src/telemetry/orca_analytics.dart';

void main() {
  group('OrcaAnalytics', () {
    test('flushes automatically once batchSize is reached', () async {
      final sent = <List<Map<String, dynamic>>>[];
      final a = OrcaAnalytics(
        sender: (events) async {
          sent.add(events);
          return true;
        },
        batchSize: 3,
        flushInterval: const Duration(days: 1), // disable the timer path
      );

      a.track('a');
      a.track('b');
      expect(sent, isEmpty, reason: 'should not flush before batchSize');
      a.track('c'); // hits batchSize → flush
      await Future<void>.delayed(Duration.zero);

      expect(sent, hasLength(1));
      expect(sent.first.map((e) => e['type']), ['a', 'b', 'c']);
      expect(a.bufferedCount, 0);
    });

    test('manual flush sends pending events with type/ts/payload', () async {
      List<Map<String, dynamic>>? got;
      final a = OrcaAnalytics(
        sender: (events) async {
          got = events;
          return true;
        },
        flushInterval: const Duration(days: 1),
      );

      a.track('screen_view', payload: {'screen': 'home'});
      await a.flush();

      expect(got, hasLength(1));
      expect(got!.first['type'], 'screen_view');
      expect(got!.first['payload'], {'screen': 'home'});
      expect(got!.first['ts'], isA<String>());
    });

    test('re-queues the batch when the send fails', () async {
      var ok = false;
      final a = OrcaAnalytics(
        sender: (events) async => ok,
        flushInterval: const Duration(days: 1),
      );

      a.track('x');
      await a.flush(); // sender returns false → re-queued
      expect(a.bufferedCount, 1, reason: 'failed send must not lose the event');

      ok = true;
      await a.flush(); // now succeeds
      expect(a.bufferedCount, 0);
    });

    test('drops oldest events beyond maxBuffer', () async {
      final a = OrcaAnalytics(
        sender: (_) async => true,
        batchSize: 10000, // never auto-flush
        flushInterval: const Duration(days: 1),
        maxBuffer: 5,
      );
      for (var i = 0; i < 20; i++) {
        a.track('e$i');
      }
      expect(a.bufferedCount, 5);
    });

    test('dispose flushes remaining events', () async {
      var sentCount = 0;
      final a = OrcaAnalytics(
        sender: (events) async {
          sentCount += events.length;
          return true;
        },
        flushInterval: const Duration(days: 1),
      );
      a.track('one');
      a.track('two');
      await a.dispose();
      expect(sentCount, 2);
    });
  });
}
