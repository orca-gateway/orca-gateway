// Conformance runner for `schema/fixtures/actions/*.json` (Epic 23b, 23b.5).
//
// Each fixture seeds page/app state, runs its actions (or steps) through the
// real ActionExecutor (no BuildContext, so nothing is drawn), then asserts the
// resulting state and the effects the executor emitted as data. The Flutter
// SDK runs these first; the Swift and Kotlin SDKs load the same files.
//
// Optional `handlers: [String]` (native parity step 16): before the actions
// run, the runner registers a recording handler under each name, which
// appends `{"kind": "handler", "name": <the name it was registered under>,
// "action": <a copy of the raw action map it received>}` to the effects.
// Fixtures without `handlers` run exactly as before.
//
// Optional `saved`, `expected.saved` and `load` (native parity step 14,
// C14.6): `saved` seeds the SavedState's local (an in-memory store, then the
// boot's load) and session storages, reset for every fixture; `load` sets state
// up as a boot and a page load do, so saved entries are restored;
// `expected.saved` is compared exactly, local both in the mirror and the store.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// An in-memory `SharedPreferencesAsync`: SavedState stores strings only.
class _MemoryPrefs implements SharedPreferencesAsync {
  final Map<String, String> data = {};

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async => data.keys
      .where((k) => allowList == null || allowList.contains(k))
      .toSet();

  @override
  Future<String?> getString(String key) async => data[key];

  @override
  Future<void> setString(String key, String value) async => data[key] = value;

  @override
  Future<bool> containsKey(String key) async => data.containsKey(key);

  @override
  Future<void> remove(String key) async => data.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used');
}

/// The entries of [storage] (`local` or `session`) in a fixture's `saved`.
Map<String, dynamic> _entries(Object? saved, String storage) =>
    saved is Map && saved[storage] is Map
    ? Map<String, dynamic>.from(saved[storage] as Map)
    : <String, dynamic>{};

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

      // The session storage is process-wide: each fixture starts without it.
      SavedState.resetSession();
      final prefs = _MemoryPrefs();
      final manager = StateManager(saved: SavedState(prefs: prefs));

      // `saved` seeds both storages: session first, through the SavedState,
      // then local through the store and the boot's load (in this order a key
      // seeded in both stays in both).
      Future<void> seedSaved() async {
        for (final entry in _entries(fx['saved'], 'session').entries) {
          for (final e in (entry.value as Map).entries) {
            await manager.saved.save(
              entry.key,
              e.key as String,
              e.value,
              'session',
            );
          }
        }
        _entries(
          fx['saved'],
          'local',
        ).forEach((entry, values) => prefs.data[entry] = jsonEncode(values));
        await manager.loadSaved();
      }

      // Without `load` the state is seeded as is and nothing is restored.
      // With it, the runner boots (app state, then the saved app entry over
      // it) and loads the page from `load.state`, its saved entry restored.
      final load = fx['load'];
      if (load is Map) {
        expect(pageState, isEmpty, reason: 'with load, state.page is {}');
        await seedSaved();
        appState.forEach(manager.setAppState);
        manager.restoreApp();
        manager.initPage(pageId, [
          for (final d in (load['state'] as List).cast<Map>())
            StateDefinition.fromJson(Map<String, dynamic>.from(d)),
        ]);
      } else {
        manager.initPage(pageId, [
          for (final e in pageState.entries)
            StateDefinition(key: e.key, scope: 'page', initial: e.value),
        ]);
        appState.forEach(manager.setAppState);
        await seedSaved();
      }

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
      for (final name in (fx['handlers'] as List? ?? const []).cast<String>()) {
        executor.registerHandler(
          name,
          (action, _) async => effects.add({
            'kind': 'handler',
            'name': name,
            'action': Map<String, dynamic>.from(action),
          }),
        );
      }

      // `actions` run with the fixture's event and no source. `steps` run in
      // order, each with the widget and trigger that fired it (`source`, so
      // once can dedupe) and its own `event` in place of the fixture's.
      final event = fx['event'];
      final fixtureEvent = event is Map
          ? Map<String, dynamic>.from(event)
          : null;
      final steps =
          fx['steps'] as List? ??
          [
            for (final action in fx['actions'] as List) {'action': action},
          ];
      for (final step in steps.cast<Map>()) {
        final source = step['source'];
        final stepEvent = step['event'];
        await executor.execute(
          Map<String, dynamic>.from(step['action'] as Map),
          eventData: stepEvent is Map
              ? Map<String, dynamic>.from(stepEvent)
              : fixtureEvent,
          source: source is Map
              ? ActionSource(
                  widgetId: source['widgetId'] as String,
                  trigger: source['trigger'] as String,
                )
              : null,
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

      // `expected.saved` is compared exactly: an entry it does not list must
      // not exist. The actions write only the app entry and this page's, so
      // those names and every name the fixture mentions cover all of them.
      final wantSaved = expected['saved'];
      if (wantSaved is Map) {
        final names = {
          SavedState.appEntry,
          SavedState.pageEntry(pageId),
          for (final saved in [fx['saved'], wantSaved])
            for (final storage in ['local', 'session'])
              ..._entries(saved, storage).keys,
        };
        for (final storage in ['local', 'session']) {
          expect(
            {
              for (final name in names)
                if (manager.saved.entryOf(storage, name).isNotEmpty)
                  name: manager.saved.entryOf(storage, name),
            },
            equals(_entries(wantSaved, storage)),
            reason: 'saved $storage',
          );
        }
        expect(
          {for (final e in prefs.data.entries) e.key: jsonDecode(e.value)},
          equals(_entries(wantSaved, 'local')),
          reason: 'saved local, as the store holds it',
        );
      }
    });
  }
}
