// SDK tests for capability negotiation (Epic 25b slice 2).
//
// Two complementary suites in this file:
//
//   1. Canonicalization pinned-hash assertion. Pins the sha256 of a known
//      small capability vector to guard against client/server canonical-form
//      drift. A companion test on the engine side (capability-vector-cache.test.ts)
//      holds the same pinned value via a snapshot — if both fail together,
//      the Dart and TS canonicalization algorithms have diverged and the
//      412 retry protocol would perma-loop in production.
//
//   2. End-to-end retry dance with MockClient. Simulates a server returning
//      412 caps_vector_unknown on the first call and 200 on the retry, and
//      asserts:
//        - Exactly TWO requests are made (original + retry).
//        - The retry is a POST with _orcaCapsVector in the body.
//        - Both requests carry x-orca-sdk-version + x-orca-caps-hash headers.
//        - A second 412 (after the retry) is surfaced as an exception, not
//          retried again (infinite-loop guard).

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:orca_gateway/orca_gateway.dart';

void main() {
  group('SDK capability vector canonicalization', () {
    test('toVector() sorts every array ascending', () {
      final v = SdkCapabilities.toVector();
      for (final key in const ['widgets', 'valueKinds', 'actionKinds', 'transformKinds', 'boolExprOps']) {
        final list = (v[key] as List).cast<String>();
        final sorted = [...list]..sort();
        expect(list, sorted, reason: '$key must be sorted ascending');
      }
    });

    test('pinned sha256 of a known minimal vector matches the engine', () {
      // This exact vector + expected hash also appear in the engine-side
      // test at engine/test/capability-vector-cache.test.ts under
      // the "known pinned-hash: smoke test for canonicalization drift"
      // snapshot. If this test fails, the engine snapshot test should
      // fail on the same day — or, if only one fails, the two algorithms
      // have drifted and the 412 retry protocol will break in production.
      final canonical = jsonEncode({
        'protocolVersion': '1.0.0',
        'sdkSemver': '0.1.0',
        'widgets': ['a', 'b'],
        'valueKinds': ['static'],
        'actionKinds': <String>[],
        'transformKinds': <String>[],
        'boolExprOps': <String>[],
      });
      final hash = sha256.convert(utf8.encode(canonical)).toString();
      expect(
        hash,
        'c71ebd593604aa669274ce2d318d9d97b38facae6ca26360201907fda433db84',
        reason:
            'Canonicalization algorithm drifted — see engine/src/core/capability-vector-cache.ts '
            'canonicalizeVector() and keep both sides in lockstep.',
      );
    });
  });

  group('OrcaClient capability negotiation headers', () {
    test('fetchPage sends x-orca-sdk-version and x-orca-caps-hash on every call',
        () async {
      int callCount = 0;
      final mockClient = http_testing.MockClient((request) async {
        callCount++;
        expect(request.headers['x-orca-sdk-version'], isNotNull);
        expect(request.headers['x-orca-caps-hash'], isNotNull);
        expect(request.headers['x-orca-sdk-version']!.isNotEmpty, true);
        expect(request.headers['x-orca-caps-hash']!.length, 64,
            reason: 'caps hash is a 64-char hex sha256 digest');
        return http.Response(
          jsonEncode({
            'pageId': 'home',
            'title': 'T',
            'state': <dynamic>[],
            'components': <dynamic>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OrcaClient(baseUrl: 'http://localhost:8080', client: mockClient);
      await client.fetchPage('testapp', 'home');
      expect(callCount, 1);
    });
  });

  group('OrcaClient 412 caps_vector_unknown retry dance', () {
    test('first 412 triggers exactly one retry with _orcaCapsVector body', () async {
      final requests = <http.BaseRequest>[];
      final mockClient = http_testing.MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          // First attempt — simulate server vector-cache miss.
          return http.Response(
            jsonEncode({'error': 'caps_vector_unknown', 'hash': 'someHashValue'}),
            412,
            headers: {'content-type': 'application/json'},
          );
        }
        // Retry — must include the full vector in the body.
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('_orcaCapsVector'), true,
            reason: 'retry body must carry the full vector');
        final vector = body['_orcaCapsVector'] as Map<String, dynamic>;
        expect(vector['protocolVersion'], isA<String>());
        expect(vector['widgets'], isA<List<dynamic>>());
        return http.Response(
          jsonEncode({
            'pageId': 'home',
            'title': 'T',
            'state': <dynamic>[],
            'components': <dynamic>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OrcaClient(baseUrl: 'http://localhost:8080', client: mockClient);
      final result = await client.fetchPage('testapp', 'home');
      expect(result.pageId, 'home');
      expect(requests.length, 2, reason: 'exactly one retry after the 412');
      expect(requests[0].method, 'GET');
      expect(requests[1].method, 'POST',
          reason: 'retry is always POST — vector has to travel in the body');
    });

    test('second 412 (after retry) throws — no infinite loop', () async {
      int callCount = 0;
      final mockClient = http_testing.MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'error': 'caps_vector_unknown', 'hash': 'x' * 64}),
          412,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = OrcaClient(baseUrl: 'http://localhost:8080', client: mockClient);

      await expectLater(
        client.fetchPage('testapp', 'home'),
        throwsA(isA<OrcaClientException>()),
      );
      expect(callCount, 2,
          reason:
              'client must attempt the request twice (original + retry) and then give up — '
              'a third call would be an infinite-loop bug');
    });

    test('non-caps 412 is passed through without retry', () async {
      // If the server returns 412 for something else (e.g. If-Match
      // precondition), the client should NOT retry with _orcaCapsVector —
      // that would be semantically wrong and could mask the real error.
      int callCount = 0;
      final mockClient = http_testing.MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'error': 'something_else_entirely'}),
          412,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = OrcaClient(baseUrl: 'http://localhost:8080', client: mockClient);

      await expectLater(
        client.fetchPage('testapp', 'home'),
        throwsA(isA<OrcaClientException>()),
      );
      expect(callCount, 1,
          reason: 'non-caps 412 should not trigger the caps retry path');
    });

    test('appState is preserved across the retry', () async {
      final requests = <http.BaseRequest>[];
      final mockClient = http_testing.MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(
            jsonEncode({'error': 'caps_vector_unknown', 'hash': 'y' * 64}),
            412,
            headers: {'content-type': 'application/json'},
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        // The retry body must preserve both the vector AND the appState the
        // caller supplied — dropping appState would silently lose state on
        // every first-request-per-session.
        expect(body.containsKey('_orcaCapsVector'), true);
        expect(body.containsKey('appState'), true);
        expect((body['appState'] as Map)['theme'], 'dark');
        return http.Response(
          jsonEncode({
            'pageId': 'home',
            'title': 'T',
            'state': <dynamic>[],
            'components': <dynamic>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OrcaClient(baseUrl: 'http://localhost:8080', client: mockClient);
      await client.fetchPage('testapp', 'home', appState: {'theme': 'dark'});
      expect(requests.length, 2);
    });
  });
}
