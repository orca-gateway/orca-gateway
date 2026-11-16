// C-flutter: the SubPage widget and the updateSubPage action follow the
// contract of schema/fixtures/subpage/README.md (S1 to S8). The pure rules
// (what merge rewrites, the query string, replace and join) are pinned by the
// fixtures through sub_page_core.dart; these tests pin what the fixtures
// cannot: the fetch, the drawing, the host page's stores and the executor.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:orca_gateway/orca_gateway.dart';

// ── Wire helpers ────────────────────────────────────────────

Map<String, dynamic> _node(
  String id,
  String type, {
  String kind = 'layout',
  String childMode = 'multi',
  Map<String, dynamic> props = const {},
  List<String> children = const [],
  List<String> watches = const [],
  Map<String, dynamic>? actions,
}) => {
  'id': id,
  'type': type,
  'kind': kind,
  'childMode': childMode,
  'props': props,
  'children': children,
  'watches': watches,
  'actions': ?actions,
};

Map<String, dynamic> _pageRef(String key) => {
  'type': 'state',
  'key': key,
  'scope': 'page',
};

Map<String, dynamic> _static(Object? value) => {
  'type': 'static',
  'value': value,
};

Map<String, dynamic> _text(String id, Object data, {List<String>? watches}) =>
    _node(
      id,
      'Text',
      kind: 'primitive',
      childMode: 'none',
      props: {'data': data},
      watches: watches ?? const [],
    );

/// A button whose label is its id and whose tap runs [action].
List<Map<String, dynamic>> _button(String id, Object action) => [
  _node(
    id,
    'ElevatedButton',
    kind: 'button',
    childMode: 'single',
    children: ['${id}_label'],
    actions: {'onTap': action},
  ),
  _text('${id}_label', id),
];

Map<String, dynamic> _setPage(String key, Object? value) => {
  'type': 'setState',
  'scope': 'page',
  'key': key,
  'value': _static(value),
};

Map<String, dynamic> _page(
  String pageId,
  List<Map<String, dynamic>> components, {
  Map<String, Object?> state = const {},
}) => {
  'pageId': pageId,
  'title': '',
  'state': [
    for (final e in state.entries)
      {'key': e.key, 'scope': 'page', 'initial': e.value},
  ],
  'components': components,
};

Map<String, dynamic> _subPageNode({
  Object pageId = 'detail/a',
  Map<String, dynamic>? params,
  List<String> children = const [],
  List<String> watches = const [],
}) => _node(
  'detail',
  'SubPage',
  childMode: 'single',
  props: {'pageId': pageId, 'params': ?params},
  children: children,
  watches: watches,
);

/// A sub-page: a column with a label and its own `count`, both tagged [tag].
Map<String, dynamic> _detail(String tag, int count) => _page(
  'detail/$tag',
  [
    _node('0', 'Column', children: ['label', 'count']),
    _text('label', 'Page $tag'),
    _text('count', _pageRef('count'), watches: ['count']),
  ],
  state: {'count': count},
);

/// The host: its own `count` (100), the SubPage `detail`, and [extra] nodes
/// listed under the root column.
Map<String, dynamic> _host({
  Map<String, dynamic>? subPage,
  List<Map<String, dynamic>> extra = const [],
  List<String> extraChildren = const [],
  Map<String, Object?> state = const {'count': 100},
}) => _page('host', [
  _node('root', 'Column', children: ['hostCount', 'detail', ...extraChildren]),
  _text('hostCount', _pageRef('count'), watches: ['count']),
  subPage ?? _subPageNode(),
  ...extra,
], state: state);

// ── Stub client ─────────────────────────────────────────────

class _StubClient extends OrcaClient {
  /// What each page location answers: a page map, an error to throw, or a
  /// `Future<Map<String, dynamic>>`.
  final Map<String, Object> pages;

  /// The actions a serverAction returns, by action id.
  final Map<String, List<dynamic>> actions;

  final List<String> fetched = [];
  final List<Map<String, dynamic>?> postedPageStates = [];

  _StubClient(this.pages, {this.actions = const {}})
    : super(baseUrl: 'http://stub');

