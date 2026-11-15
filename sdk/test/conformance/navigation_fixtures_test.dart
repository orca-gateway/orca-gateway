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
//
// Links (native parity step 11, case L-F): a file may instead carry `links`,
// each one URL handed to a fresh app the way the platform hands it to Flutter.
// Cold: the URL is the platform's default route name before the app is pumped.
// Warm: the app is shown at `startAt`, then a `pushRouteInformation` call
// arrives on the `flutter/navigation` channel. `onDeeplink` is set and what it
// receives is recorded. Flutter's location is compared in the fixture's form
// (path and query); where a documented Flutter quirk differs from `expected`,
// the case says so under `flutter` and that is what Flutter is held to.
import 'dart:convert';

import 'package:flutter/services.dart';
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
  '15': 'L-F',
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

/// Keys of a link case, the required ones and the optional ones.
const _linkRequiredKeys = {'name', 'link', 'coldStart', 'expected'};
const _linkOptionalKeys = {'startAt', 'appState', 'flutter'};
const _linkExpectedKeys = {
  'kind',
  'location',
  'redirected',
  'stack',
  'tabIndex',
  'pageRequests',
  'event',
};
const _linkEventKeys = {
  'resolvedLocation',
  'pathParameters',
  'queryParameters',
  'wasRedirected',
  'isColdStart',
};

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

