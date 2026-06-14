// SDK tests for the anonymous device-id request header (Epic 48).
//
// The cloud counts distinct active devices (MAU) by reading x-orca-device-id
// off every request. OrcaApp resolves the id asynchronously at boot and pushes
// it into the client via setDeviceId — which must invalidate the cached header
// map so the very next request carries it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:orca_gateway/orca_gateway.dart';

http.Response _okPage() => http.Response(
      jsonEncode({
        'pageId': 'home',
        'title': 'T',
        'state': <dynamic>[],
        'components': <dynamic>[],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('x-orca-device-id header', () {
    test('absent before setDeviceId, present after, with the given value', () async {
      final seen = <String?>[];
      final mockClient = http_testing.MockClient((request) async {
        seen.add(request.headers['x-orca-device-id']);
        return _okPage();
      });
      final client = OrcaClient(baseUrl: 'http://localhost:8080', client: mockClient);

      await client.fetchPage('testapp', 'home');
      expect(seen.last, isNull, reason: 'no id until OrcaApp resolves one');

      client.setDeviceId('vendor-abc-123');
      await client.fetchPage('testapp', 'home');
      expect(seen.last, 'vendor-abc-123',
          reason: 'setDeviceId must invalidate the cached header map');
    });

    test('setDeviceId(null) clears the header again', () async {
      String? last;
      final mockClient = http_testing.MockClient((request) async {
        last = request.headers['x-orca-device-id'];
        return _okPage();
      });
      final client = OrcaClient(baseUrl: 'http://localhost:8080', client: mockClient);

      client.setDeviceId('vendor-xyz');
      await client.fetchPage('testapp', 'home');
      expect(last, 'vendor-xyz');

      client.setDeviceId(null);
      await client.fetchPage('testapp', 'home');
      expect(last, isNull, reason: 'clearing the id drops the header');
    });
  });
}
