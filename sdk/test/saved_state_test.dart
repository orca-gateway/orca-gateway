// Saved state (native parity step 14, case C14.6-F, option A): persistState
// saves a key's current value in local (survives a restart) or session (lives
// until the process ends) storage, the value is restored when its scope is set
// up again, and clearState removes the live value and every saved copy.
//
// Every test runs the real StateManager + ActionExecutor over an in-memory
// SharedPreferencesAsync, injected the way the offline runner does it. The
// contract it pins (S1-S5 of the slice) is the one the Swift and Kotlin cores
// follow: one entry per scope, `orca_saved_app` and `orca_saved_page_<pageId>`,
// each a JSON object {key: value}.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _home = 'orca_saved_page_home';
const _app = 'orca_saved_app';

/// An in-memory `SharedPreferencesAsync` holding strings; [fail] makes every
/// call throw, as a broken platform store would.
class _MemoryPrefs implements SharedPreferencesAsync {
  _MemoryPrefs({this.fail = false});

  final Map<String, String> data = {};
  final bool fail;

  void _check() {
    if (fail) throw StateError('store down');
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    _check();
    return data.keys
        .where((k) => allowList == null || allowList.contains(k))
        .toSet();
  }

  @override
  Future<String?> getString(String key) async {
    _check();
    return data[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    _check();
    data[key] = value;
  }

  @override
  Future<bool> containsKey(String key) async {
    _check();
    return data.containsKey(key);
  }

  @override
  Future<void> remove(String key) async {
    _check();
    data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used');
}

/// Answers every page request with a page declaring `count` (initial 0).
class _StubClient extends OrcaClient {
  _StubClient() : super(baseUrl: 'http://stub.invalid');

  @override
  Future<PageResponse> fetchPage(
    String appId,
    String path, {
    Map<String, dynamic>? appState,
  }) async {
    return PageResponse(
      pageId: 'page:$path',
      title: '',
      state: const [StateDefinition(key: 'count', scope: 'page', initial: 0)],
      components: const [],
    );
  }
}

Object? _stored(_MemoryPrefs prefs, String name) {
  final raw = prefs.data[name];
  return raw == null ? null : jsonDecode(raw);
}

const _countDef = StateDefinition(key: 'count', scope: 'page', initial: 0);

void main() {
  late _MemoryPrefs prefs;
  late StateManager manager;
  late ActionExecutor exec;
  late List<ActionEffect> effects;

  Future<void> run(Map<String, dynamic> action) => exec.execute(action);

  Future<void> set(String key, Object? value, [String scope = 'page']) => run({
    'type': 'setState',
    'key': key,
    'scope': scope,
    'value': {'type': 'static', 'value': value},
  });

  Future<void> persist(
    String key, {
    String scope = 'page',
    String storage = 'local',
  }) => run({
    'type': 'persistState',
    'key': key,
    'scope': scope,
    'storage': storage,
  });

  Future<void> clear(String key, [String scope = 'page']) =>
      run({'type': 'clearState', 'key': key, 'scope': scope});

  /// A new StateManager over the same local store, the session left as it is.
  StateManager reopen() => StateManager(saved: SavedState(prefs: prefs));

  setUp(() {
    SavedState.resetSession();
    prefs = _MemoryPrefs();
    manager = reopen();
    manager.initPage('home', const [_countDef]);
    effects = [];
    exec = ActionExecutor(
      stateManager: manager,
      pageId: 'home',
      onEffect: effects.add,
    );
  });

  test('C14_6 · S1 S3 S7 · persistState local writes the page entry as JSON, '
      'no effect', () async {
    await set('count', 3);
    await persist('count');

    expect(prefs.data.keys, [_home]);
    expect(prefs.data[_home], '{"count":3}');
    expect(manager.saved.entryOf('local', _home), {'count': 3});
    expect(manager.saved.entryOf('session', _home), isEmpty);
    expect(effects, isEmpty);
  });

  test('C14_6 · S3 · a persistState without scope or storage saves the page '
      'key locally', () async {
    await set('count', 2);
    await run({'type': 'persistState', 'key': 'count'});

    expect(_stored(prefs, _home), {'count': 2});
  });

  test('C14_6 · S1 S3 · app scope saves under orca_saved_app', () async {
    await set('visits', 4, 'app');
    await persist('visits', scope: 'app');

    expect(prefs.data.keys, [_app]);
    expect(_stored(prefs, _app), {'visits': 4});
  });

  test('C14_6 · S2 S3 · session is process-wide and holds the one saved '
      'copy', () async {
    await set('count', 3);
    await persist('count');
    await persist('count', storage: 'session');

    expect(prefs.data, isEmpty, reason: 'the emptied local entry is deleted');
    expect(manager.saved.entryOf('local', _home), isEmpty);
    expect(manager.saved.entryOf('session', _home), {'count': 3});
    expect(SavedState(prefs: _MemoryPrefs()).entryOf('session', _home), {
      'count': 3,
    }, reason: 'another SavedState sees the same session');

    await persist('count');
    expect(_stored(prefs, _home), {'count': 3});
    expect(manager.saved.entryOf('session', _home), isEmpty);
  });

  test(
    'C14_6 · S3 · a snapshot: a later setState leaves the saved copy',
    () async {
      await set('count', 3);
      await persist('count');
      await set('count', 9);

      expect(_stored(prefs, _home), {'count': 3});
      expect(manager.saved.entryOf('local', _home), {'count': 3});
    },
  );

  test('C14_6 · S3 · a key absent from the live scope changes nothing; a '
      'present null is saved', () async {
    await persist('missing');
    await persist('missing', storage: 'session');
    await persist('visits', scope: 'app');
    expect(prefs.data, isEmpty);
    expect(manager.saved.entryOf('session', _home), isEmpty);

    await set('count', null);
    await persist('count');
    expect(prefs.data[_home], '{"count":null}');
  });

  test('C14_6 · S4 · clearState nulls the live key and removes every saved '
      'copy; an emptied entry is deleted', () async {
    await set('count', 3);
    await set('step', 1);
    await persist('count', storage: 'session');
    await persist('step');
    await set('visits', 5, 'app');
    await persist('visits', scope: 'app');

    await clear('count');
    expect(manager.getPageState('home', 'count'), isNull);
    expect(manager.saved.entryOf('session', _home), isEmpty);
    expect(_stored(prefs, _home), {'step': 1});

    await clear('step');
    expect(prefs.data.containsKey(_home), isFalse);
    expect(manager.saved.entryOf('local', _home), isEmpty);

    await clear('visits', 'app');
    expect(manager.getAppState('visits'), isNull);
    expect(prefs.data, isEmpty);
    expect(effects, isEmpty);
  });

  test('C14_6 · S5 · initPage restores the saved entry over the declared '
      'initials and adds undeclared keys', () async {
    await set('count', 3);
    await set('extra', 'x');
    await persist('count');
    await persist('extra', storage: 'session');

    manager.disposePage('home');
    manager.initPage('home', const [_countDef]);
    expect(manager.getPageStore('home')!.state, {'count': 3, 'extra': 'x'});

    manager.initPage('other', const [_countDef]);
    expect(manager.getPageStore('other')!.state, {'count': 0});
  });

  test('C14_6 · S5 · restoreApp lays the saved app entry over the config; an '
      'app definition does not override it', () async {
    await set('visits', 5, 'app');
    await persist('visits', scope: 'app');

    final again = reopen();
    await again.loadSaved();
    again.setAppState('visits', 0);
    again.setAppState('theme', 'dark');
    again.restoreApp();
    expect(again.appStore.state, {'visits': 5, 'theme': 'dark'});

    again.initPage('home', const [
      StateDefinition(key: 'visits', scope: 'app', initial: 0),
    ]);
    expect(again.getAppState('visits'), 5);
  });

  test('C14_6 · S2 S6 · a restart restores local, not session', () async {
    await set('count', 3);
    await set('extra', 'x');
    await persist('count');
    await persist('extra', storage: 'session');

    SavedState.resetSession();
    final restarted = reopen();
    await restarted.loadSaved();
    restarted.initPage('home', const [
      _countDef,
      StateDefinition(key: 'extra', scope: 'page', initial: 'init'),
    ]);
    expect(restarted.getPageStore('home')!.state, {
      'count': 3,
      'extra': 'init',
    });
  });

  test('C14_6 · S6 · a failing store is swallowed: the actions complete and '
      'the mirror still restores', () async {
    prefs = _MemoryPrefs(fail: true);
    manager = reopen();
    manager.initPage('home', const [_countDef]);
    exec = ActionExecutor(stateManager: manager, pageId: 'home');
    await set('count', 3);
    await persist('count');
    expect(manager.saved.entryOf('local', _home), {'count': 3});

    manager.initPage('home', const [_countDef]);
    expect(manager.getPageState('home', 'count'), 3);

    await clear('count');
    expect(manager.getPageState('home', 'count'), isNull);
    await reopen().loadSaved();
  });

  testWidgets('C14_6 · S5 S6 · OrcaApp loads the saved entries at boot, '
      'restores app state after initialAppState and the first page', (
    tester,
  ) async {
    prefs.data[_app] = '{"visits":5}';
    prefs.data['orca_saved_page_page:home'] = '{"count":7}';
    final booted = reopen();
    final config = NavConfig.fromJson({
      'appId': 'saved-app',
      'appName': 'Saved',
      'initialRoute': '/home',
      'initialAppState': {'visits': 0, 'theme': 'dark'},
      'flows': [
        {
          'name': 'main',
          'routes': [
            {'path': 'home', 'requiredAppState': <String>[]},
          ],
        },
      ],
    });

    await tester.pumpWidget(
      OrcaApp(
        client: _StubClient(),
        appId: 'saved-app',
        preloadedConfig: config,
        stateManager: booted,
      ),
    );
    await tester.pumpAndSettle();

    expect(booted.appStore.state, {'visits': 5, 'theme': 'dark'});
    expect(booted.getPageState('page:home', 'count'), 7);
  });
}
