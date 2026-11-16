// Conformance runner for `schema/fixtures/offline/*.json` (native parity step
// 14, cases C14.1-F .. C14.5-F).
//
// Flutter is the oracle of this family: every case seeds a store with the
// fixture's `saved` keys, answers /version and /config from the fixture over
// `MockClient` (recording the requests in order), and runs the real
// `OrcaApp.preload` with a real `StaticFlowManager` over that store. Flutter's
// saves are fire-and-forget, so the runner lets the event queue drain before it
// reads the store back. Then, when the boot gave a config, it calls
// `initDynamicPaths(config.flows)` and asks `getCachedPage` for every `serves`
// path, as an `OrcaPage` does. The Swift and Kotlin cores run the same files
// and must give the same values.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:orca_gateway/orca_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_paths.dart';

const _configKey = 'orca_nav_config';
const _versionsKey = 'orca_flow_versions';
const _pagesPrefix = 'orca_pages_';

/// Case ids (phase-c-tests.md rows) per case name, for the test names.
const _rowsOf = <String, List<String>>{
  'first online boot': ['C14_1', 'C14_2'],
  'fresh: saved versions equal the remote ones': ['C14_3'],
  'fresh with no saved config': ['C14_3'],
  'stale: a flow version moved': ['C14_3'],
  'offline with a saved config': ['C14_1', 'C14_2'],
  'offline is any /version failure, an error status too': ['C14_2'],
  'offline with nothing saved': ['C14_2', 'C14_5'],
  'force update wins over a stale version': ['C14_5'],
  'cleanup: a versioned flow gone from the refetched config': ['C14_4'],
  'an unversioned flow gone from the config keeps its pages': ['C14_4'],
  'a dynamic route is never served, even with a saved page': ['C14_4'],
  'the cache reads the saved pages, not the pages inside the config': ['C14_1'],
  'quirk: an unversioned flow keeps the boot stale': ['C14_3'],
  'a stale boot whose /config fails does not fall back': ['C14_3', 'C14_5'],
};

const _caseKeys = {
  'name',
  'description',
  'saved',
  'version',
  'config',
  'expected',
};
const _expectedKeys = {'requests', 'result', 'saved', 'serves'};

/// An in-memory `SharedPreferencesAsync`: the manager stores strings only.
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

/// The JSON text a fixture value is stored or served as.
String _text(Object? value) => jsonEncode(value);

http.Response _answer(Object answer) {
  if (answer == 'fail') throw http.ClientException('offline');
  final a = answer as Map;
  return http.Response(_text(a['body']), a['status'] as int);
}

void _expectWellFormed(Map<String, dynamic> c, String label) {
  expect(c.keys.toSet().difference(_caseKeys), isEmpty, reason: label);
  for (final k in ['name', 'description', 'saved', 'version', 'expected']) {
    expect(c.containsKey(k), isTrue, reason: '$label: $k');
  }
  expect(c['description'], isA<String>(), reason: label);
  expect(c['saved'], isA<Map>(), reason: '$label: saved');
  for (final k in (c['saved'] as Map).keys) {
    expect(
      k == _configKey || k == _versionsKey || '$k'.startsWith(_pagesPrefix),
      isTrue,
      reason: '$label: saved key $k',
    );
  }
  final v = c['version'];
  expect(v == 'fail' || v is Map, isTrue, reason: '$label: version');
  if (c.containsKey('config')) {
    expect(c['config'], isA<Map>(), reason: '$label: config');
  }
  final e = c['expected'];
  expect(e, isA<Map>(), reason: label);
  expect((e as Map).keys.toSet(), _expectedKeys, reason: label);
  expect(
    e['requests'],
    everyElement(isIn(['version', 'config'])),
    reason: '$label: requests',
  );
  final r = e['result'];
  expect(
    r == 'forceUpdate' ||
        (r is Map && r.keys.length == 1 && r.keys.first == 'config') ||
        (r is Map && r.keys.length == 1 && r.keys.first == 'error'),
    isTrue,
    reason: '$label: result',
  );
  expect(e['saved'], isA<Map>(), reason: '$label: expected saved');
  expect(e['serves'], isA<Map>(), reason: '$label: serves');
  if (!(r is Map && r.containsKey('config'))) {
    expect(e['serves'], isEmpty, reason: '$label: serves needs a config');
  }
}

