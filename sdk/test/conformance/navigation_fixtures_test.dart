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
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

    for (final c in (fx['cases'] as List).cast<Map<String, dynamic>>()) {
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
  }
}
