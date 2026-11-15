// Conformance runner for `schema/fixtures/navigation/*.json` (native parity
// step 9, cases B9.2-F .. B9.10-F).
//
// Flutter is the oracle of this family: every case boots the real `OrcaApp`
// from the fixture's config (`preloadedConfig`, so `initialAppState` is seeded
// and the router comes from `NavigationHandler.buildRouter`), lays the
// fixture's `appState` over the seed, calls `go(location)` on the real
// GoRouter and reads every `expected` field back from what is on screen. The
// Swift and Kotlin cores load the same files and must resolve to the same
// values.
//
// Sessions (native parity step 10, cases B10.2-F and B10.3-F): a file may also
// carry `sessions`, each a list of steps run one after the other on one booted
// app. The runner drives the real thing (the router, the default tab bar, the
// action executor, the state manager) and reads back, after the boot and after
// every step, the visible location, the shell's tab index, the app state keys
// the fixture names and the page paths requested during that step.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show BottomNavigationBar;
import 'package:orca_gateway/orca_gateway.dart';

import 'fixture_paths.dart';

/// Case id (phase-b-tests.md row) per fixture file number, for the test names.
const _caseIds = <String, String>{
  '01': 'B9.2-F',
  '02': 'B9.3-F',
  '03': 'B9.3-F',
  '04': 'B9.4-F',
  '05': 'B9.4-F',
  '06': 'B9.4-F',
  '07': 'B9.5-F',
  '08': 'B9.9-F',
  '12': 'B10.2-F',
  '13': 'B10.3-F',
  '14': 'B10.3-F',
};

const _pageKeys = [
  'kind',
  'location',
  'redirected',
  'pagePath',
  'routePath',
  'params',
  'stack',
  'tabIndex',
  'scaffoldTitle',
];
const _errorKeys = ['kind', 'location', 'redirected'];

const _sessionKeys = {'name', 'boot', 'steps'};
const _observedKeys = {'location', 'tabIndex', 'appState', 'pageRequests'};

/// Keys a step carries per op, `expected` included.
const _stepKeys = <String, Set<String>>{
  'go': {'op', 'location', 'expected'},
  'push': {'op', 'location', 'expected'},
  'back': {'op', 'expected'},
  'tapTab': {'op', 'index', 'expected'},
  'switchTab': {'op', 'tabId', 'expected'},
  'setAppState': {'op', 'key', 'value', 'expected'},
};

/// Answers every page request with a minimal valid page and records the path.
class _StubClient extends OrcaClient {
  final List<String> requests = [];
  _StubClient() : super(baseUrl: 'http://stub.invalid');

  @override
  Future<PageResponse> fetchPage(
    String appId,
    String path, {
    Map<String, dynamic>? appState,
  }) async {
    requests.add(path);
    return PageResponse(
      pageId: 'page:$path',
      title: '',
      state: const [],
      components: const [],
    );
  }
}

/// Page paths of the matched GoRoutes, bottom to top, shells opened up.
List<String> _stackOf(List<RouteMatchBase> matches) {
  final out = <String>[];
  for (final m in matches) {
    if (m is ShellRouteMatch) {
      out.addAll(_stackOf(m.matches));
    } else {
      final loc = m.matchedLocation;
      out.add(loc.startsWith('/') ? loc.substring(1) : loc);
    }
  }
  return out;
}

