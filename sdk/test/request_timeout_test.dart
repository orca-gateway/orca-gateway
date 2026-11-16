// OrcaClient's request timeout (C18.5 of the native parity plan).
//
// `OrcaClient(timeout:)`, 30 s by default, bounds every request the client
// sends, from the send to the last byte of the answer. A slower request fails
// with a SocketException, so the error screen shows Connection Failed, as the
// Swift and Kotlin SDKs show their own timeout errors.

import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:orca_gateway/orca_gateway.dart';

const _short = Duration(milliseconds: 100);
const _slow = Duration(milliseconds: 1500);

String _pageJson() => jsonEncode({
      'pageId': 'home',
      'title': 'T',
      'state': <dynamic>[],
      'components': <dynamic>[],
    });

/// Answers every request with a page, after [delay].
http.Client _answerAfter(Duration delay) => http_testing.MockClient((request) async {
      await Future<void>.delayed(delay);
      return http.Response(_pageJson(), 200, headers: {'content-type': 'application/json'});
    });

/// Sends its headers at once and the body only after [delay].
http.Client _bodyAfter(Duration delay) => http_testing.MockClient.streaming((request, _) async {
      final body = Future<List<int>>.delayed(delay, () => utf8.encode(_pageJson()));
      return http.StreamedResponse(Stream.fromFuture(body), 200,
          headers: {'content-type': 'application/json'});
    });

/// Runs [request] and returns how long it took to fail, and its error.
Future<(Duration, Object?)> _failure(Future<Object?> Function() request) async {
  final watch = Stopwatch()..start();
  Object? error;
  try {
    await request();
  } catch (e) {
    error = e;
  }
  return (watch.elapsed, error);
}

void main() {
  group('C18.5 the request timeout', () {
    test('defaults to 30 seconds', () {
      expect(OrcaClient(baseUrl: 'http://localhost:8080').timeout, const Duration(seconds: 30));
    });

    test('an answer slower than the timeout fails at the timeout with a SocketException', () async {
      final client = OrcaClient(baseUrl: 'http://localhost:8080', timeout: _short, client: _answerAfter(_slow));
      final (elapsed, error) = await _failure(() => client.fetchPage('testapp', 'home'));
      expect(error, isA<SocketException>());
      expect(elapsed, lessThan(_slow), reason: 'it failed at the timeout, not when the answer came');
    });

    test('a body that arrives after the timeout fails too: the whole answer is timed', () async {
      final client = OrcaClient(baseUrl: 'http://localhost:8080', timeout: _short, client: _bodyAfter(_slow));
      final (elapsed, error) = await _failure(() => client.fetchPage('testapp', 'home'));
      expect(error, isA<SocketException>());
      expect(elapsed, lessThan(_slow));
    });

    test('an answer within the timeout succeeds', () async {
      final client = OrcaClient(
        baseUrl: 'http://localhost:8080',
        timeout: const Duration(seconds: 5),
        client: _answerAfter(const Duration(milliseconds: 20)),
      );
      final page = await client.fetchPage('testapp', 'home');
      expect(page.pageId, 'home');
    });

    test('every request is timed: the config, an action and the version check', () async {
      final client = OrcaClient(baseUrl: 'http://localhost:8080', timeout: _short, client: _answerAfter(_slow));
      for (final request in <Future<Object?> Function()>[
        () => client.fetchConfig('testapp'),
        () => client.executeAction('testapp', action: 'increment'),
        () => client.fetchVersion('testapp'),
      ]) {
        final (elapsed, error) = await _failure(request);
        expect(error, isA<SocketException>());
        expect(elapsed, lessThan(_slow));
      }
    });

    test('a best-effort request gives up at the timeout', () async {
      final client = OrcaClient(baseUrl: 'http://localhost:8080', timeout: _short, client: _answerAfter(_slow));
      final watch = Stopwatch()..start();
      final sent = await client.sendEvents('testapp', [
        {'name': 'tap'},
      ]);
      expect(sent, isFalse);
      expect(watch.elapsed, lessThan(_slow));
    });

    testWidgets('the error screen shows a timeout as Connection Failed, as the native SDKs do', (tester) async {
      final client = OrcaClient(baseUrl: 'http://localhost:8080', timeout: _short, client: _answerAfter(_slow));
      final (_, error) = (await tester.runAsync(() => _failure(() => client.fetchPage('testapp', 'home'))))!;
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: buildOrcaError(error!)));
      expect(find.text('Connection Failed'), findsOneWidget);
      expect(find.text('Unable to reach the server. Please check your network and server status.'), findsOneWidget);
    });
  });
}
