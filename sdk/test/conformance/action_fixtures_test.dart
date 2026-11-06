// Conformance runner for `schema/fixtures/actions/*.json` (Epic 23b, 23b.5).
//
// Each fixture seeds page/app state, runs its actions through the real
// ActionExecutor (no BuildContext, so nothing is drawn), then asserts the
// resulting state and the effects the executor emitted as data. The Flutter
// SDK runs these first; the Swift and Kotlin SDKs load the same files.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

import 'fixture_paths.dart';

/// Replays the fixture's `serverResponses` instead of talking HTTP.
class _StubClient extends OrcaClient {
  final Map<String, dynamic> responses;
  _StubClient(this.responses) : super(baseUrl: 'http://stub.invalid');

  @override
  Future<ActionResponse> executeAction(
    String appId, {
    required String action,
    Map<String, dynamic>? params,
    Map<String, dynamic>? pageState,
    Map<String, dynamic>? appState,
  }) async {
    final stub = responses[action];
    if (stub is! Map) {
      throw OrcaClientException(
        'no stubbed response for "$action"',
        statusCode: 500,
        body: '',
      );
    }
    final error = stub['error'];
    if (error is String) {
      throw OrcaClientException(error, statusCode: 400, body: '');
    }
    return ActionResponse(
      actions: ((stub['actions'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Effects are emitted before the platform call; keep the platform calls
    // from throwing in a plugin-less test binding.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => true,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => 'dev.fluttercommunity.plus/share/success',
    );
  });

  for (final file in fixtureFiles('actions')) {
    final fx = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final name = file.uri.pathSegments.last;

    test('$name · ${fx['name']}', () async {
      final pageId = fx['pageId'] as String;
      final state = fx['state'] as Map<String, dynamic>;
      final pageState = Map<String, dynamic>.from(state['page'] as Map);
      final appState = Map<String, dynamic>.from(state['app'] as Map);

      final manager = StateManager();
      manager.initPage(pageId, [
        for (final e in pageState.entries)
          StateDefinition(key: e.key, scope: 'page', initial: e.value),
      ]);
      appState.forEach(manager.setAppState);

      final effects = <Map<String, dynamic>>[];
      final responses = fx['serverResponses'];
      final executor = ActionExecutor(
        stateManager: manager,
        pageId: pageId,
        appId: 'fixture-app',
        client: responses is Map
            ? _StubClient(Map<String, dynamic>.from(responses))
            : null,
        onEffect: (e) => effects.add(e.toJson()),
      );

      final event = fx['event'];
      for (final action in fx['actions'] as List) {
        await executor.execute(
          Map<String, dynamic>.from(action as Map),
          eventData: event is Map ? Map<String, dynamic>.from(event) : null,
        );
      }

      final expected = fx['expected'] as Map<String, dynamic>;
      final expectedState = expected['state'] as Map<String, dynamic>;
      expect(
        manager.getPageStore(pageId)?.state ?? <String, dynamic>{},
        equals(expectedState['page']),
        reason: 'page state',
      );
      expect(
        manager.appStore.state,
        equals(expectedState['app']),
        reason: 'app state',
      );
      expect(effects, equals(expected['effects']), reason: 'effects');
    });
  }
}