void main() {
  final files = fixtureFiles('offline');

  test('C14 · the offline family holds well-formed fixtures', () {
    expect(files, isNotEmpty);
    final results = <String>{};
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final fx = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(fx.keys.toSet(), {'name', 'description', 'cases'}, reason: name);
      expect(fx['cases'], isA<List>(), reason: name);
      expect(fx['cases'] as List, isNotEmpty, reason: name);
      for (final c in (fx['cases'] as List).cast<Map<String, dynamic>>()) {
        _expectWellFormed(c, '$name · ${c['name']}');
        final r = (c['expected'] as Map)['result'];
        results.add(r is Map ? r.keys.first as String : r as String);
      }
    }
    expect(results, {'config', 'forceUpdate', 'error'});
  });

  for (final file in files) {
    final fx = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final name = file.uri.pathSegments.last;

    for (final c in (fx['cases'] as List).cast<Map<String, dynamic>>()) {
      final rows = _rowsOf[c['name']] ?? const ['C14'];
      test('${rows.join(' ')} · $name · ${c['name']}', () async {
        final saved = (c['saved'] as Map).cast<String, Object?>();
        final expected = c['expected'] as Map<String, dynamic>;

        final prefs = _MemoryPrefs();
        saved.forEach((k, v) => prefs.data[k] = _text(v));
        final configText = c.containsKey('config')
            ? _text((c['config'] as Map)['body'])
            : null;

        final requests = <String>[];
        final mock = http_testing.MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/version')) {
            requests.add('version');
            return _answer(c['version'] as Object);
          }
          if (path.endsWith('/config')) {
            requests.add('config');
            final answer = c['config'];
            if (answer == null) throw http.ClientException('no /config');
            return _answer(answer as Object);
          }
          requests.add(path);
          return http.Response('', 404);
        });
        final client = OrcaClient(baseUrl: 'http://stub.invalid', client: mock);
        final manager = StaticFlowManager(prefs: prefs);

        PreloadResult? result;
        Object? error;
        try {
          result = await OrcaApp.preload(
            client: client,
            appId: 'static-flows',
            flowManager: manager,
          );
        } catch (e) {
          error = e;
        }
        // The saves are fire-and-forget: let them land before reading.
        await pumpEventQueue();

        expect(requests, expected['requests'], reason: 'requests');

        final want = expected['result'];
        if (want == 'forceUpdate') {
          expect(error, isNull, reason: 'boot error');
          expect(result, isA<PreloadForceUpdate>());
        } else if (want is Map && want.containsKey('error')) {
          expect(result, isNull, reason: 'result');
          final e = want['error'];
          if (e is String) {
            expect(error, isA<Exception>());
            expect('$error', 'Exception: $e');
          } else {
            expect(error, isA<OrcaClientException>());
            expect(
              (error as OrcaClientException).statusCode,
              (e as Map)['status'],
            );
          }
        } else {
          expect(error, isNull, reason: 'boot error');
          expect(result, isA<PreloadSuccess>());
          final config = (result as PreloadSuccess).config;
          expect(
            {for (final f in config.flows) f.name: f.version},
            (want as Map)['config'],
            reason: 'config flows',
          );
        }

        final wantSaved = expected['saved'] as Map<String, dynamic>;
        expect(prefs.data.keys.toSet(), wantSaved.keys.toSet(), reason: 'keys');
        wantSaved.forEach((key, value) {
          final stored = prefs.data[key]!;
          if (key == _configKey) {
            expect(value, anyOf('config', 'saved'), reason: key);
            expect(
              stored,
              value == 'config' ? configText : _text(saved[key]),
              reason: '$key: $value',
            );
          } else if (key == _versionsKey) {
            expect(jsonDecode(stored), value, reason: key);
          } else {
            expect(
              (jsonDecode(stored) as Map).keys.toSet(),
              (value as List).toSet(),
              reason: key,
            );
          }
        });

        final serves = expected['serves'] as Map<String, dynamic>;
        if (result is PreloadSuccess) {
          final flows = result.config.flows;
          manager.initDynamicPaths(flows);
          final got = <String, String?>{
            for (final path in serves.keys)
              path: (await manager.getCachedPage(path, flows))?.pageId,
          };
          expect(got, serves, reason: 'serves');
        }
      });
    }
  }
}