  @override
  Future<PageResponse> fetchPage(
    String appId,
    String path, {
    Map<String, dynamic>? appState,
  }) async {
    fetched.add(path);
    final answer = pages[path];
    if (answer == null) throw StateError('no page $path');
    if (answer is Map<String, dynamic>) return PageResponse.fromJson(answer);
    if (answer is Future<Map<String, dynamic>>) {
      return PageResponse.fromJson(await answer);
    }
    throw answer;
  }

  @override
  Future<ActionResponse> executeAction(
    String appId, {
    required String action,
    Map<String, dynamic>? params,
    Map<String, dynamic>? pageState,
    Map<String, dynamic>? appState,
  }) async {
    postedPageStates.add(
      pageState == null ? null : Map<String, dynamic>.from(pageState),
    );
    return ActionResponse.fromJson({'actions': actions[action] ?? const []});
  }
}

class _Harness {
  final _StubClient client;
  final StateManager state = StateManager();

  /// Set by the custom action `grab`: the page's executor.
  ActionExecutor? executor;

  _Harness(this.client);

  Map<String, dynamic> get pageState => state.getPageStore('host')!.state;
  ComponentStore get store => executor!.componentStore!;

  Widget get app => MaterialApp(
    home: Scaffold(
      body: OrcaPage(
        client: client,
        appId: 'app',
        path: 'host',
        stateManager: state,
        customActions: {'grab': (_, exec) async => executor = exec},
      ),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }
}

/// The `grab` button: gives the test the page's executor and stores.
final _grab = _button('grab', {'type': 'grab'});

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

/// Width of the page root (the nearest Column) that holds [text].
double _rootWidth(WidgetTester tester, String text) => tester
    .getSize(
      find.ancestor(of: find.text(text), matching: find.byType(Column)).first,
    )
    .width;

/// A sub-page `detail/a` that holds a nested SubPage `inner` showing `leaf/x`.
Map<String, dynamic> _outer() => _page(
  'detail/a',
  [
    _node('0', 'Column', children: ['label', 'inner']),
    _text('label', 'Page a'),
    _node('inner', 'SubPage', childMode: 'single', props: {'pageId': 'leaf/x'}),
  ],
  state: {'count': 5},
);

/// The nested page: its own `n` (1), shown, and the buttons [buttons].
Map<String, dynamic> _leaf(List<List<Map<String, dynamic>>> buttons) => _page(
  'leaf/x',
  [
    _node(
      '0',
      'Column',
      children: ['n', for (final b in buttons) b.first['id'] as String],
    ),
    _text('n', _pageRef('n'), watches: ['n']),
    for (final b in buttons) ...b,
  ],
  state: {'n': 1},
);

/// The sub-page `detail/<tag>` with a `bump` button that sets its count to 8.
Map<String, dynamic> _bumpable(String tag, int count) {
  final page = _detail(tag, count);
  (page['components'] as List)
    ..addAll(_button('bump', _setPage('count', 8)))
    ..[0]['children'] = ['label', 'count', 'bump'];
  return page;
}

/// A host whose SubPage `detail` is the first child of a list of type [list],
/// above a spacer taller than the screen: a ListView scrolled to the end
/// disposes the SubPage's widget while its node stays in the page.
Map<String, dynamic> _listHost({String list = 'ListView'}) => _page('host', [
  _node('root', 'Column', children: ['grab', 'replace', 'fill']),
  ..._grab,
  ..._button('replace', {
    'type': 'updateSubPage',
    'subPageId': 'detail',
    'pageId': 'detail/b',
    'mode': 'replace',
  }),
  _node('fill', 'Expanded', childMode: 'single', children: ['list']),
  _node('list', list, children: ['detail', 'spacer', 'tail']),
  _subPageNode(),
  _node('spacer', 'SizedBox', childMode: 'single', props: {'height': 3000}),
  _text('tail', 'Tail'),
]);

/// Jumps the host's ListView to [offset].
Future<void> _scrollTo(WidgetTester tester, double offset) async {
  tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position
      .jumpTo(offset);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('C-flutter: params reach the request as the query', (
    tester,
  ) async {
    final client = _StubClient({
      'host': _host(
        subPage: _subPageNode(params: {'name': 'Ada Lovelace', 'n': 3}),
      ),
      'detail/a?n=3&name=Ada%20Lovelace': _detail('a', 5),
    });
    await _Harness(client).pump(tester);

    expect(client.fetched, ['host', 'detail/a?n=3&name=Ada%20Lovelace']);
    expect(find.text('Page a'), findsOneWidget);
  });

  testWidgets('C-flutter: a Scaffold and an AppBar inside a sub-page draw', (
    tester,
  ) async {
    final client = _StubClient({
      // The SubPage is the host's root, so the Scaffold has a bounded box.
      'host': _page('host', [_subPageNode()]),
      'detail/a': _page('detail/a', [
        _node(
          '0',
          'Scaffold',
          kind: 'structure',
          childMode: 'none',
          props: {'appBar': '1', 'body': 'body'},
          children: ['1', 'body'],
        ),
        _node(
          '1',
          'AppBar',
          kind: 'structure',
          childMode: 'none',
          props: {'title': 'title'},
          children: ['title'],
        ),
        _text('title', 'Inbox'),
        _text('body', 'Messages'),
      ]),
    });
    await _Harness(client).pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets(
    'C-flutter: the sub-page sees its own initial state, apart from the '
    'host key of the same name',
    (tester) async {
      final client = _StubClient({
        'host': _host(),
        'detail/a': _detail('a', 5),
      });
      final h = _Harness(client);
      await h.pump(tester);

      expect(find.text('100'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(h.pageState, {'count': 100, 'detail:count': 5});
    },
  );

  testWidgets('C-flutter: setState inside writes the prefixed key', (
    tester,
  ) async {
    final detail = _detail('a', 5);
    (detail['components'] as List)
      ..addAll(_button('bump', _setPage('count', 6)))
      ..[0]['children'] = ['label', 'count', 'bump'];
    final client = _StubClient({'host': _host(), 'detail/a': detail});
    final h = _Harness(client);
    await h.pump(tester);

    await h.tap(tester, 'bump');

    expect(h.pageState, {'count': 100, 'detail:count': 6});
    expect(find.text('100'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets(
    'C-flutter: updateSubPage replace to another page sticks after a rebuild',
    (tester) async {
      final client = _StubClient({
        'host': _host(
          extraChildren: ['replace'],
          extra: _button('replace', {
            'type': 'updateSubPage',
            'subPageId': 'detail',
            'pageId': 'detail/b',
            'mode': 'replace',
          }),
        ),
        'detail/a': _detail('a', 5),
        'detail/b': _detail('b', 7),
      });
      final h = _Harness(client);
      await h.pump(tester);

      await h.tap(tester, 'replace');
      expect(find.text('Page b'), findsOneWidget);
      expect(find.text('Page a'), findsNothing);

      // A rebuild from the top must not put the first page back.
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      expect(find.text('Page b'), findsOneWidget);
      expect(find.text('Page a'), findsNothing);
      expect(h.pageState, {'count': 100, 'detail:count': 7});
      expect(client.fetched, ['host', 'detail/a', 'detail/b']);
    },
  );

  testWidgets(
    'C-flutter: join draws both pages in order, each with its own state',
    (tester) async {
      final client = _StubClient({
        'host': _host(
          extraChildren: ['join'],
          extra: _button('join', {
            'type': 'updateSubPage',
            'subPageId': 'detail',
            'pageId': 'detail/c',
            'mode': 'join',
          }),
        ),
        'detail/a': _detail('a', 5),
        'detail/c': _detail('c', 50),
      });
      final h = _Harness(client);
      await h.pump(tester);

      await h.tap(tester, 'join');

      expect(find.text('Page a'), findsOneWidget);
      expect(find.text('Page c'), findsOneWidget);
      expect(_top(tester, 'Page a'), lessThan(_top(tester, 'Page c')));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(_top(tester, '5'), lessThan(_top(tester, 'Page c')));
      expect(h.pageState, {
        'count': 100,
        'detail:count': 5,
        'detail#1:count': 50,
      });
      // Each page root gets the width the host gives the SubPage.
      final host = tester.getSize(find.byType(OrcaPage)).width;
      expect(_rootWidth(tester, 'Page a'), host);
      expect(_rootWidth(tester, 'Page c'), host);
    },
  );

  testWidgets(
    'C-flutter: a server action inside posts the sub-page keys unprefixed '
    'and its setState lands under the prefix',
    (tester) async {
      final detail = _detail('a', 5);
      (detail['components'] as List)
        ..addAll(_button('save', {'type': 'serverAction', 'id': 'save'}))
        ..[0]['children'] = ['label', 'count', 'save'];
      final client = _StubClient(
        {
          'host': _host(
            extraChildren: ['hostSave'],
            extra: _button('hostSave', {
              'type': 'serverAction',
              'id': 'hostSave',
            }),
          ),
          'detail/a': detail,
        },
        actions: {
          'save': [_setPage('count', 42)],
          'hostSave': [_setPage('count', 101)],
        },
      );
      final h = _Harness(client);
      await h.pump(tester);

      await h.tap(tester, 'save');

      expect(client.postedPageStates.single, {'count': 5});
      expect(h.pageState, {'count': 100, 'detail:count': 42});
      expect(find.text('42'), findsOneWidget);

      // A host node posts the whole page state and writes host keys, as before.
      await h.tap(tester, 'hostSave');

      expect(client.postedPageStates.last, {'count': 100, 'detail:count': 42});
      expect(h.pageState, {'count': 101, 'detail:count': 42});
    },
  );

  testWidgets(
    'C-flutter: a component mutation returned for a sub-page node changes it',
    (tester) async {
      final detail = _detail('a', 5);
      (detail['components'] as List)
        ..addAll(_button('rename', {'type': 'serverAction', 'id': 'rename'}))
        ..[0]['children'] = ['label', 'count', 'rename'];
      final client = _StubClient(
        {'host': _host(), 'detail/a': detail},
        actions: {
          'rename': [
            {
              'type': 'updateComponent',
              'id': 'label',
              'props': {'data': 'Renamed'},
            },
          ],
        },
      );
      final h = _Harness(client);
      await h.pump(tester);

      await h.tap(tester, 'rename');

      expect(find.text('Renamed'), findsOneWidget);
      expect(find.text('Page a'), findsNothing);
    },
  );

  testWidgets('C-flutter: the child is drawn while the first fetch runs', (
    tester,
  ) async {
    final answer = Completer<Map<String, dynamic>>();
    final client = _StubClient({
      'host': _host(
        subPage: _subPageNode(children: ['wait']),
        extra: [_text('wait', 'Please wait')],
      ),
      'detail/a': answer.future,
    });
    final h = _Harness(client);
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.pump();

    expect(find.text('Please wait'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    answer.complete(_detail('a', 5));
    await tester.pumpAndSettle();

    expect(find.text('Please wait'), findsNothing);
    expect(find.text('Page a'), findsOneWidget);
  });

  testWidgets('C-flutter: without a child a centred spinner is drawn', (
    tester,
  ) async {
    final answer = Completer<Map<String, dynamic>>();
    final client = _StubClient({'host': _host(), 'detail/a': answer.future});
    await tester.pumpWidget(_Harness(client).app);
    await tester.pump();
    await tester.pump();

    final spinner = find.byType(CircularProgressIndicator);
    expect(spinner, findsOneWidget);
    expect(
      find.ancestor(of: spinner, matching: find.byType(Center)),
      findsWidgets,
    );

    answer.complete(_detail('a', 5));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('C-flutter: a failed fetch draws "SubPage error: <message>"', (
    tester,
  ) async {
    final client = _StubClient({
      'host': _host(),
      'detail/a': const OrcaClientException(
        'Failed to fetch page: 500',
        statusCode: 500,
        body: '',
      ),
    });
    await _Harness(client).pump(tester);

    expect(
      find.text('SubPage error: OrcaClientException(500): Failed to fetch page: 500'),
      findsOneWidget,
    );
  });

  testWidgets('C-flutter: an unknown subPageId does nothing', (tester) async {
    final client = _StubClient({
      'host': _host(
        extraChildren: ['stray'],
        extra: _button('stray', {
          'type': 'updateSubPage',
          'subPageId': 'nobody',
          'pageId': 'detail/b',
          'mode': 'replace',
        }),
      ),
      'detail/a': _detail('a', 5),
    });
    final h = _Harness(client);
    await h.pump(tester);

    await h.tap(tester, 'stray');

    expect(tester.takeException(), isNull);
    expect(client.fetched, ['host', 'detail/a']);
    expect(find.text('Page a'), findsOneWidget);
    expect(h.pageState, {'count': 100, 'detail:count': 5});
  });

  testWidgets(
    'C-flutter: a failed updateSubPage leaves the content and reaches onError',
    (tester) async {
      final client = _StubClient({
        'host': _host(
          extraChildren: ['broken'],
          extra: _button('broken', {
            'type': 'lifecycle',
            'action': {
              'type': 'updateSubPage',
              'subPageId': 'detail',
              'pageId': 'detail/missing',
              'mode': 'replace',
            },
            'onError': _setPage('failed', true),
          }),
        ),
        'detail/a': _detail('a', 5),
      });
      final h = _Harness(client);
      await h.pump(tester);

      await h.tap(tester, 'broken');

      expect(find.text('Page a'), findsOneWidget);
      expect(h.pageState, {'count': 100, 'detail:count': 5, 'failed': true});
    },
  );

  testWidgets('C-flutter: a change of params or pageId refetches as a replace', (
    tester,
  ) async {
    final client = _StubClient({
      'host': _host(
        state: {'count': 100, 'who': 'Ada', 'page': 'detail/a'},
        subPage: _subPageNode(
          pageId: _pageRef('page'),
          params: {'name': _pageRef('who')},
          watches: ['page', 'who'],
        ),
        extraChildren: ['bob', 'other'],
        extra: [
          ..._button('bob', _setPage('who', 'Bob')),
          ..._button('other', _setPage('page', 'detail/b')),
        ],
      ),
      'detail/a?name=Ada': _detail('a', 5),
      'detail/a?name=Bob': _detail('a', 6),
      'detail/b?name=Bob': _detail('b', 7),
    });
    final h = _Harness(client);
    await h.pump(tester);
    expect(find.text('5'), findsOneWidget);

    await h.tap(tester, 'bob');

    expect(client.fetched.last, 'detail/a?name=Bob');
    expect(find.text('6'), findsOneWidget);
    expect(h.pageState['detail:count'], 6);

    await h.tap(tester, 'other');

    expect(client.fetched, [
      'host',
      'detail/a?name=Ada',
      'detail/a?name=Bob',
      'detail/b?name=Bob',
    ]);
    expect(find.text('Page b'), findsOneWidget);
    expect(find.text('Page a'), findsNothing);
    expect(h.pageState['detail:count'], 7);
  });

  testWidgets(
    'C-flutter: the nodes are in the page store and leave it on unmount',
    (tester) async {
      final client = _StubClient({
        'host': _host(
          extraChildren: ['grab', 'drop'],
          extra: [
            ..._grab,
            ..._button('drop', {'type': 'deleteComponent', 'id': 'detail'}),
          ],
        ),
        'detail/a': _detail('a', 5),
      });
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');

      Iterable<String> mounted() =>
          h.store.nodeMap.keys.where((id) => id.startsWith('detail:'));
      expect(mounted(), unorderedEquals(['detail:0', 'detail:label', 'detail:count']));

      await h.tap(tester, 'drop');

      expect(find.text('Page a'), findsNothing);
      expect(mounted(), isEmpty);
      // S8: the state keys are left where they are.
      expect(h.pageState, {'count': 100, 'detail:count': 5});
    },
  );

  testWidgets(
    'C-flutter: a nested SubPage mounts under outer:inner: and a server '
    'action inside it posts the inner view',
    (tester) async {
      final client = _StubClient(
        {
          'host': _host(),
          'detail/a': _outer(),
          'leaf/x': _leaf([
            _button('save', {'type': 'serverAction', 'id': 'save'}),
          ]),
        },
        actions: {
          'save': [_setPage('n', 9)],
        },
      );
      final h = _Harness(client);
      await h.pump(tester);

      expect(client.fetched, ['host', 'detail/a', 'leaf/x']);
      expect(h.pageState, {'count': 100, 'detail:count': 5, 'detail:inner:n': 1});

      await h.tap(tester, 'save');

      expect(client.postedPageStates.single, {'n': 1});
      expect(h.pageState, {'count': 100, 'detail:count': 5, 'detail:inner:n': 9});
      expect(find.text('9'), findsOneWidget);
    },
  );

  testWidgets(
    'C-flutter: a replace of the outer page draws its nested SubPage anew, '
    'against fresh state',
    (tester) async {
      final client = _StubClient({
        'host': _host(
          extraChildren: ['refresh'],
          extra: _button('refresh', {
            'type': 'updateSubPage',
            'subPageId': 'detail',
            'pageId': 'detail/a',
            'mode': 'replace',
          }),
        ),
        'detail/a': _outer(),
        'leaf/x': _leaf([_button('bump', _setPage('n', 2))]),
      });
      final h = _Harness(client);
      await h.pump(tester);

      await h.tap(tester, 'bump');
      expect(find.text('2'), findsOneWidget);
      expect(h.pageState['detail:inner:n'], 2);

      await h.tap(tester, 'refresh');

      expect(tester.takeException(), isNull);
      expect(client.fetched, [
        'host',
        'detail/a',
        'leaf/x',
        'detail/a',
        'leaf/x',
      ]);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('bump'), findsOneWidget);
      expect(h.pageState, {'count': 100, 'detail:count': 5, 'detail:inner:n': 1});

      // The new inner page is the one updateSubPage and the actions reach.
      await h.tap(tester, 'bump');
      expect(find.text('2'), findsOneWidget);
      expect(h.pageState['detail:inner:n'], 2);
    },
  );

  testWidgets(
    'C-flutter: nodes added inside a sub-page leave the store with their page',
    (tester) async {
      Map<String, dynamic> detail(String tag) {
        final page = _detail(tag, 5);
        (page['components'] as List)
          ..addAll(_button('add', {'type': 'serverAction', 'id': 'add'}))
          ..[0]['children'] = ['label', 'count', 'add'];
        return page;
      }

      final client = _StubClient(
        {
          'host': _host(
            extraChildren: ['grab', 'replace', 'drop'],
            extra: [
              ..._grab,
              ..._button('replace', {
                'type': 'updateSubPage',
                'subPageId': 'detail',
                'pageId': 'detail/b',
                'mode': 'replace',
              }),
              ..._button('drop', {'type': 'deleteComponent', 'id': 'detail'}),
            ],
          ),
          'detail/a': detail('a'),
          'detail/b': detail('b'),
        },
        actions: {
          'add': [
            {
              'type': 'addComponent',
              'parentId': '0',
              'components': [_text('added', 'Added')],
            },
          ],
        },
      );
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');

      Iterable<String> mounted() =>
          h.store.nodeMap.keys.where((id) => id.startsWith('detail:'));
      const own = [
        'detail:0',
        'detail:label',
        'detail:count',
        'detail:add',
        'detail:add_label',
      ];

      await h.tap(tester, 'add');
      expect(find.text('Added'), findsOneWidget);
      expect(mounted(), unorderedEquals([...own, 'detail:added']));

      await h.tap(tester, 'replace');
      expect(find.text('Page b'), findsOneWidget);
      expect(find.text('Added'), findsNothing);
      expect(mounted(), unorderedEquals(own));

      await h.tap(tester, 'add');
      expect(mounted(), unorderedEquals([...own, 'detail:added']));

      await h.tap(tester, 'drop');
      expect(mounted(), isEmpty);
    },
  );

  testWidgets(
    'C-flutter: a host refetch keeps the sub-page nodes and its state value',
    (tester) async {
      final detail = _detail('a', 5);
      (detail['components'] as List)
        ..addAll(_button('bump', _setPage('count', 6)))
        ..[0]['children'] = ['label', 'count', 'bump'];
      final client = _StubClient({
        'host': _host(
          extraChildren: ['grab', 'hostBump', 'refetch'],
          extra: [
            ..._grab,
            ..._button('hostBump', _setPage('count', 101)),
            ..._button('refetch', {'type': 'refetchPage'}),
          ],
        ),
        'detail/a': detail,
      });
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');
      await h.tap(tester, 'bump');
      await h.tap(tester, 'hostBump');
      expect(h.pageState, {'count': 101, 'detail:count': 6});

      await h.tap(tester, 'refetch');

      expect(client.fetched, ['host', 'detail/a', 'host']);
      // The host's own keys start again; the mounted page keeps its value.
      expect(h.pageState, {'count': 100, 'detail:count': 6});
      expect(
        h.store.nodeMap.keys.where((id) => id.startsWith('detail:')),
        unorderedEquals([
          'detail:0',
          'detail:label',
          'detail:count',
          'detail:bump',
          'detail:bump_label',
        ]),
      );
      expect(find.text('Page a'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    },
  );

  testWidgets('C-flutter: openDialog shows a Dialog node of the sub-page', (
    tester,
  ) async {
    final client = _StubClient({
      'host': _host(),
      'detail/a': _page(
        'detail/a',
        [
          _node('0', 'Column', children: ['label', 'open', 'dlg']),
          _text('label', 'Page a'),
          ..._button('open', {'type': 'openDialog', 'dialogId': 'dlg'}),
          _node(
            'dlg',
            'Dialog',
            kind: 'structure',
            childMode: 'single',
            children: ['secret'],
          ),
          _text('secret', _pageRef('secret'), watches: ['secret']),
        ],
        state: {'secret': 77},
      ),
    });
    final h = _Harness(client);
    await h.pump(tester);
    expect(find.text('77'), findsNothing);

    await h.tap(tester, 'open');

    expect(tester.takeException(), isNull);
    expect(find.text('77'), findsOneWidget);
  });

  testWidgets(
    'C-flutter: animateForward reaches an AnimatedBuilder of the sub-page',
    (tester) async {
      final client = _StubClient({
        'host': _host(
          extraChildren: ['grab', 'refresh'],
          extra: [
            ..._grab,
            ..._button('refresh', {
              'type': 'updateSubPage',
              'subPageId': 'detail',
              'pageId': 'detail/a',
              'mode': 'replace',
            }),
          ],
        ),
        'detail/a': _page('detail/a', [
          _node('0', 'Column', children: ['label', 'go', 'anim']),
          _text('label', 'Page a'),
          ..._button('go', {'type': 'animateForward', 'animationId': 'spin'}),
          _node(
            'anim',
            'AnimatedBuilder',
            childMode: 'single',
            props: {'animationId': 'spin', 'autoStart': false, 'duration': 100},
            children: ['animated'],
          ),
          _text('animated', 'Animated'),
        ]),
      });
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');

      final registry = h.executor!.animationRegistry!;
      expect(registry.getController('spin'), isNull);
      final controller = registry.getController('detail:spin');
      expect(controller, isNotNull);
      expect(controller!.value, 0.0);

      await h.tap(tester, 'go');

      expect(controller.value, 1.0);

      // The page that replaces it registers its own controller under the id.
      await h.tap(tester, 'refresh');

      final fresh = registry.getController('detail:spin');
      expect(fresh, isNotNull);
      expect(fresh, isNot(same(controller)));
      expect(fresh!.value, 0.0);

      await h.tap(tester, 'go');

      expect(fresh.value, 1.0);
    },
  );

  // ── Unmount follows the node, not the widget (S7, S8) ───────

  testWidgets(
    'C-flutter: a SubPage scrolled out of a lazy list and back keeps its '
    'pages, its state and an earlier updateSubPage, with no fetch',
    (tester) async {
      final client = _StubClient({
        'host': _listHost(),
        'detail/a': _bumpable('a', 5),
        'detail/b': _bumpable('b', 7),
      });
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');
      await h.tap(tester, 'replace');
      await h.tap(tester, 'bump');
      expect(find.text('Page b'), findsOneWidget);
      expect(h.pageState, {'detail:count': 8});

      Iterable<String> mounted() =>
          h.store.nodeMap.keys.where((id) => id.startsWith('detail:'));
      final nodes = mounted().toList();
      expect(nodes, hasLength(5));

      await _scrollTo(tester, 2500);

      // The widget is gone; the node, its pages and their state are not.
      expect(find.text('Page b'), findsNothing);
      expect(find.text('bump'), findsNothing);
      expect(mounted(), unorderedEquals(nodes));
      expect(h.store.subPagePrefixes, ['detail:']);
      expect(h.pageState, {'detail:count': 8});

      await _scrollTo(tester, 0);

      expect(find.text('Page b'), findsOneWidget);
      expect(find.text('Page a'), findsNothing);
      expect(find.text('8'), findsOneWidget);
      expect(h.pageState, {'detail:count': 8});
      expect(mounted(), unorderedEquals(nodes));
      expect(client.fetched, ['host', 'detail/a', 'detail/b']);

      // The widget that came back is the one updateSubPage reaches.
      await h.tap(tester, 'replace');

      expect(client.fetched, ['host', 'detail/a', 'detail/b', 'detail/b']);
      expect(find.text('7'), findsOneWidget);
      expect(h.pageState, {'detail:count': 7});
    },
  );

  testWidgets(
    'C-flutter: a SubPage whose widget is re-keyed by its parent in one '
    'frame keeps its pages, its state and an earlier updateSubPage',
    (tester) async {
      final host = _listHost(list: 'ReorderableListView');
      final client = _StubClient({
        'host': host,
        'detail/a': _bumpable('a', 5),
        'detail/b': _bumpable('b', 7),
      });
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');
      await h.tap(tester, 'replace');
      await h.tap(tester, 'bump');

      // The list comes back with `detail` second: its index key changes, so
      // its widget is built anew while the SubPage node stays in the page.
      h.store.replaceComponent('list', [
        ComponentNode.fromJson(
          _node(
            'list',
            'ReorderableListView',
            children: ['tail', 'detail', 'spacer'],
          ),
        ),
        for (final node in host['components'] as List)
          if (const ['tail', 'detail', 'spacer'].contains(node['id']))
            ComponentNode.fromJson(node as Map<String, dynamic>),
      ]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_top(tester, 'Tail'), lessThan(_top(tester, 'Page b')));
      expect(find.text('Page a'), findsNothing);
      expect(find.text('8'), findsOneWidget);
      expect(h.pageState, {'detail:count': 8});
      expect(client.fetched, ['host', 'detail/a', 'detail/b']);
    },
  );

  testWidgets(
    'C-flutter: a SubPage node deleted while no widget shows it is unmounted',
    (tester) async {
      final client = _StubClient({
        'host': _listHost(),
        'detail/a': _detail('a', 5),
      });
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');
      await _scrollTo(tester, 2500);
      expect(find.text('Page a'), findsNothing);
      expect(
        h.store.nodeMap.keys.where((id) => id.startsWith('detail:')),
        hasLength(3),
      );

      h.store.deleteComponent('detail');
      await tester.pumpAndSettle();

      expect(
        h.store.nodeMap.keys.where((id) => id.startsWith('detail')),
        isEmpty,
      );
      expect(h.store.subPagePrefixes, isEmpty);
      // S8: the state keys are left where they are.
      expect(h.pageState, {'detail:count': 5});

      await _scrollTo(tester, 0);

      expect(find.text('Page a'), findsNothing);
      expect(client.fetched, ['host', 'detail/a']);
    },
  );

  testWidgets(
    'C-flutter: a SubPage node deleted while shown in a list is unmounted',
    (tester) async {
      final client = _StubClient({
        'host': _listHost(),
        'detail/a': _detail('a', 5),
      });
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');
      expect(find.text('Page a'), findsOneWidget);

      h.store.deleteComponent('detail');
      await tester.pumpAndSettle();

      expect(find.text('Page a'), findsNothing);
      expect(
        h.store.nodeMap.keys.where((id) => id.startsWith('detail')),
        isEmpty,
      );
      expect(h.store.subPagePrefixes, isEmpty);
      expect(h.pageState, {'detail:count': 5});
      expect(client.fetched, ['host', 'detail/a']);
    },
  );

  testWidgets(
    'C-flutter: a nested SubPage is kept with its outer one, and unmounted '
    'with it when the outer node is deleted off screen',
    (tester) async {
      final client = _StubClient({
        'host': _listHost(),
        'detail/a': _outer(),
        'leaf/x': _leaf([_button('bump', _setPage('n', 2))]),
      });
      final h = _Harness(client);
      await h.pump(tester);
      await h.tap(tester, 'grab');
      await h.tap(tester, 'bump');
      expect(h.pageState, {'detail:count': 5, 'detail:inner:n': 2});

      await _scrollTo(tester, 2500);
      expect(find.text('Page a'), findsNothing);
      await _scrollTo(tester, 0);

      expect(find.text('Page a'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(h.pageState, {'detail:count': 5, 'detail:inner:n': 2});
      expect(client.fetched, ['host', 'detail/a', 'leaf/x']);

      await _scrollTo(tester, 2500);
      h.store.deleteComponent('detail');
      await tester.pumpAndSettle();

      expect(
        h.store.nodeMap.keys.where((id) => id.startsWith('detail')),
        isEmpty,
      );
      expect(h.store.subPagePrefixes, isEmpty);
      expect(h.pageState, {'detail:count': 5, 'detail:inner:n': 2});
    },
  );
}