String _pathOf(String location) => Uri.parse(location).path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final files = fixtureFiles('navigation');

  test('B9.10-F · the family holds at least six well-formed fixtures', () {
    expect(files.length, greaterThanOrEqualTo(6));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final fx = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(fx['name'], isA<String>(), reason: '$name name');
      expect(fx['description'], isA<String>(), reason: '$name description');
      final config = fx['config'];
      expect(config, isA<Map>(), reason: '$name config');
      expect((config as Map)['flows'], isA<List>(), reason: '$name flows');
      expect(config['initialRoute'], isA<String>(), reason: '$name initial');
      if (fx.containsKey('appState')) {
        expect(fx['appState'], isA<Map>(), reason: '$name appState');
      }
      expect(
        fx.containsKey('cases') || fx.containsKey('sessions'),
        isTrue,
        reason: '$name carries cases, sessions or both',
      );
      final sessions = fx['sessions'];
      if (fx.containsKey('sessions')) {
        expect(sessions, isA<List>(), reason: '$name sessions');
        expect(sessions as List, isNotEmpty, reason: '$name sessions');
        for (final s in sessions) {
          final label = '$name · ${(s as Map)['name']}';
          expect(s.keys.toSet(), _sessionKeys, reason: label);
          expect(s['name'], isA<String>(), reason: label);
          final boot = s['boot'];
          expect(boot, isA<Map>(), reason: '$label: boot');
          expect((boot as Map).keys.toSet(), {'expected'}, reason: label);
          _expectObserved(boot['expected'], '$label: boot');
          final steps = s['steps'];
          expect(steps, isA<List>(), reason: '$label: steps');
          expect(steps as List, isNotEmpty, reason: '$label: steps');
          for (var i = 0; i < steps.length; i++) {
            final step = steps[i];
            final at = '$label: step ${i + 1}';
            expect(step, isA<Map>(), reason: at);
            final keys = _stepKeys[(step as Map)['op']];
            expect(keys, isNotNull, reason: '$at: op ${step['op']}');
            expect(step.keys.toSet(), keys, reason: at);
            if (keys!.contains('location')) {
              expect(step['location'], startsWith('/'), reason: at);
            }
            if (keys.contains('index')) {
              expect(step['index'], isA<int>(), reason: at);
            }
            if (keys.contains('tabId')) {
              expect(step['tabId'], isA<String>(), reason: at);
            }
            if (keys.contains('key')) {
              expect(step['key'], isA<String>(), reason: at);
            }
            _expectObserved(step['expected'], at);
          }
        }
      }
      if (!fx.containsKey('cases')) continue;
      final cases = fx['cases'];
      expect(cases, isA<List>(), reason: '$name cases');
      expect(cases as List, isNotEmpty, reason: '$name cases');
      for (final c in cases) {
        final label = '$name · ${(c as Map)['name']}';
        expect(c['name'], isA<String>(), reason: label);
        expect(c['location'], isA<String>(), reason: label);
        final expected = c['expected'];
        expect(expected, isA<Map>(), reason: label);
        final kind = (expected as Map)['kind'];
        expect(kind, anyOf('page', 'error'), reason: label);
        for (final key in kind == 'page' ? _pageKeys : _errorKeys) {
          expect(expected.containsKey(key), isTrue, reason: '$label: $key');
        }
        if (kind == 'error') {
          expect(expected.keys.toSet(), _errorKeys.toSet(), reason: label);
        }
      }
    }
  });

  for (final file in files) {
    final fx = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final name = file.uri.pathSegments.last;
    final id = _caseIds[name.split('_').first] ?? 'B9.10-F';

    for (final c
        in ((fx['cases'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
      testWidgets('$id · $name · ${fx['name']} · ${c['name']}', (tester) async {
        final client = _StubClient();
        final manager = StateManager();
        final config = NavConfig.fromJson(
          Map<String, dynamic>.from(fx['config'] as Map),
        );

        await tester.pumpWidget(
          OrcaApp(
            client: client,
            appId: 'fixture-app',
            preloadedConfig: config,
            stateManager: manager,
          ),
        );
        await tester.pumpAndSettle();

        // The overlay goes on top of the seeded initialAppState.
        final overlay = fx['appState'];
        if (overlay is Map) {
          Map<String, dynamic>.from(overlay).forEach(manager.setAppState);
        }
        final router = GoRouter.of(tester.element(find.byType(Navigator).first));
        final seenAtBoot = List<String>.from(client.requests);
        client.requests.clear();

        final location = c['location'] as String;
        router.go(location);
        await tester.pumpAndSettle();

        final matches = router.routerDelegate.currentConfiguration;
        final finalLocation = matches.uri.toString();
        final actual = <String, dynamic>{
          'location': finalLocation,
          'redirected': _pathOf(finalLocation) != _pathOf(location),
        };

        final onstage = tester.widgetList<OrcaPage>(find.byType(OrcaPage));
        if (matches.isError) {
          actual['kind'] = 'error';
          expect(onstage, isEmpty, reason: 'no page on the error screen');
          expect(find.text('Page Not Found'), findsOneWidget);
          expect(client.requests, isEmpty, reason: 'no page request');
        } else {
          final stack = _stackOf(matches.matches);
          final top = onstage.single;
          final shells = tester.widgetList<OrcaShell>(find.byType(OrcaShell));
          actual.addAll({
            'kind': 'page',
            'pagePath': top.path,
            'routePath': matches.fullPath,
            'params': matches.pathParameters,
            'stack': stack,
            'tabIndex': shells.isEmpty
                ? null
                : shells.single.navigationShell.currentIndex,
            'scaffoldTitle':
                top.wrapInScaffold ? top.scaffoldTitleFallback : null,
          });
          // What the matches say must be what was built and asked for.
          expect(stack.last, top.path, reason: 'top of the stack is on screen');
          final built = tester
              .widgetList<OrcaPage>(
                find.byType(OrcaPage, skipOffstage: false),
              )
              .map((p) => p.path)
              .toSet();
          expect(built, containsAll(stack), reason: 'every stack page built');
          expect(
            {...seenAtBoot, ...client.requests},
            containsAll(stack),
            reason: 'every stack page requested',
          );
        }

        final expected = Map<String, dynamic>.from(c['expected'] as Map);
        if (expected.containsKey('appState')) {
          actual['appState'] = manager.appStore.state;
        }
        expect(actual, equals(expected));
      });
    }

    final sessions =
        ((fx['sessions'] as List?) ?? const []).cast<Map<String, dynamic>>();
    for (final s in sessions) {
      testWidgets('$id · $name · ${fx['name']} · ${s['name']}', (tester) async {
        final client = _StubClient();
        final manager = StateManager();
        final config = NavConfig.fromJson(
          Map<String, dynamic>.from(fx['config'] as Map),
        );
        final steps = (s['steps'] as List).cast<Map<String, dynamic>>();
        final expected = <dynamic>[
          (s['boot'] as Map)['expected'],
          for (final step in steps) step['expected'],
        ];

        // What Flutter shows now; the requests are those since the last call.
        Map<String, dynamic> observe(GoRouter router, Map expectedHere) {
          final shells = tester.widgetList<OrcaShell>(
            find.byType(OrcaShell, skipOffstage: false),
          );
          final state = manager.appStore.state;
          final watched = expectedHere['appState'] as Map;
          final seen = <String, dynamic>{
            'location': router.state.uri.toString(),
            'tabIndex': shells.isEmpty
                ? null
                : shells.single.navigationShell.currentIndex,
            'appState': {
              for (final key in watched.keys)
                if (state.containsKey(key)) key: state[key],
            },
            'pageRequests': List<String>.from(client.requests),
          };
          client.requests.clear();
          // The location read from the router is the page on screen.
          final top = tester.widgetList<OrcaPage>(find.byType(OrcaPage));
          expect(
            top.map((p) => '/${p.path}'),
            [_pathOf(seen['location'] as String)],
            reason: 'the visible page is the router location',
          );
          return seen;
        }

        await tester.pumpWidget(
          OrcaApp(
            client: client,
            appId: 'fixture-app',
            preloadedConfig: config,
            stateManager: manager,
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(Navigator).first));
        final actual = <dynamic>[observe(router, expected[0] as Map)];

        for (var i = 0; i < steps.length; i++) {
          final step = steps[i];
          switch (step['op']) {
            case 'go':
              router.go(step['location'] as String);
            case 'push':
              // The future completes when the pushed route is popped.
              router.push(step['location'] as String).ignore();
            case 'back':
              router.pop();
            case 'tapTab':
              // The real default bar: the item is found by its tab's label.
              final tab = config.tabs[step['index'] as int];
              await tester.tap(
                find.descendant(
                  of: find.byType(BottomNavigationBar),
                  matching: find.text(tab.label),
                ),
              );
            case 'switchTab':
              // The real executor, under the page on screen as a page's is.
              final page = tester.element(find.byType(OrcaPage));
              await ActionExecutor(
                context: page,
                stateManager: manager,
                pageId: 'fixture-session',
              ).execute({'type': 'switchTab', 'tabId': step['tabId']});
            case 'setAppState':
              manager.setAppState(step['key'] as String, step['value']);
            default:
              fail('unknown op ${step['op']}');
          }
          await tester.pumpAndSettle();
          actual.add(observe(router, expected[i + 1] as Map));
        }

        // On a difference the whole observed session is printed, boot first:
        // Flutter is the oracle, so that is what the fixture should say.
        expect(
          actual,
          equals(expected),
          reason: 'observed: ${jsonEncode(actual)}',
        );
      });
    }
  }
}

/// An `expected` of a session: the four observed keys, each of its type.
void _expectObserved(dynamic expected, String label) {
  expect(expected, isA<Map>(), reason: '$label: expected');
  final e = expected as Map;
  expect(e.keys.toSet(), _observedKeys, reason: '$label: expected');
  expect(e['location'], isA<String>(), reason: '$label: location');
  expect(e['tabIndex'], anyOf(isNull, isA<int>()), reason: '$label: tabIndex');
  expect(e['appState'], isA<Map>(), reason: '$label: appState');
  expect(e['pageRequests'], isA<List>(), reason: '$label: pageRequests');
}
