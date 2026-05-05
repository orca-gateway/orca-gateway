import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:orca_gateway/orca_gateway.dart';

void main() {
  group('VersionResponse', () {
    test('fromJson parses flow versions', () {
      final json = {
        'flows': {'homeFlow': 3, 'profileFlow': 1},
      };
      final response = VersionResponse.fromJson(json);
      expect(response.flows['homeFlow'], 3);
      expect(response.flows['profileFlow'], 1);
      expect(response.forceUpdate, false);
    });

    test('fromJson parses forceUpdate', () {
      final json = {
        'flows': {'main': 2},
        'forceUpdate': true,
      };
      final response = VersionResponse.fromJson(json);
      expect(response.forceUpdate, true);
    });
  });

  group('OrcaClient.fetchVersion', () {
    test('returns VersionResponse on 200', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, '/api/v1/app/testapp/version');
        return http.Response(
          jsonEncode({
            'flows': {'homeFlow': 1},
          }),
          200,
        );
      });

      final client = OrcaClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );
      final result = await client.fetchVersion('testapp');
      expect(result.flows['homeFlow'], 1);
      expect(result.forceUpdate, false);
    });

    test('throws on non-200', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final client = OrcaClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );
      expect(
        () => client.fetchVersion('testapp'),
        throwsA(isA<OrcaClientException>()),
      );
    });
  });

  group('NavFlow static fields', () {
    test('fromJson parses isStatic and version', () {
      final json = {
        'name': 'homeFlow',
        'version': 3,
        'isStatic': true,
        'routes': [],
        'pages': {
          'home': {
            'pageId': 'home',
            'title': 'Home',
            'state': [],
            'components': [
              {
                'id': 'n1',
                'type': 'Text',
                'kind': 'primitive',
                'childMode': 'none',
                'props': {'data': 'Hello'},
                'children': [],
                'watches': [],
              },
            ],
          },
        },
      };

      final flow = NavFlow.fromJson(json);
      expect(flow.isStatic, true);
      expect(flow.version, 3);
      expect(flow.pages, isNotNull);
      expect(flow.pages!['home']!.pageId, 'home');
      expect(flow.pages!['home']!.components.length, 1);
    });

    test('defaults to non-static when fields absent', () {
      final json = {
        'name': 'dynamicFlow',
        'routes': [],
      };
      final flow = NavFlow.fromJson(json);
      expect(flow.isStatic, false);
      expect(flow.version, isNull);
      expect(flow.pages, isNull);
    });
  });

  group('PageResponse.toJson', () {
    test('round-trips correctly', () {
      final original = PageResponse(
        pageId: 'test',
        title: 'Test Page',
        state: [
          const StateDefinition(key: 'count', scope: 'page', initial: 0),
        ],
        components: [
          ComponentNode(
            id: 'n1',
            type: 'Text',
            kind: 'primitive',
            childMode: 'none',
            props: {'data': 'Hello'},
            children: [],
            watches: [],
          ),
        ],
      );

      final json = original.toJson();
      final restored = PageResponse.fromJson(json);

      expect(restored.pageId, 'test');
      expect(restored.title, 'Test Page');
      expect(restored.state.length, 1);
      expect(restored.state[0].key, 'count');
      expect(restored.components.length, 1);
      expect(restored.components[0].props['data'], 'Hello');
    });
  });
}
