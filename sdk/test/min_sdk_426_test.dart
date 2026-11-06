// Epic 25b.6 / 23b.23: a client below the app's minimum SDK version gets
// HTTP 426 with the upgrade screen embedded as `page`. The SDK renders that
// page instead of throwing; a 426 without a page still throws. The body
// below is what engine/src/core/min-sdk-version.ts `buildUpgradeRequiredBody`
// returns (engine/test/caps-policy-e2e.test.ts pins it on the engine side).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:orca_gateway/orca_gateway.dart';

Map<String, dynamic> _upgradeBody() => {
      'error': 'sdk_version_too_old',
      'minSdkVersion': '2.0.0',
      'clientSdkVersion': '0.1.0',
      'page': {
        'pageId': 'home',
        'title': 'Update required',
        'state': <dynamic>[],
        'components': [
          {
            'id': '__min_sdk_block_root__',
            'type': 'FallbackPrompt',
            'kind': 'primitive',
            'childMode': 'none',
            'props': {
              'title': 'Update required',
              'body': 'This app needs version 2.0.0 or later to continue. '
                  'Please update from your app store.',
              'severity': 'blocking',
            },
            'children': <dynamic>[],
            'watches': <dynamic>[],
          },
        ],
      },
    };

void main() {
  test('a 426 with an embedded page returns that page', () async {
    final client = OrcaClient(
      baseUrl: 'http://localhost:8080',
      client: http_testing.MockClient((_) async => http.Response(
            jsonEncode(_upgradeBody()),
            426,
            headers: {'content-type': 'application/json'},
          )),
    );

    final page = await client.fetchPage('testapp', 'home');

    expect(page.title, 'Update required');
    expect(page.components, hasLength(1));
    final root = page.components.single;
    expect(root.id, '__min_sdk_block_root__');
    expect(root.type, 'FallbackPrompt');
    expect(root.props['severity'], 'blocking');
  });

  test('a 426 without a page still throws', () async {
    final client = OrcaClient(
      baseUrl: 'http://localhost:8080',
      client: http_testing.MockClient((_) async => http.Response(
            jsonEncode({'error': 'sdk_version_too_old'}),
            426,
          )),
    );

    expect(
      () => client.fetchPage('testapp', 'home'),
      throwsA(isA<OrcaClientException>()
          .having((e) => e.statusCode, 'statusCode', 426)),
    );
  });

  test('other errors still throw', () async {
    final client = OrcaClient(
      baseUrl: 'http://localhost:8080',
      client: http_testing.MockClient((_) async => http.Response(
            jsonEncode({'error': 'boom', 'page': _upgradeBody()['page']}),
            500,
          )),
    );

    expect(
      () => client.fetchPage('testapp', 'home'),
      throwsA(isA<OrcaClientException>()
          .having((e) => e.statusCode, 'statusCode', 500)),
    );
  });
}