/// A URL in the form the link fixtures compare: its path and its query,
/// nothing else. An empty path is "/", a trailing slash is dropped.
String _linkLocation(String url) {
  final uri = Uri.parse(url);
  var path = uri.path.isEmpty ? '/' : uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return uri.query.isEmpty ? path : '$path?${uri.query}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final files = fixtureFiles('navigation');

  test('B9.10-F · the family holds at least fifteen well-formed fixtures', () {
    expect(files.length, greaterThanOrEqualTo(15));
    expect(
      files.where(
        (f) => (jsonDecode(f.readAsStringSync()) as Map).containsKey('links'),
      ),
      isNotEmpty,
      reason: 'L-F: one file at least carries links',
    );
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
        fx.containsKey('cases') ||
            fx.containsKey('sessions') ||
            fx.containsKey('links'),
        isTrue,
        reason: '$name carries cases, sessions or links',
      );
      if (fx.containsKey('links')) {
        expect(fx.keys.toSet(), {
          'name',
          'description',
          'config',
          'links',
        }, reason: '$name: a links file carries links alone');
        final links = fx['links'];
        expect(links, isA<List>(), reason: '$name links');
        expect(links as List, isNotEmpty, reason: '$name links');
        for (final l in links) {
          final label = '$name · ${(l as Map)['name']}';
          expect(l.keys.toSet(), containsAll(_linkRequiredKeys), reason: label);
          expect(
            l.keys.toSet().difference(_linkRequiredKeys),
            everyElement(isIn(_linkOptionalKeys)),
            reason: label,
          );
          expect(l['name'], isA<String>(), reason: label);
          expect(l['link'], isA<String>(), reason: label);
          expect(l['coldStart'], isA<bool>(), reason: label);
          if (l.containsKey('startAt')) {
            expect(l['startAt'], startsWith('/'), reason: label);
            expect(l['coldStart'], isFalse, reason: '$label: startAt is warm');
          }
          if (l.containsKey('appState')) {
            expect(l['appState'], isA<Map>(), reason: label);
          }
          final e = l['expected'];
          expect(e, isA<Map>(), reason: label);
          expect((e as Map).keys.toSet(), _linkExpectedKeys, reason: label);
          expect(e['kind'], anyOf('page', 'error'), reason: label);
          expect(e['location'], startsWith('/'), reason: label);
          expect(e['redirected'], isA<bool>(), reason: label);
          expect(e['stack'], isA<List>(), reason: label);
          expect(
            (e['stack'] as List).isEmpty,
            e['kind'] == 'error',
            reason: '$label: a stack for a page, none for an error',
          );
          expect(e['tabIndex'], anyOf(isNull, isA<int>()), reason: label);
          expect(e['pageRequests'], isA<List>(), reason: label);
          final event = e['event'];
          if (event != null) {
            expect(event, isA<Map>(), reason: label);
            expect((event as Map).keys.toSet(), _linkEventKeys, reason: label);
            expect(event['isColdStart'], l['coldStart'], reason: label);
          }
          if (l.containsKey('flutter')) {
            final f = l['flutter'];
            expect(f, isA<Map>(), reason: label);
            expect((f as Map)['why'], isA<String>(), reason: '$label: why');
            expect(f['why'] as String, isNotEmpty, reason: '$label: why');
            final over = f.keys.toSet()..remove('why');
            expect(over, isNotEmpty, reason: '$label: flutter overrides');
            expect(over, everyElement(isIn(_linkExpectedKeys)), reason: label);
            final fe = f['event'];
            if (fe != null) {
              expect(fe, isA<Map>(), reason: label);
              expect(
                (fe as Map).keys,
                everyElement(isIn(_linkEventKeys)),
                reason: label,
              );
            }
          }
        }
      }
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

    final links = ((fx['links'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    for (final l in links) {
      testWidgets('$id · $name · ${fx['name']} · ${l['name']}', (tester) async {
        final client = _StubClient();
        final manager = StateManager();
        // The app boots with the case's app state laid over the seed, so a
        // cold link is redirected (or not) by the state the case names.
        final json = Map<String, dynamic>.from(fx['config'] as Map);
        json['initialAppState'] = <String, dynamic>{
          ...?(json['initialAppState'] as Map?)?.cast<String, dynamic>(),
          ...?(l['appState'] as Map?)?.cast<String, dynamic>(),
        };
        final config = NavConfig.fromJson(json);
        final link = l['link'] as String;
        final cold = l['coldStart'] as bool;

        // 'route <location>' and 'deeplink' in the order they are called.
        final calls = <String>[];
        final events = <OrcaDeeplinkEvent>[];

        if (cold) {
          // The link opened the app: it is the platform's default route name.
          tester.platformDispatcher.defaultRouteNameTestValue = link;
          addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
        }
        await tester.pumpWidget(
          OrcaApp(
            client: client,
            appId: 'fixture-app',
            preloadedConfig: config,
            stateManager: manager,
            onRouteChanged: (e) => calls.add('route ${e.location}'),
            onDeeplink: (e) {
              calls.add('deeplink');
              events.add(e);
            },
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(Navigator).first));

        if (!cold) {
          final startAt = l['startAt'] as String?;
          if (startAt != null && startAt != config.initialRoute) {
            router.go(startAt);
            await tester.pumpAndSettle();
          }
          expect(events, isEmpty, reason: 'no link yet, no callback');
          client.requests.clear();
          calls.clear();
          // The link arrives as the platform sends it to a running app.
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/navigation',
            const JSONMethodCodec().encodeMethodCall(
              MethodCall('pushRouteInformation', <String, dynamic>{
                'location': link,
                'state': null,
              }),
            ),
            (_) {},
          );
          await tester.pumpAndSettle();
        }

        final matches = router.routerDelegate.currentConfiguration;
        final raw = matches.uri.toString();
        final shells = tester.widgetList<OrcaShell>(find.byType(OrcaShell));
        final onstage = tester.widgetList<OrcaPage>(find.byType(OrcaPage));
        if (matches.isError) {
          expect(onstage, isEmpty, reason: 'no page on the error screen');
          expect(find.text('Page Not Found'), findsOneWidget);
          expect(find.text('Go to home page'), findsOneWidget);
        } else {
          expect(onstage.map((p) => '/${p.path}'), [
            _pathOf(_linkLocation(raw)),
          ], reason: 'the visible page is the router location');
        }

        expect(events.length, lessThanOrEqualTo(1), reason: 'once at most');
        Object? event;
        if (events.isNotEmpty) {
          final e = events.single;
          expect(e.incoming.toString(), link, reason: 'the link as given');
          // The callback comes after onRouteChanged, for the same location.
          final at = calls.indexOf('deeplink');
          expect(at, greaterThan(0), reason: 'calls: $calls');
          expect(calls[at - 1], 'route ${e.resolvedLocation}');
          event = <String, dynamic>{
            'resolvedLocation': e.resolvedLocation,
            'pathParameters': e.pathParameters,
            'queryParameters': e.queryParameters,
            'wasRedirected': e.wasRedirected,
            'isColdStart': e.isColdStart,
          };
        }

        final actual = <String, dynamic>{
          'kind': matches.isError ? 'error' : 'page',
          'location': _linkLocation(raw),
          'redirected':
              _pathOf(_linkLocation(raw)) != _pathOf(_linkLocation(link)),
          'stack': matches.isError ? <String>[] : _stackOf(matches.matches),
          'tabIndex': shells.isEmpty
              ? null
              : shells.single.navigationShell.currentIndex,
          'pageRequests': List<String>.from(client.requests),
          'event': event,
        };

        // What Flutter is held to: `expected`, with the case's documented
        // Flutter differences laid over it (an event key by key, or null).
        final expected = Map<String, dynamic>.from(l['expected'] as Map);
        final over = Map<String, dynamic>.from((l['flutter'] as Map?) ?? {})
          ..remove('why');
        over.forEach((key, value) {
          expected[key] = key == 'event' && value is Map
              ? {...expected['event'] as Map, ...value}
              : value;
        });

        expect(
          actual,
          equals(expected),
          reason: 'observed (location raw: $raw): ${jsonEncode(actual)}',
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
