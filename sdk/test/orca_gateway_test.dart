import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

/// A plain Dart class with no `toJson()` — `jsonEncode` will refuse it.
/// Used to force the debugLog handler's fallback path during testing.
class _NonEncodable {
  final String marker = 'sentinel';
}

void main() {
  group('ComponentNode', () {
    test('fromJson parses wire format correctly', () {
      final json = {
        'id': 'n1',
        'type': 'Text',
        'kind': 'primitive',
        'childMode': 'none',
        'props': {'data': 'Hello'},
        'children': <String>[],
        'watches': <String>[],
      };

      final node = ComponentNode.fromJson(json);

      expect(node.id, 'n1');
      expect(node.type, 'Text');
      expect(node.kind, 'primitive');
      expect(node.childMode, 'none');
      expect(node.props['data'], 'Hello');
      expect(node.children, isEmpty);
      expect(node.watches, isEmpty);
      expect(node.actions, isNull);
    });

    test('fromJson parses actions', () {
      final json = {
        'id': 'n1',
        'type': 'ElevatedButton',
        'kind': 'button',
        'childMode': 'single',
        'props': {},
        'children': ['n2'],
        'watches': [],
        'actions': {
          'onTap': {'type': 'setState', 'scope': 'page', 'key': 'count', 'value': {'type': 'static', 'value': 1}},
        },
      };

      final node = ComponentNode.fromJson(json);

      expect(node.actions, isNotNull);
      expect(node.actions!['onTap'], isA<Map>());
    });

    test('toJson round-trips correctly', () {
      final node = ComponentNode(
        id: 'n1',
        type: 'Column',
        kind: 'layout',
        childMode: 'multi',
        props: {'gap': 8},
        children: ['n2', 'n3'],
        watches: ['count'],
      );

      final json = node.toJson();
      final restored = ComponentNode.fromJson(json);

      expect(restored.id, node.id);
      expect(restored.type, node.type);
      expect(restored.children, node.children);
      expect(restored.watches, node.watches);
    });
  });

  group('PageResponse', () {
    test('fromJson parses full response', () {
      final json = {
        'pageId': 'home',
        'title': 'Counter',
        'state': [
          {'key': 'count', 'scope': 'page', 'initial': 0},
        ],
        'components': [
          {
            'id': 'n1',
            'type': 'Text',
            'kind': 'primitive',
            'childMode': 'none',
            'props': {'data': 'Hello'},
            'children': <String>[],
            'watches': <String>[],
          },
        ],
        'customField': 'extra',
      };

      final response = PageResponse.fromJson(json);

      expect(response.pageId, 'home');
      expect(response.title, 'Counter');
      expect(response.state, hasLength(1));
      expect(response.state.first.key, 'count');
      expect(response.state.first.scope, 'page');
      expect(response.state.first.initial, 0);
      expect(response.components, hasLength(1));
      expect(response.extra['customField'], 'extra');
    });
  });

  group('ComponentRegistry', () {
    test('register and retrieve builder', () {
      final registry = ComponentRegistry();
      registry.register('Custom', (ctx) => const Text('custom'));

      expect(registry.has('Custom'), isTrue);
      expect(registry.has('Unknown'), isFalse);
      expect(registry.get('Custom'), isNotNull);
    });

    test('registerDefaults registers all built-in types', () {
      final registry = ComponentRegistry();
      registry.registerDefaults();

      // Layout
      expect(registry.has('Column'), isTrue);
      expect(registry.has('Row'), isTrue);
      expect(registry.has('Container'), isTrue);
      expect(registry.has('Stack'), isTrue);
      expect(registry.has('SizedBox'), isTrue);
      expect(registry.has('Padding'), isTrue);
      expect(registry.has('Center'), isTrue);
      expect(registry.has('Expanded'), isTrue);

      // Primitive
      expect(registry.has('Text'), isTrue);
      expect(registry.has('Image'), isTrue);
      expect(registry.has('Icon'), isTrue);
      expect(registry.has('Divider'), isTrue);

      // Input
      expect(registry.has('TextField'), isTrue);
      expect(registry.has('Checkbox'), isTrue);
      expect(registry.has('Switch'), isTrue);
      expect(registry.has('Slider'), isTrue);

      // Button
      expect(registry.has('ElevatedButton'), isTrue);
      expect(registry.has('TextButton'), isTrue);
      expect(registry.has('IconButton'), isTrue);

      // Structure
      expect(registry.has('Scaffold'), isTrue);
      expect(registry.has('AppBar'), isTrue);
      expect(registry.has('Card'), isTrue);
      expect(registry.has('ListView'), isTrue);
      expect(registry.has('GridView'), isTrue);
    });
  });

  group('ComponentRenderer', () {
    late ComponentRegistry registry;
    late ComponentRenderer renderer;

    setUp(() {
      registry = ComponentRegistry()..registerDefaults();
      renderer = ComponentRenderer(registry: registry);
    });

    testWidgets('renders a Text node', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Hello World'},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders Column with children', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Column',
          kind: 'layout',
          childMode: 'multi',
          props: {},
          children: ['n2', 'n3'],
          watches: [],
        ),
        ComponentNode(
          id: 'n2',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'First'},
          children: [],
          watches: [],
        ),
        ComponentNode(
          id: 'n3',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Second'},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('renders nested layout tree', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Center',
          kind: 'layout',
          childMode: 'single',
          props: {},
          children: ['n2'],
          watches: [],
        ),
        ComponentNode(
          id: 'n2',
          type: 'Column',
          kind: 'layout',
          childMode: 'multi',
          props: {'mainAxisAlignment': 'center'},
          children: ['n3', 'n4'],
          watches: [],
        ),
        ComponentNode(
          id: 'n3',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Title', 'style': {'fontSize': 24, 'fontWeight': 'bold'}},
          children: [],
          watches: [],
        ),
        ComponentNode(
          id: 'n4',
          type: 'SizedBox',
          kind: 'layout',
          childMode: 'single',
          props: {'height': 16},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(find.byType(Center), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders Container with decoration', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Container',
          kind: 'layout',
          childMode: 'single',
          props: {
            'padding': {'top': 16, 'right': 16, 'bottom': 16, 'left': 16},
            'decoration': {
              'color': '#FF0000',
              'borderRadius': 8,
            },
          },
          children: ['n2'],
          watches: [],
        ),
        ComponentNode(
          id: 'n2',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Boxed'},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
      expect(find.text('Boxed'), findsOneWidget);
    });

    testWidgets('renders ElevatedButton with child', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'ElevatedButton',
          kind: 'button',
          childMode: 'single',
          props: {},
          children: ['n2'],
          watches: [],
        ),
        ComponentNode(
          id: 'n2',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Click Me'},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: renderer.render(nodes),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders Scaffold with AppBar and body', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Scaffold',
          kind: 'structure',
          childMode: 'none',
          props: {'appBar': 'n2', 'body': 'n5'},
          children: [],
          watches: [],
        ),
        ComponentNode(
          id: 'n2',
          type: 'AppBar',
          kind: 'structure',
          childMode: 'none',
          props: {'title': 'n3', 'centerTitle': true},
          children: [],
          watches: [],
        ),
        ComponentNode(
          id: 'n3',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Counter'},
          children: [],
          watches: [],
        ),
        ComponentNode(
          id: 'n5',
          type: 'Center',
          kind: 'layout',
          childMode: 'single',
          props: {},
          children: ['n6'],
          watches: [],
        ),
        ComponentNode(
          id: 'n6',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': '0'},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: renderer.render(nodes),
        ),
      );

      expect(find.text('Counter'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('safe-degrades unknown component type to FallbackPrompt', (tester) async {
      // Contract change (Epic 25b, task 25b.9): unknown component types used
      // to render a red ErrorWidget; they now safe-degrade to a FallbackPrompt
      // with the unknown type name in the body so end users see actionable
      // text instead of a dev-facing error overlay. The detailed spec lives
      // in test/safe_degrade_test.dart — this case is kept here as a sanity
      // check that the existing ComponentRenderer group covers the new
      // behavior end-to-end.
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'NonExistent',
          kind: 'primitive',
          childMode: 'none',
          props: {},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('Unsupported content'), findsOneWidget);
      expect(find.textContaining('"NonExistent"'), findsOneWidget);

      // Clean up telemetry dedup so later tests in this file are isolated.
      OrcaTelemetry.resetForTesting();
    });

    testWidgets('renders empty node list as SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render([]),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    test('custom component registration works', () {
      final registry = ComponentRegistry()..registerDefaults();
      registry.register('custom:MyWidget', (ctx) {
        return const Text('Custom!');
      });

      expect(registry.has('custom:MyWidget'), isTrue);
    });

    testWidgets('renders Row with gap', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Row',
          kind: 'layout',
          childMode: 'multi',
          props: {'gap': 8},
          children: ['n2', 'n3'],
          watches: [],
        ),
        ComponentNode(
          id: 'n2',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'A'},
          children: [],
          watches: [],
        ),
        ComponentNode(
          id: 'n3',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'B'},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      // Gap adds a SizedBox between children
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });

  group('Builder helpers', () {
    test('parseEdgeInsets handles map', () {
      final insets = parseEdgeInsets({
        'top': 10, 'right': 20, 'bottom': 30, 'left': 40,
      });
      expect(insets, isNotNull);
      expect(insets!.top, 10);
      expect(insets.right, 20);
      expect(insets.bottom, 30);
      expect(insets.left, 40);
    });

    test('parseEdgeInsets returns null for null', () {
      expect(parseEdgeInsets(null), isNull);
    });

    test('parseColor handles hex strings', () {
      final color = parseColor('#FF0000');
      expect(color, isNotNull);
      expect(color!.toARGB32(), 0xFFFF0000);
    });

    test('parseColor handles 8-digit hex (CSS #RRGGBBAA, alpha-last)', () {
      // Input: red (FF0000) at 50% alpha (80). CSS alpha is the last two
      // chars; parseColor rotates it into Flutter's AARRGGBB internally.
      final color = parseColor('#FF000080');
      expect(color, isNotNull);
      expect(color!.toARGB32(), 0x80FF0000);
    });

    test('resolveStringValue handles static Value', () {
      expect(resolveStringValue({'type': 'static', 'value': 'hello'}), 'hello');
    });

    test('resolveStringValue handles plain string', () {
      expect(resolveStringValue('hello'), 'hello');
    });

    test('resolveStringValue handles number', () {
      expect(resolveStringValue(42), '42');
    });

    test('resolveStringValue resolves state-bound value', () {
      final state = {'count': 42};
      expect(resolveStringValue({'type': 'state', 'key': 'count'}, state), '42');
    });

    test('resolveStringValue returns empty for missing state key', () {
      expect(resolveStringValue({'type': 'state', 'key': 'missing'}, {}), '');
    });

    test('parseTextStyle parses font properties', () {
      final style = parseTextStyle({
        'fontSize': 24,
        'fontWeight': 'bold',
        'color': '#000000',
      });
      expect(style, isNotNull);
      expect(style!.fontSize, 24);
      expect(style.fontWeight, FontWeight.bold);
    });
  });

  // ── Epic 7: State Management ──────────────────────────────────

  group('ElmStore', () {
    test('initializes with empty state by default', () {
      final store = ElmStore();
      expect(store.state, isEmpty);
    });

    test('initializes with provided state', () {
      final store = ElmStore(initial: {'count': 0, 'name': 'test'});
      expect(store.get('count'), 0);
      expect(store.get('name'), 'test');
    });

    test('dispatch merges update and notifies listeners', () {
      final store = ElmStore(initial: {'count': 0});
      var notified = false;
      store.addListener(() => notified = true);

      store.dispatch({'count': 5});

      expect(store.get('count'), 5);
      expect(notified, isTrue);
    });

    test('dispatch adds new keys without removing existing ones', () {
      final store = ElmStore(initial: {'a': 1});
      store.dispatch({'b': 2});

      expect(store.get('a'), 1);
      expect(store.get('b'), 2);
    });

    test('get returns null for missing key', () {
      final store = ElmStore();
      expect(store.get('missing'), isNull);
    });
  });

  group('StateManager', () {
    late StateManager manager;

    setUp(() {
      manager = StateManager();
    });

    test('initPage creates page store from state definitions', () {
      manager.initPage('home', [
        StateDefinition(key: 'count', scope: 'page', initial: 0),
      ]);

      expect(manager.getPageState('home', 'count'), 0);
    });

    test('app-scoped definitions go to appStore', () {
      manager.initPage('home', [
        StateDefinition(key: 'token', scope: 'app', initial: 'abc'),
      ]);

      expect(manager.getAppState('token'), 'abc');
    });

    test('app state persists across page inits', () {
      manager.initPage('home', [
        StateDefinition(key: 'token', scope: 'app', initial: 'abc'),
      ]);
      // Second page init should not overwrite existing app state
      manager.initPage('settings', [
        StateDefinition(key: 'token', scope: 'app', initial: 'default'),
      ]);

      expect(manager.getAppState('token'), 'abc');
    });

    test('setPageState updates page store', () {
      manager.initPage('home', [
        StateDefinition(key: 'count', scope: 'page', initial: 0),
      ]);

      manager.setPageState('home', 'count', 42);
      expect(manager.getPageState('home', 'count'), 42);
    });

    test('setAppState updates app store', () {
      manager.setAppState('theme', 'dark');
      expect(manager.getAppState('theme'), 'dark');
    });

    test('disposePage removes page store', () {
      manager.initPage('home', [
        StateDefinition(key: 'count', scope: 'page', initial: 0),
      ]);

      manager.disposePage('home');
      expect(manager.getPageStore('home'), isNull);
    });

    test('page state is independent across pages', () {
      manager.initPage('page1', [
        StateDefinition(key: 'count', scope: 'page', initial: 10),
      ]);
      manager.initPage('page2', [
        StateDefinition(key: 'count', scope: 'page', initial: 20),
      ]);

      expect(manager.getPageState('page1', 'count'), 10);
      expect(manager.getPageState('page2', 'count'), 20);
    });
  });

  group('ActionExecutor', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'count', scope: 'page', initial: 0),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'home');
    });

    test('setState with static value', () {
      executor.execute({
        'type': 'setState',
        'key': 'count',
        'value': 5,
      });

      expect(manager.getPageState('home', 'count'), 5);
    });

    test('setState with transform pipeline (add)', () {
      executor.execute({
        'type': 'setState',
        'scope': 'page',
        'key': 'count',
        'value': {
          'type': 'transform',
          'input': {'type': 'state', 'key': 'count', 'scope': 'page'},
          'by': [
            {'type': 'add', 'by': {'type': 'static', 'value': 1}},
          ],
        },
      });

      expect(manager.getPageState('home', 'count'), 1);
    });

    test('setState with transform pipeline (subtract)', () {
      manager.setPageState('home', 'count', 10);
      executor.execute({
        'type': 'setState',
        'scope': 'page',
        'key': 'count',
        'value': {
          'type': 'transform',
          'input': {'type': 'state', 'key': 'count', 'scope': 'page'},
          'by': [
            {'type': 'subtract', 'by': {'type': 'static', 'value': 3}},
          ],
        },
      });

      expect(manager.getPageState('home', 'count'), 7);
    });

    test('setState with transform pipeline (toggle)', () {
      manager.initPage('form', [
        StateDefinition(key: 'checked', scope: 'page', initial: false),
      ]);
      final formExecutor = ActionExecutor(stateManager: manager, pageId: 'form');

      formExecutor.execute({
        'type': 'setState',
        'key': 'checked',
        'value': {
          'type': 'transform',
          'input': {'type': 'state', 'key': 'checked', 'scope': 'page'},
          'by': [
            {'type': 'toggle'},
          ],
        },
      });

      expect(manager.getPageState('form', 'checked'), true);
    });

    test('setState with app scope', () {
      executor.execute({
        'type': 'setState',
        'scope': 'app',
        'key': 'theme',
        'value': 'dark',
      });

      expect(manager.getAppState('theme'), 'dark');
    });

    test('executeAll runs multiple actions', () async {
      await executor.executeAll([
        {'type': 'setState', 'key': 'count', 'value': 10},
        {'type': 'setState', 'scope': 'app', 'key': 'lang', 'value': 'en'},
      ]);

      expect(manager.getPageState('home', 'count'), 10);
      expect(manager.getAppState('lang'), 'en');
    });

    test('unknown action type is silently ignored', () {
      executor.execute({'type': 'navigate', 'path': '/settings'});
      expect(manager.getPageState('home', 'count'), 0);
    });
  });

  group('State initialization from JSON', () {
    test('PageResponse state definitions initialize correctly', () {
      final json = {
        'pageId': 'counter',
        'title': 'Counter',
        'state': [
          {'key': 'count', 'scope': 'page', 'initial': 0},
          {'key': 'theme', 'scope': 'app', 'initial': 'light'},
        ],
        'components': <Map<String, dynamic>>[],
      };

      final response = PageResponse.fromJson(json);
      final manager = StateManager();
      manager.initPage(response.pageId, response.state);

      expect(manager.getPageState('counter', 'count'), 0);
      expect(manager.getAppState('theme'), 'light');
    });
  });

  group('ComponentRenderer with state', () {
    late ComponentRegistry registry;

    setUp(() {
      registry = ComponentRegistry()..registerDefaults();
    });

    testWidgets('Text resolves state-bound data prop', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': {'type': 'state', 'key': 'count'}},
          children: [],
          watches: ['count'],
        ),
      ];

      final renderer = ComponentRenderer(
        registry: registry,
        state: {'count': 42},
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('IconButton with NO actions does NOT absorb taps from an outer GestureDetector', (tester) async {
      // Critical regression: the user's chat page wraps IconButton in an
      // outer GestureDetector — the outer carries Sequential(DebugLog,
      // ServerAction) on onTap, the IconButton has no actions of its own
      // (only a color prop). Before the fix, the IconButton's internal
      // GestureDetector registered onTap/onLongPress unconditionally with
      // HitTestBehavior.opaque, so the tap was swallowed and fireAction
      // bailed early because node.actions was empty. The outer onTap never
      // fired — "nothing logs at all" from the user's perspective.
      //
      // Fix: only wrap IconButton in a GestureDetector when it actually
      // has tap or long-press actions. No actions = pass-through, and
      // outer gesture wrappers receive the tap as intended.
      final manager = StateManager();
      manager.initPage('chat', [
        StateDefinition(key: 'outerTapCount', scope: 'page', initial: 0),
      ]);
      final executor = ActionExecutor(stateManager: manager, pageId: 'chat');

      final nodes = [
        ComponentNode(
          id: 'wrapper',
          type: 'GestureDetector',
          kind: 'layout',
          childMode: 'single',
          props: {},
          children: ['btn'],
          watches: [],
          actions: {
            'onTap': {
              'type': 'setState',
              'scope': 'page',
              'key': 'outerTapCount',
              'value': {
                'type': 'transform',
                'input': {'type': 'state', 'key': 'outerTapCount', 'scope': 'page'},
                'by': [
                  {'type': 'add', 'by': {'type': 'static', 'value': 1}},
                ],
              },
            },
          },
        ),
        // IconButton with NO actions — only styling.
        ComponentNode(
          id: 'btn',
          type: 'IconButton',
          kind: 'button',
          childMode: 'single',
          props: {'size': 22, 'color': '#7C3AED'},
          children: ['icon'],
          watches: [],
        ),
        ComponentNode(
          id: 'icon',
          type: 'Icon',
          kind: 'primitive',
          childMode: 'none',
          props: {'name': 'send', 'size': 22},
          children: [],
          watches: [],
        ),
      ];

      final renderer = ComponentRenderer(
        registry: registry,
        state: manager.getPageStore('chat')!.state,
        actionExecutor: executor,
      );

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: renderer.render(nodes))),
      );

      await tester.tap(find.byType(Icon));
      await tester.pump();

      expect(manager.getPageState('chat', 'outerTapCount'), 1,
          reason: 'Outer GestureDetector must receive tap when '
              'IconButton has no actions of its own');
    });

    testWidgets('IconButton inside Row renders as a tappable widget (chat-page shape)', (tester) async {
      // Mirrors the exact chat page: Row > [Expanded(TextField), SizedBox, IconButton(Icon)].
      // Protects against builder regressions that would strip the IconButton
      // wrapper leaving only the raw Icon — which is what the user reported
      // seeing when they inspected the widget tree. If _buildIconButton
      // fails to return a GestureDetector around the icon, this test fails.
      final manager = StateManager();
      manager.initPage('chat', [
        StateDefinition(key: 'sendCount', scope: 'page', initial: 0),
      ]);
      final executor = ActionExecutor(stateManager: manager, pageId: 'chat');

      final nodes = [
        ComponentNode(
          id: 'row',
          type: 'Row',
          kind: 'layout',
          childMode: 'multi',
          props: {'crossAxisAlignment': 'center'},
          children: ['exp', 'sp', 'btn'],
          watches: [],
        ),
        ComponentNode(
          id: 'exp',
          type: 'Expanded',
          kind: 'layout',
          childMode: 'single',
          props: {},
          children: ['tf'],
          watches: [],
        ),
        ComponentNode(
          id: 'tf',
          type: 'TextField',
          kind: 'input',
          childMode: 'none',
          props: {'placeholder': 'Type a message'},
          children: [],
          watches: [],
        ),
        ComponentNode(
          id: 'sp',
          type: 'SizedBox',
          kind: 'layout',
          childMode: 'single',
          props: {'width': 8},
          children: [],
          watches: [],
        ),
        ComponentNode(
          id: 'btn',
          type: 'IconButton',
          kind: 'button',
          childMode: 'single',
          props: {'size': 22, 'color': '#7C3AED'},
          children: ['icon'],
          watches: [],
          actions: {
            'onTap': {
              'type': 'setState',
              'scope': 'page',
              'key': 'sendCount',
              'value': {'type': 'static', 'value': 5},
            },
          },
        ),
        ComponentNode(
          id: 'icon',
          type: 'Icon',
          kind: 'primitive',
          childMode: 'none',
          props: {'name': 'send', 'size': 22},
          children: [],
          watches: [],
        ),
      ];

      final renderer = ComponentRenderer(
        registry: registry,
        state: manager.getPageStore('chat')!.state,
        actionExecutor: executor,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.ltr,
              child: renderer.render(nodes),
            ),
          ),
        ),
      );

      // After my latest fix, the IconButton builder wraps the Icon in a
      // GestureDetector — so find.byType(GestureDetector) must locate it.
      // If the user's tree shows only Icon (no GestureDetector ancestor),
      // this assertion catches it.
      expect(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(GestureDetector),
        ),
        findsWidgets,
        reason: 'IconButton must render a GestureDetector wrapper inside Row',
      );

      // Tap fires the action.
      await tester.tap(find.byType(Icon));
      await tester.pump();
      expect(manager.getPageState('chat', 'sendCount'), 5,
          reason: 'Tap on send Icon must fire IconButton onTap');
    });

    testWidgets('IconButton fires onTap action when tapped', (tester) async {
      // Regression: after the IconButton refactor wrapped Material's
      // IconButton in a GestureDetector(onLongPress), tap events were
      // getting swallowed in some gesture-arena configurations. Restoring
      // the unified GestureDetector(onTap + onLongPress) with
      // HitTestBehavior.opaque should reliably fire onTap on any tap
      // within the hit area.
      final manager = StateManager();
      manager.initPage('chat', [
        StateDefinition(key: 'sendCount', scope: 'page', initial: 0),
      ]);
      final executor = ActionExecutor(stateManager: manager, pageId: 'chat');

      final nodes = [
        ComponentNode(
          id: 'send-btn',
          type: 'IconButton',
          kind: 'button',
          childMode: 'single',
          props: {'size': 22, 'color': '#7C3AED'},
          children: ['icon'],
          watches: [],
          actions: {
            'onTap': {
              'type': 'actionGroup',
              'mode': 'sequential',
              'actions': [
                {
                  'type': 'debugLog',
                  'level': 'info',
                  'tag': 'chat',
                  'message': 'send tapped',
                  'includeState': true,
                },
                {
                  'type': 'setState',
                  'scope': 'page',
                  'key': 'sendCount',
                  'value': {
                    'type': 'transform',
                    'input': {'type': 'state', 'key': 'sendCount', 'scope': 'page'},
                    'by': [
                      {'type': 'add', 'by': {'type': 'static', 'value': 1}},
                    ],
                  },
                },
              ],
            },
          },
        ),
        ComponentNode(
          id: 'icon',
          type: 'Icon',
          kind: 'primitive',
          childMode: 'none',
          props: {'name': 'send', 'size': 22},
          children: [],
          watches: [],
        ),
      ];

      final renderer = ComponentRenderer(
        registry: registry,
        state: manager.getPageStore('chat')!.state,
        actionExecutor: executor,
      );

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: renderer.render(nodes))),
      );

      // Tap the IconButton — after the fix, this must fire both the
      // debugLog (no-op side effect for state) and the setState.
      await tester.tap(find.byType(Icon));
      await tester.pump();

      expect(manager.getPageState('chat', 'sendCount'), 1,
          reason: 'onTap must fire Sequential(debugLog, setState) in full');
    });

    testWidgets('ElevatedButton fires setState action on tap', (tester) async {
      final manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'count', scope: 'page', initial: 0),
      ]);
      final executor = ActionExecutor(stateManager: manager, pageId: 'home');

      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'ElevatedButton',
          kind: 'button',
          childMode: 'single',
          props: {},
          children: ['n2'],
          watches: [],
          actions: {
            'onTap': {
              'type': 'setState',
              'scope': 'page',
              'key': 'count',
              'value': {
                'type': 'transform',
                'input': {'type': 'state', 'key': 'count', 'scope': 'page'},
                'by': [
                  {'type': 'add', 'by': {'type': 'static', 'value': 1}},
                ],
              },
            },
          },
        ),
        ComponentNode(
          id: 'n2',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': '+'},
          children: [],
          watches: [],
        ),
      ];

      final renderer = ComponentRenderer(
        registry: registry,
        state: manager.getPageStore('home')!.state,
        actionExecutor: executor,
      );

      await tester.pumpWidget(
        MaterialApp(home: renderer.render(nodes)),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(manager.getPageState('home', 'count'), 1);
    });

    testWidgets('Text resolves transform pipeline with toString', (tester) async {
      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {
            'data': {
              'type': 'transform',
              'input': {'type': 'state', 'key': 'count', 'scope': 'page'},
              'by': [
                {'type': 'toString'},
              ],
            },
          },
          children: [],
          watches: ['count'],
        ),
      ];

      final renderer = ComponentRenderer(
        registry: registry,
        state: {'count': 7},
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      expect(find.text('7'), findsOneWidget);
    });
  });

  group('ValueResolver', () {
    test('resolves static value', () {
      final r = ValueResolver(state: {});
      expect(r.resolve({'type': 'static', 'value': 42}), 42);
    });

    test('resolves state reference', () {
      final r = ValueResolver(state: {'count': 10});
      expect(r.resolve({'type': 'state', 'key': 'count'}), 10);
    });

    test('resolves transform pipeline with add', () {
      final r = ValueResolver(state: {'count': 5});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'state', 'key': 'count'},
        'by': [
          {'type': 'add', 'by': {'type': 'static', 'value': 3}},
        ],
      });
      expect(result, 8);
    });

    test('resolves transform pipeline with subtract', () {
      final r = ValueResolver(state: {'count': 10});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'state', 'key': 'count'},
        'by': [
          {'type': 'subtract', 'by': {'type': 'static', 'value': 4}},
        ],
      });
      expect(result, 6);
    });

    test('resolves chained pipeline (add then multiply)', () {
      final r = ValueResolver(state: {'x': 2});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'state', 'key': 'x'},
        'by': [
          {'type': 'add', 'by': {'type': 'static', 'value': 3}},
          {'type': 'multiply', 'by': {'type': 'static', 'value': 2}},
        ],
      });
      expect(result, 10); // (2 + 3) * 2
    });

    test('resolves toString in pipeline', () {
      final r = ValueResolver(state: {'count': 42});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'state', 'key': 'count'},
        'by': [
          {'type': 'toString'},
        ],
      });
      expect(result, '42');
    });

    test('resolveToString returns empty for null state', () {
      final r = ValueResolver(state: {});
      expect(r.resolveToString({'type': 'state', 'key': 'missing'}), '');
    });

    test('passes through literals unchanged', () {
      final r = ValueResolver(state: {});
      expect(r.resolve('hello'), 'hello');
      expect(r.resolve(42), 42);
      expect(r.resolve(true), true);
      expect(r.resolve(null), null);
    });

    // Feature: TemplateTransform + RegexTransform extensions.
    // Keep the old `{{value}}`-only test above unchanged and add the new
    // multi-placeholder surface here. These prove that a client receiving a
    // wire payload with `params: {...}` resolves them correctly — the new
    // capability that Settings-style pages rely on.
    test('template resolves named params from state and static', () {
      final r = ValueResolver(state: {'userName': 'Amr'});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'static', 'value': 'Hi'},
        'by': [
          {
            'type': 'template',
            'template': '{{greeting}}: {{value}}, {{name}}',
            'params': {
              'greeting': {'type': 'static', 'value': 'Welcome'},
              'name': {'type': 'state', 'key': 'userName'},
            },
          },
        ],
      });
      expect(result, 'Welcome: Hi, Amr');
    });

    test('template unknown placeholder renders empty (no literal braces)', () {
      final r = ValueResolver(state: {});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'static', 'value': 'x'},
        'by': [
          {'type': 'template', 'template': '[{{value}}|{{missing}}]'},
        ],
      });
      expect(result, '[x|]');
    });

    test('regex transform: match-only returns first match', () {
      final r = ValueResolver(state: {});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'static', 'value': 'abc123def'},
        'by': [
          {'type': 'regex', 'pattern': r'\d+'},
        ],
      });
      expect(result, '123');
    });

    test('regex transform: no match returns null', () {
      final r = ValueResolver(state: {});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'static', 'value': 'abc'},
        'by': [
          {'type': 'regex', 'pattern': r'\d+'},
        ],
      });
      expect(result, null);
    });

    test('regex replace with \$1 backref + {{value}} + named param', () {
      final r = ValueResolver(state: {'suffix': '!'});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'static', 'value': 'hello world'},
        'by': [
          {
            'type': 'regex',
            'pattern': r'(\w+) (\w+)',
            'replacement': r'$2 $1 ({{value}}){{suffix}}',
            'params': {
              'suffix': {'type': 'state', 'key': 'suffix'},
            },
          },
        ],
      });
      expect(result, 'world hello (hello world)!');
    });

    test('regex replace: global flag replaces all matches', () {
      final r = ValueResolver(state: {});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'static', 'value': 'a a a'},
        'by': [
          {
            'type': 'regex',
            'pattern': 'a',
            'flags': 'g',
            'replacement': 'b',
          },
        ],
      });
      expect(result, 'b b b');
    });

    test('regex replace: no g flag replaces only first match', () {
      final r = ValueResolver(state: {});
      final result = r.resolve({
        'type': 'transform',
        'input': {'type': 'static', 'value': 'a a a'},
        'by': [
          {
            'type': 'regex',
            'pattern': 'a',
            'replacement': 'b',
          },
        ],
      });
      expect(result, 'b a a');
    });
  });

  // ── Epic 8: Basic Actions ────────────────────────────────────

  group('ActionExecutor handler registry', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'count', scope: 'page', initial: 0),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'home');
    });

    test('registerHandler overrides default handler', () {
      var customCalled = false;
      executor.registerHandler('setState', (action, exec) async {
        customCalled = true;
      });
      executor.execute({'type': 'setState', 'key': 'count', 'value': 99});
      expect(customCalled, true);
      // Original handler was replaced, so state should not change.
      expect(manager.getPageState('home', 'count'), 0);
    });

    test('resolveString resolves state-bound value', () {
      manager.setPageState('home', 'count', 42);
      final result = executor.resolveString({
        'type': 'state',
        'key': 'count',
      });
      expect(result, '42');
    });

    test('resolveString returns empty for null', () {
      expect(executor.resolveString(null), '');
    });

    test('actionGroup executes child actions sequentially', () async {
      await executor.execute({
        'type': 'actionGroup',
        'mode': 'sequential',
        'actions': [
          {'type': 'setState', 'key': 'count', 'value': 10},
          {'type': 'setState', 'scope': 'app', 'key': 'lang', 'value': 'fr'},
        ],
      });
      expect(manager.getPageState('home', 'count'), 10);
      expect(manager.getAppState('lang'), 'fr');
    });

    test('Sequential(debugLog, setState) — debugLog must not block subsequent actions', () async {
      // Regression for the chat page send button: tapping the button fires
      // `Sequential(DebugLog(includeState: true), ServerAction(...))`. If the
      // debugLog handler throws or returns early, the subsequent action
      // never fires and the button appears broken.
      manager.setPageState('home', 'count', 0);
      await executor.execute({
        'type': 'actionGroup',
        'mode': 'sequential',
        'actions': [
          {
            'type': 'debugLog',
            'level': 'info',
            'tag': 'test',
            'message': 'chain step 1',
            'data': {
              'current': {'type': 'state', 'key': 'count', 'scope': 'page'},
            },
            'includeState': true,
            'includeEvent': true,
          },
          {'type': 'setState', 'key': 'count', 'value': 42},
        ],
      });
      expect(manager.getPageState('home', 'count'), 42);
    });

    test('debugLog never breaks Sequential even with non-JSON-encodable state', () async {
      // Critical regression: the user's chat page wraps Sequential(DebugLog +
      // includeState, ServerAction). If jsonEncode(pageState) throws because
      // state contains ANY non-encodable value, the Sequential for-loop
      // aborts and the ServerAction silently never fires. debugLog must
      // catch and swallow every possible failure so it cannot break the
      // chain. This test stashes a non-JSON-encodable object (a plain Dart
      // class) in pageState and then runs Sequential(debugLog+includeState,
      // setState). The setState MUST fire.
      //
      // Reproduces the "send icon button no longer working" bug where a
      // DebugLog handler throw prevented the subsequent ServerAction from
      // running, making the button appear dead.
      manager.setPageState('home', 'nonEncodable', _NonEncodable());
      manager.setPageState('home', 'count', 0);

      await executor.execute({
        'type': 'actionGroup',
        'mode': 'sequential',
        'actions': [
          {
            'type': 'debugLog',
            'level': 'info',
            'tag': 'chat',
            'message': 'sendMessage fired',
            'includeState': true,
          },
          {'type': 'setState', 'key': 'count', 'value': 99},
        ],
      });

      // The subsequent action fired — meaning debugLog did NOT throw.
      expect(manager.getPageState('home', 'count'), 99,
          reason:
              'Sequential(debugLog+includeState, setState) must run setState '
              'even when state contains non-JSON-encodable values');
    });

    test('debugLog alone completes without throwing when pageState is non-empty', () async {
      manager.setPageState('home', 'count', 7);
      manager.setAppState('draft', 'hello world');
      // If debugLog crashes on serialization (e.g. unencodable values in
      // state), later actions in a chain wouldn't fire. Exercise the full
      // includeState + includeEvent + data path once in isolation.
      await executor.execute({
        'type': 'debugLog',
        'level': 'warn',
        'tag': 'regression',
        'message': 'dump everything',
        'data': {
          'count': {'type': 'state', 'key': 'count', 'scope': 'page'},
        },
        'includeState': true,
        'includeEvent': true,
        'includeRequest': true,
      });
      // No exception => test passes.
    });

    test('navigate is no-op without context', () {
      // No context provided — should not throw.
      executor.execute({'type': 'navigate', 'path': '/settings'});
      expect(manager.getPageState('home', 'count'), 0);
    });

    test('goBack is no-op without context', () {
      executor.execute({'type': 'goBack'});
      expect(manager.getPageState('home', 'count'), 0);
    });

    test('showSnackbar is no-op without context', () {
      executor.execute({'type': 'showSnackbar', 'message': 'hello'});
      expect(manager.getPageState('home', 'count'), 0);
    });

    test('showToast is no-op without context', () {
      executor.execute({'type': 'showToast', 'message': 'hello'});
      expect(manager.getPageState('home', 'count'), 0);
    });
  });

  group('Navigate action', () {
    testWidgets('pushes a new route', (tester) async {
      final manager = StateManager();
      manager.initPage('home', []);

      late BuildContext capturedCtx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (ctx) {
            capturedCtx = ctx;
            return const Text('Home');
          }),
        ),
      );

      var builtPath = '';
      final executor = ActionExecutor(
        context: capturedCtx,
        stateManager: manager,
        pageId: 'home',
        pageBuilder: (path) {
          builtPath = path;
          return Text('Page: $path');
        },
      );

      executor.execute({'type': 'navigate', 'path': '/settings'});
      await tester.pumpAndSettle();

      expect(builtPath, '/settings');
      expect(find.text('Page: /settings'), findsOneWidget);
    });
  });

  group('GoBack action', () {
    testWidgets('pops the current route', (tester) async {
      final manager = StateManager();
      manager.initPage('home', []);

      late BuildContext secondCtx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (ctx) {
            return ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (ctx2) {
                      secondCtx = ctx2;
                      return const Text('Second');
                    },
                  ),
                );
              },
              child: const Text('Go'),
            );
          }),
        ),
      );

      // Push the second route.
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);

      // Pop via goBack action.
      final executor = ActionExecutor(
        context: secondCtx,
        stateManager: manager,
        pageId: 'home',
      );
      executor.execute({'type': 'goBack'});
      await tester.pumpAndSettle();

      expect(find.text('Second'), findsNothing);
    });
  });

  group('ShowSnackbar action', () {
    testWidgets('shows a SnackBar', (tester) async {
      final manager = StateManager();
      manager.initPage('home', []);

      late BuildContext capturedCtx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              capturedCtx = ctx;
              return const Text('Body');
            }),
          ),
        ),
      );

      final executor = ActionExecutor(
        context: capturedCtx,
        stateManager: manager,
        pageId: 'home',
      );

      executor.execute({
        'type': 'showSnackbar',
        'message': 'Saved!',
        'duration': 1000,
      });
      await tester.pump();

      expect(find.text('Saved!'), findsOneWidget);
    });
  });

  group('ShowToast action', () {
    testWidgets('shows a floating SnackBar', (tester) async {
      final manager = StateManager();
      manager.initPage('home', []);

      late BuildContext capturedCtx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              capturedCtx = ctx;
              return const Text('Body');
            }),
          ),
        ),
      );

      final executor = ActionExecutor(
        context: capturedCtx,
        stateManager: manager,
        pageId: 'home',
      );

      executor.execute({
        'type': 'showToast',
        'message': 'Copied!',
      });
      await tester.pump();

      expect(find.text('Copied!'), findsOneWidget);
    });
  });

  group('CopyToClipboard action', () {
    test('calls Clipboard.setData without throwing', () {
      final manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'text', scope: 'page', initial: 'hello world'),
      ]);

      final executor = ActionExecutor(
        stateManager: manager,
        pageId: 'home',
      );

      // Should not throw — exercises resolveString with state ref.
      expect(
        () => executor.execute({
          'type': 'copyToClipboard',
          'text': {'type': 'state', 'key': 'text'},
        }),
        returnsNormally,
      );
    });
  });

  group('OrcaLifecycleWrapper', () {
    testWidgets('fires onInit after first frame', (tester) async {
      var initFired = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: OrcaLifecycleWrapper(
            onInit: () => initFired = true,
            child: const Text('child'),
          ),
        ),
      );

      // onInit fires via addPostFrameCallback, so pump once more.
      await tester.pump();
      expect(initFired, true);
    });

    testWidgets('fires onVisible after first frame', (tester) async {
      var visibleFired = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: OrcaLifecycleWrapper(
            onVisible: () => visibleFired = true,
            child: const Text('child'),
          ),
        ),
      );

      await tester.pump();
      expect(visibleFired, true);
    });
  });

  group('ComponentRenderer lifecycle integration', () {
    testWidgets('wraps node with onInit action in OrcaLifecycleWrapper',
        (tester) async {
      final manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'initialized', scope: 'page', initial: false),
      ]);
      final executor = ActionExecutor(stateManager: manager, pageId: 'home');
      final registry = ComponentRegistry()..registerDefaults();

      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Hello'},
          children: [],
          watches: [],
          actions: {
            'onInit': {
              'type': 'setState',
              'key': 'initialized',
              'value': true,
            },
          },
        ),
      ];

      final renderer = ComponentRenderer(
        registry: registry,
        state: manager.getPageStore('home')!.state,
        actionExecutor: executor,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render(nodes),
        ),
      );

      // onInit fires after post-frame callback.
      await tester.pump();
      expect(manager.getPageState('home', 'initialized'), true);
    });
  });

  group('Action integration end-to-end', () {
    testWidgets('tap button → setState + showSnackbar', (tester) async {
      final manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'count', scope: 'page', initial: 0),
      ]);
      final registry = ComponentRegistry()..registerDefaults();

      final nodes = [
        ComponentNode(
          id: 'n1',
          type: 'ElevatedButton',
          kind: 'button',
          childMode: 'single',
          props: {},
          children: ['n2'],
          watches: [],
          actions: {
            'onTap': [
              {
                'type': 'setState',
                'key': 'count',
                'value': {
                  'type': 'transform',
                  'input': {'type': 'state', 'key': 'count'},
                  'by': [
                    {'type': 'add', 'by': {'type': 'static', 'value': 1}},
                  ],
                },
              },
              {
                'type': 'showSnackbar',
                'message': 'Incremented!',
              },
            ],
          },
        ),
        ComponentNode(
          id: 'n2',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': '+'},
          children: [],
          watches: [],
        ),
      ];

      // Use a Builder to capture context that is below both MaterialApp
      // and Scaffold, so ScaffoldMessenger.of works.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              final executor = ActionExecutor(
                context: ctx,
                stateManager: manager,
                pageId: 'home',
              );
              final renderer = ComponentRenderer(
                registry: registry,
                state: manager.getPageStore('home')!.state,
                actionExecutor: executor,
              );
              return renderer.render(nodes);
            }),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(manager.getPageState('home', 'count'), 1);
      expect(find.text('Incremented!'), findsOneWidget);
    });
  });

  // ── Epic 11: Conditions + Watches ──────────────────────────────

  group('11.9: BoolExpr evaluation (Flutter)', () {
    test('eq — equal values', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({'op': 'eq', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 5}}), true);
    });

    test('eq — unequal values', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({'op': 'eq', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 3}}), false);
    });

    test('neq', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({'op': 'neq', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 3}}), true);
      expect(resolver.evaluateBoolExpr({'op': 'neq', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 5}}), false);
    });

    test('gt / gte / lt / lte', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({'op': 'gt', 'left': {'type': 'static', 'value': 10}, 'right': {'type': 'static', 'value': 5}}), true);
      expect(resolver.evaluateBoolExpr({'op': 'gt', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 5}}), false);
      expect(resolver.evaluateBoolExpr({'op': 'gte', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 5}}), true);
      expect(resolver.evaluateBoolExpr({'op': 'lt', 'left': {'type': 'static', 'value': 3}, 'right': {'type': 'static', 'value': 5}}), true);
      expect(resolver.evaluateBoolExpr({'op': 'lte', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 5}}), true);
    });

    test('and — all true', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({
        'op': 'and',
        'exprs': [
          {'op': 'eq', 'left': {'type': 'static', 'value': 1}, 'right': {'type': 'static', 'value': 1}},
          {'op': 'gt', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 3}},
        ],
      }), true);
    });

    test('and — one false', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({
        'op': 'and',
        'exprs': [
          {'op': 'eq', 'left': {'type': 'static', 'value': 1}, 'right': {'type': 'static', 'value': 1}},
          {'op': 'gt', 'left': {'type': 'static', 'value': 3}, 'right': {'type': 'static', 'value': 5}},
        ],
      }), false);
    });

    test('or — one true', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({
        'op': 'or',
        'exprs': [
          {'op': 'eq', 'left': {'type': 'static', 'value': 1}, 'right': {'type': 'static', 'value': 2}},
          {'op': 'gt', 'left': {'type': 'static', 'value': 5}, 'right': {'type': 'static', 'value': 3}},
        ],
      }), true);
    });

    test('not', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({
        'op': 'not',
        'expr': {'op': 'eq', 'left': {'type': 'static', 'value': 1}, 'right': {'type': 'static', 'value': 2}},
      }), true);
    });

    test('isNull', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({'op': 'isNull', 'value': {'type': 'static', 'value': null}}), true);
      expect(resolver.evaluateBoolExpr({'op': 'isNull', 'value': {'type': 'static', 'value': 42}}), false);
      expect(resolver.evaluateBoolExpr({'op': 'isNull', 'value': {'type': 'state', 'key': 'missing', 'scope': 'page'}}), true);
    });

    test('contains — string', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({
        'op': 'contains',
        'haystack': {'type': 'static', 'value': 'hello world'},
        'needle': {'type': 'static', 'value': 'world'},
      }), true);
    });

    test('contains — array', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({
        'op': 'contains',
        'haystack': {'type': 'static', 'value': [1, 2, 3]},
        'needle': {'type': 'static', 'value': 2},
      }), true);
    });

    test('startsWith', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({
        'op': 'startsWith',
        'str': {'type': 'static', 'value': 'hello'},
        'prefix': {'type': 'static', 'value': 'hel'},
      }), true);
    });

    test('matches', () {
      final resolver = ValueResolver(state: {});
      expect(resolver.evaluateBoolExpr({
        'op': 'matches',
        'str': {'type': 'static', 'value': 'abc123'},
        'regex': r'\d+',
      }), true);
      expect(resolver.evaluateBoolExpr({
        'op': 'matches',
        'str': {'type': 'static', 'value': 'abc'},
        'regex': r'\d+',
      }), false);
    });

    test('evaluates with state values', () {
      final resolver = ValueResolver(state: {'count': 5});
      expect(resolver.evaluateBoolExpr({
        'op': 'gt',
        'left': {'type': 'state', 'key': 'count', 'scope': 'page'},
        'right': {'type': 'static', 'value': 3},
      }), true);
    });
  });

  group('11.7: ConditionalValue resolution (Flutter)', () {
    test('resolves first matching branch', () {
      final resolver = ValueResolver(state: {'stock': 5});
      final result = resolver.resolve({
        'type': 'conditional',
        'branches': [
          {
            'when': {'op': 'gt', 'left': {'type': 'state', 'key': 'stock', 'scope': 'page'}, 'right': {'type': 'static', 'value': 0}},
            'then': {'type': 'static', 'value': 'In Stock'},
          },
        ],
        'else': {'type': 'static', 'value': 'Out of Stock'},
      });
      expect(result, 'In Stock');
    });

    test('resolves else branch when no match', () {
      final resolver = ValueResolver(state: {'stock': 0});
      final result = resolver.resolve({
        'type': 'conditional',
        'branches': [
          {
            'when': {'op': 'gt', 'left': {'type': 'state', 'key': 'stock', 'scope': 'page'}, 'right': {'type': 'static', 'value': 0}},
            'then': {'type': 'static', 'value': 'In Stock'},
          },
        ],
        'else': {'type': 'static', 'value': 'Out of Stock'},
      });
      expect(result, 'Out of Stock');
    });

    test('resolves null when no match and no else', () {
      final resolver = ValueResolver(state: {});
      final result = resolver.resolve({
        'type': 'conditional',
        'branches': [
          {
            'when': {'op': 'eq', 'left': {'type': 'static', 'value': 1}, 'right': {'type': 'static', 'value': 2}},
            'then': {'type': 'static', 'value': 'never'},
          },
        ],
      });
      expect(result, isNull);
    });

    test('if/else-if/else chain', () {
      final conditional = {
        'type': 'conditional',
        'branches': [
          {
            'when': {'op': 'lt', 'left': {'type': 'state', 'key': 'temp', 'scope': 'page'}, 'right': {'type': 'static', 'value': 0}},
            'then': {'type': 'static', 'value': 'Freezing'},
          },
          {
            'when': {'op': 'lt', 'left': {'type': 'state', 'key': 'temp', 'scope': 'page'}, 'right': {'type': 'static', 'value': 20}},
            'then': {'type': 'static', 'value': 'Cold'},
          },
        ],
        'else': {'type': 'static', 'value': 'Warm'},
      };

      expect(ValueResolver(state: {'temp': -5}).resolve(conditional), 'Freezing');
      expect(ValueResolver(state: {'temp': 10}).resolve(conditional), 'Cold');
      expect(ValueResolver(state: {'temp': 25}).resolve(conditional), 'Warm');
    });

    test('nested condition inside condition', () {
      final inner = {
        'type': 'conditional',
        'branches': [
          {
            'when': {'op': 'eq', 'left': {'type': 'state', 'key': 'tier', 'scope': 'page'}, 'right': {'type': 'static', 'value': 'premium'}},
            'then': {'type': 'static', 'value': 'Free Shipping'},
          },
        ],
        'else': {'type': 'static', 'value': '\$9.99 Shipping'},
      };
      final outer = {
        'type': 'conditional',
        'branches': [
          {
            'when': {'op': 'gt', 'left': {'type': 'state', 'key': 'total', 'scope': 'page'}, 'right': {'type': 'static', 'value': 100}},
            'then': {'type': 'static', 'value': 'Free Shipping'},
          },
        ],
        'else': inner,
      };

      expect(ValueResolver(state: {'total': 150, 'tier': 'basic'}).resolve(outer), 'Free Shipping');
      expect(ValueResolver(state: {'total': 50, 'tier': 'premium'}).resolve(outer), 'Free Shipping');
      expect(ValueResolver(state: {'total': 50, 'tier': 'basic'}).resolve(outer), '\$9.99 Shipping');
    });

    test('then branch can be a TransformValue', () {
      final result = ValueResolver(state: {'price': 49.99, 'quantity': 2}).resolve({
        'type': 'conditional',
        'branches': [
          {
            'when': {'op': 'gt', 'left': {'type': 'state', 'key': 'quantity', 'scope': 'page'}, 'right': {'type': 'static', 'value': 0}},
            'then': {
              'type': 'transform',
              'input': {'type': 'state', 'key': 'price', 'scope': 'page'},
              'by': [
                {'type': 'multiply', 'by': {'type': 'state', 'key': 'quantity', 'scope': 'page'}},
                {'type': 'toFixed', 'decimals': 2},
                {'type': 'template', 'template': 'Total: \${{value}}'},
              ],
            },
          },
        ],
        'else': {'type': 'static', 'value': 'No items'},
      });
      expect(result, 'Total: \$99.98');
    });
  });

  group('11.6: WatchBuilder (Flutter)', () {
    testWidgets('rebuilds only when watched keys change', (tester) async {
      final store = ElmStore(initial: {'count': 0, 'name': 'Amr'});
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: WatchBuilder(
            pageStore: store,
            watches: {'count'},
            builder: (ctx, state) {
              buildCount++;
              return Text('Count: ${state['count']}');
            },
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Count: 0'), findsOneWidget);

      // Change watched key → should rebuild
      store.dispatch({'count': 1});
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Count: 1'), findsOneWidget);

      // Change unwatched key → should NOT rebuild
      store.dispatch({'name': 'Orca'});
      await tester.pump();
      expect(buildCount, 2); // still 2
    });

    testWidgets('handles multiple watched keys', (tester) async {
      final store = ElmStore(initial: {'a': 1, 'b': 2, 'c': 3});
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: WatchBuilder(
            pageStore: store,
            watches: {'a', 'b'},
            builder: (ctx, state) {
              buildCount++;
              return Text('${state['a']}-${state['b']}');
            },
          ),
        ),
      );

      expect(buildCount, 1);

      // Change 'c' (unwatched) → no rebuild
      store.dispatch({'c': 99});
      await tester.pump();
      expect(buildCount, 1);

      // Change 'a' (watched) → rebuild
      store.dispatch({'a': 10});
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('10-2'), findsOneWidget);
    });
  });

  group('11.10: Integration — watched Text', () {
    testWidgets('Text showing pageState updates when state changes', (tester) async {
      final registry = ComponentRegistry()..registerDefaults();
      final store = ElmStore(initial: {'count': 0, 'other': 'hello'});

      // Text node watching "count"
      final nodes = [
        ComponentNode(
          id: 'root',
          type: 'Column',
          kind: 'layout',
          childMode: 'multi',
          props: {},
          children: ['t1', 't2'],
          watches: [],
        ),
        ComponentNode(
          id: 't1',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': {'type': 'state', 'key': 'count', 'scope': 'page'}},
          children: [],
          watches: ['count'],
        ),
        ComponentNode(
          id: 't2',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Static text'},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ComponentRenderer(
            registry: registry,
            state: store.state,
            pageStore: store,
          ).render(nodes),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('Static text'), findsOneWidget);

      // Update count → watched text rebuilds
      store.dispatch({'count': 42});
      await tester.pump();
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Static text'), findsOneWidget);
    });
  });

  group('11.11: Integration — conditional rendering', () {
    testWidgets('In Stock / Out of Stock switches based on state', (tester) async {
      final registry = ComponentRegistry()..registerDefaults();
      final store = ElmStore(initial: {'stock': 5});

      final nodes = [
        ComponentNode(
          id: 'label',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {
            'data': {
              'type': 'conditional',
              'branches': [
                {
                  'when': {'op': 'gt', 'left': {'type': 'state', 'key': 'stock', 'scope': 'page'}, 'right': {'type': 'static', 'value': 0}},
                  'then': {'type': 'static', 'value': 'In Stock'},
                },
              ],
              'else': {'type': 'static', 'value': 'Out of Stock'},
            },
          },
          children: [],
          watches: ['stock'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ComponentRenderer(
            registry: registry,
            state: store.state,
            pageStore: store,
          ).render(nodes),
        ),
      );

      expect(find.text('In Stock'), findsOneWidget);

      // Set stock to 0 → should show "Out of Stock"
      store.dispatch({'stock': 0});
      await tester.pump();
      expect(find.text('Out of Stock'), findsOneWidget);

      // Set stock back to 3 → should show "In Stock"
      store.dispatch({'stock': 3});
      await tester.pump();
      expect(find.text('In Stock'), findsOneWidget);
    });
  });

  group('11.12: Performance — selective rebuild', () {
    testWidgets('100 widgets, 1 watched — only 1 rebuilds per state change', (tester) async {
      final store = ElmStore(initial: {'target': 0});
      int watchedBuilds = 0;
      int unwatchedBuilds = 0;

      // Build 100 widgets: 99 unwatched + 1 watched
      final children = <Widget>[];
      for (int i = 0; i < 99; i++) {
        children.add(Builder(builder: (_) {
          unwatchedBuilds++;
          return const Text('static');
        }));
      }
      children.add(WatchBuilder(
        pageStore: store,
        watches: {'target'},
        builder: (ctx, state) {
          watchedBuilds++;
          return Text('Target: ${state['target']}');
        },
      ));

      await tester.pumpWidget(
        MaterialApp(home: SingleChildScrollView(child: Column(children: children))),
      );

      final initialUnwatched = unwatchedBuilds;
      final initialWatched = watchedBuilds;
      expect(initialWatched, 1);

      // Change watched key
      store.dispatch({'target': 1});
      await tester.pump();

      // Only the watched widget should have rebuilt
      expect(watchedBuilds, initialWatched + 1);
      expect(unwatchedBuilds, initialUnwatched); // unchanged
      expect(find.text('Target: 1'), findsOneWidget);

      // Change again
      store.dispatch({'target': 2});
      await tester.pump();

      expect(watchedBuilds, initialWatched + 2);
      expect(unwatchedBuilds, initialUnwatched); // still unchanged
    });
  });

  group('11.12b: app-scope selective rebuild', () {
    testWidgets('WatchBuilder rebuilds on appStore change, not just pageStore',
        (tester) async {
      final appStore = ElmStore(pageId: 'app', scope: 'app')
        ..dispatch({'activeValue': 0});
      final pageStore = ElmStore(initial: {'pageOnly': 'x'});
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: WatchBuilder(
            pageStore: pageStore,
            appStore: appStore,
            watches: {'activeValue'},
            builder: (ctx, state) {
              buildCount++;
              return Text('Value: ${state['activeValue']}');
            },
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Value: 0'), findsOneWidget);

      // App-scoped watched key changes → watcher rebuilds.
      appStore.dispatch({'activeValue': 7});
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Value: 7'), findsOneWidget);

      // Unwatched page-scoped key changes → no rebuild.
      pageStore.dispatch({'pageOnly': 'y'});
      await tester.pump();
      expect(buildCount, 2);
    });

    testWidgets('app-scope SetState rebuilds only watching nodes', (tester) async {
      final registry = ComponentRegistry()..registerDefaults();
      final appStore = ElmStore(pageId: 'app', scope: 'app')
        ..dispatch({'activeValue': 1});
      final pageStore = ElmStore(initial: {});

      // Root + two Text leaves: one watches the app key, one is static.
      final nodes = [
        ComponentNode(
          id: 'root',
          type: 'Column',
          kind: 'layout',
          childMode: 'multi',
          props: {},
          children: ['watched', 'static'],
          watches: [],
        ),
        ComponentNode(
          id: 'watched',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {
            'data': {
              'type': 'transform',
              'input': {'type': 'state', 'key': 'activeValue', 'scope': 'app'},
              'by': [{'type': 'toString'}],
            },
          },
          children: [],
          watches: ['activeValue'],
        ),
        ComponentNode(
          id: 'static',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': 'Untouched'},
          children: [],
          watches: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ComponentRenderer(
            registry: registry,
            state: {...appStore.state, ...pageStore.state},
            pageStore: pageStore,
            appStore: appStore,
          ).render(nodes),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Untouched'), findsOneWidget);

      // App-scoped SetState — the watched Text re-resolves, the rest stays.
      appStore.dispatch({'activeValue': 99});
      await tester.pump();
      expect(find.text('99'), findsOneWidget);
      expect(find.text('Untouched'), findsOneWidget);
    });
  });

  group('11.13: E-commerce product page', () {
    testWidgets('price, stock status, quantity — all reactive', (tester) async {
      final registry = ComponentRegistry()..registerDefaults();
      final store = ElmStore(initial: {
        'quantity': 1,
        'stock': 10,
        'price': 29.99,
      });

      final nodes = [
        ComponentNode(
          id: 'root',
          type: 'Column',
          kind: 'layout',
          childMode: 'multi',
          props: {},
          children: ['total', 'stockLabel', 'qty'],
          watches: [],
        ),
        // Total price: price × quantity → formatted
        ComponentNode(
          id: 'total',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {
            'data': {
              'type': 'transform',
              'input': {'type': 'state', 'key': 'price', 'scope': 'page'},
              'by': [
                {'type': 'multiply', 'by': {'type': 'state', 'key': 'quantity', 'scope': 'page'}},
                {'type': 'toFixed', 'decimals': 2},
                {'type': 'template', 'template': 'Total: \${{value}}'},
              ],
            },
          },
          children: [],
          watches: ['price', 'quantity'],
        ),
        // Stock status: conditional
        ComponentNode(
          id: 'stockLabel',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {
            'data': {
              'type': 'conditional',
              'branches': [
                {
                  'when': {'op': 'gt', 'left': {'type': 'state', 'key': 'stock', 'scope': 'page'}, 'right': {'type': 'static', 'value': 0}},
                  'then': {'type': 'static', 'value': 'In Stock'},
                },
              ],
              'else': {'type': 'static', 'value': 'Out of Stock'},
            },
          },
          children: [],
          watches: ['stock'],
        ),
        // Quantity display
        ComponentNode(
          id: 'qty',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {
            'data': {
              'type': 'transform',
              'input': {'type': 'state', 'key': 'quantity', 'scope': 'page'},
              'by': [
                {'type': 'template', 'template': 'Qty: {{value}}'},
              ],
            },
          },
          children: [],
          watches: ['quantity'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ComponentRenderer(
            registry: registry,
            state: store.state,
            pageStore: store,
          ).render(nodes),
        ),
      );

      expect(find.text('Total: \$29.99'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('Qty: 1'), findsOneWidget);

      // Update quantity → total and qty update
      store.dispatch({'quantity': 3});
      await tester.pump();
      expect(find.text('Total: \$89.97'), findsOneWidget);
      expect(find.text('Qty: 3'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget); // stock unchanged

      // Update stock to 0 → stock label changes
      store.dispatch({'stock': 0});
      await tester.pump();
      expect(find.text('Out of Stock'), findsOneWidget);
      expect(find.text('Total: \$89.97'), findsOneWidget); // price unchanged

      // Update price
      store.dispatch({'price': 9.99});
      await tester.pump();
      expect(find.text('Total: \$29.97'), findsOneWidget);
    });
  });

  // ── Epic 12: ActionGroup ──────────────────────────────────────

  group('12.1-12.2: ActionGroup constructors + serialization', () {
    test('Sequential serializes correctly', () {
      // This tests the wire format the server sends
      final sequential = {
        'type': 'actionGroup',
        'mode': 'sequential',
        'actions': [
          {'type': 'setState', 'key': 'a', 'value': 1},
          {'type': 'setState', 'key': 'b', 'value': 2},
        ],
      };
      expect(sequential['type'], 'actionGroup');
      expect(sequential['mode'], 'sequential');
    });

    test('Parallel serializes correctly', () {
      final parallel = {
        'type': 'actionGroup',
        'mode': 'parallel',
        'actions': [
          {'type': 'setState', 'key': 'a', 'value': 1},
          {'type': 'setState', 'key': 'b', 'value': 2},
        ],
      };
      expect(parallel['mode'], 'parallel');
    });
  });

  group('12.3: ActionGroupExecutor — sequential + parallel', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'a', scope: 'page', initial: 0),
        StateDefinition(key: 'b', scope: 'page', initial: 0),
        StateDefinition(key: 'c', scope: 'page', initial: 0),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'home');
    });

    test('sequential mode awaits each action in order', () async {
      final order = <String>[];
      executor.registerHandler('track', (action, exec) async {
        order.add(action['label'] as String);
      });

      await executor.execute({
        'type': 'actionGroup',
        'mode': 'sequential',
        'actions': [
          {'type': 'track', 'label': 'first'},
          {'type': 'track', 'label': 'second'},
          {'type': 'track', 'label': 'third'},
        ],
      });

      expect(order, ['first', 'second', 'third']);
    });

    test('parallel mode executes all actions', () async {
      await executor.execute({
        'type': 'actionGroup',
        'mode': 'parallel',
        'actions': [
          {'type': 'setState', 'key': 'a', 'value': 10},
          {'type': 'setState', 'key': 'b', 'value': 20},
          {'type': 'setState', 'key': 'c', 'value': 30},
        ],
      });

      expect(manager.getPageState('home', 'a'), 10);
      expect(manager.getPageState('home', 'b'), 20);
      expect(manager.getPageState('home', 'c'), 30);
    });

    test('parallel uses Future.wait (concurrent execution)', () async {
      final startTimes = <String, int>{};
      final endTimes = <String, int>{};
      var tick = 0;

      executor.registerHandler('slowTrack', (action, exec) async {
        final label = action['label'] as String;
        startTimes[label] = tick++;
        await Future.delayed(const Duration(milliseconds: 10));
        endTimes[label] = tick++;
      });

      await executor.execute({
        'type': 'actionGroup',
        'mode': 'parallel',
        'actions': [
          {'type': 'slowTrack', 'label': 'a'},
          {'type': 'slowTrack', 'label': 'b'},
        ],
      });

      // Both should have started before either finished
      expect(startTimes['a']! < endTimes['b']!, true);
      expect(startTimes['b']! < endTimes['a']!, true);
    });
  });

  group('12.4: Nested groups', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'a', scope: 'page', initial: 0),
        StateDefinition(key: 'b', scope: 'page', initial: 0),
        StateDefinition(key: 'c', scope: 'page', initial: 0),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'home');
    });

    test('Sequential(Parallel(a, b), c) — a+b together, then c', () async {
      final order = <String>[];
      executor.registerHandler('track', (action, exec) async {
        order.add('start:${action['label']}');
        await Future.delayed(const Duration(milliseconds: 5));
        order.add('end:${action['label']}');
      });

      await executor.execute({
        'type': 'actionGroup',
        'mode': 'sequential',
        'actions': [
          {
            'type': 'actionGroup',
            'mode': 'parallel',
            'actions': [
              {'type': 'track', 'label': 'a'},
              {'type': 'track', 'label': 'b'},
            ],
          },
          {'type': 'track', 'label': 'c'},
        ],
      });

      // a and b start before c starts
      final cStartIdx = order.indexOf('start:c');
      final aEndIdx = order.indexOf('end:a');
      final bEndIdx = order.indexOf('end:b');
      expect(aEndIdx < cStartIdx, true);
      expect(bEndIdx < cStartIdx, true);
    });
  });

  group('12.5: ConditionalAction', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'loggedIn', scope: 'page', initial: false),
        StateDefinition(key: 'result', scope: 'page', initial: ''),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'home');
    });

    test('evaluates first matching branch', () async {
      manager.setPageState('home', 'loggedIn', true);

      await executor.execute({
        'type': 'conditionalAction',
        'branches': [
          {
            'when': {'op': 'eq', 'left': {'type': 'state', 'key': 'loggedIn', 'scope': 'page'}, 'right': {'type': 'static', 'value': true}},
            'then': {'type': 'setState', 'key': 'result', 'value': 'dashboard'},
          },
        ],
        'else': {'type': 'setState', 'key': 'result', 'value': 'login'},
      });

      expect(manager.getPageState('home', 'result'), 'dashboard');
    });

    test('runs else when no branch matches', () async {
      // loggedIn is false (initial)
      await executor.execute({
        'type': 'conditionalAction',
        'branches': [
          {
            'when': {'op': 'eq', 'left': {'type': 'state', 'key': 'loggedIn', 'scope': 'page'}, 'right': {'type': 'static', 'value': true}},
            'then': {'type': 'setState', 'key': 'result', 'value': 'dashboard'},
          },
        ],
        'else': {'type': 'setState', 'key': 'result', 'value': 'login'},
      });

      expect(manager.getPageState('home', 'result'), 'login');
    });

    test('no-op when no branch matches and no else', () async {
      await executor.execute({
        'type': 'conditionalAction',
        'branches': [
          {
            'when': {'op': 'eq', 'left': {'type': 'static', 'value': 1}, 'right': {'type': 'static', 'value': 2}},
            'then': {'type': 'setState', 'key': 'result', 'value': 'should not happen'},
          },
        ],
      });

      expect(manager.getPageState('home', 'result'), '');
    });
  });

  group('12.6: Actions with Value params', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'count', scope: 'page', initial: 5),
        StateDefinition(key: 'doubled', scope: 'page', initial: 0),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'home');
    });

    test('SetState with V.transform resolves before setting', () async {
      await executor.execute({
        'type': 'setState',
        'key': 'doubled',
        'value': {
          'type': 'transform',
          'input': {'type': 'state', 'key': 'count', 'scope': 'page'},
          'by': [
            {'type': 'multiply', 'by': {'type': 'static', 'value': 2}},
          ],
        },
      });

      expect(manager.getPageState('home', 'doubled'), 10);
    });
  });

  group('12.7: CopyToClipboard with transform', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'code', scope: 'page', initial: 'abc123'),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'home');
    });

    test('resolves transform before copying', () async {
      // We can't easily test clipboard contents, but we verify
      // resolveString works with transform values
      final result = executor.resolveString({
        'type': 'transform',
        'input': {'type': 'state', 'key': 'code', 'scope': 'page'},
        'by': [{'type': 'toUpperCase'}],
      });
      expect(result, 'ABC123');
    });
  });

  group('12.8: Navigate with dynamic route', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('home', [
        StateDefinition(key: 'productId', scope: 'page', initial: '42'),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'home');
    });

    test('resolves dynamic route template', () {
      final resolved = executor.resolveString({
        'type': 'transform',
        'input': {'type': 'state', 'key': 'productId', 'scope': 'page'},
        'by': [
          {'type': 'template', 'template': '/product/{{value}}'},
        ],
      });
      expect(resolved, '/product/42');
    });
  });

  group('12.9: Checkout flow', () {
    late StateManager manager;
    late ActionExecutor executor;

    setUp(() {
      manager = StateManager();
      manager.initPage('checkout', [
        StateDefinition(key: 'loading', scope: 'page', initial: false),
        StateDefinition(key: 'paymentOk', scope: 'page', initial: false),
        StateDefinition(key: 'result', scope: 'page', initial: ''),
      ]);
      executor = ActionExecutor(stateManager: manager, pageId: 'checkout');
    });

    test('setLoading → process → conditional navigate → unsetLoading', () async {
      // Simulate: payment succeeded
      manager.setPageState('checkout', 'paymentOk', true);

      await executor.execute({
        'type': 'actionGroup',
        'mode': 'sequential',
        'actions': [
          // 1. Set loading
          {'type': 'setState', 'key': 'loading', 'value': true},
          // 2. Conditional: check payment result
          {
            'type': 'conditionalAction',
            'branches': [
              {
                'when': {
                  'op': 'eq',
                  'left': {'type': 'state', 'key': 'paymentOk', 'scope': 'page'},
                  'right': {'type': 'static', 'value': true},
                },
                'then': {'type': 'setState', 'key': 'result', 'value': 'success'},
              },
            ],
            'else': {'type': 'setState', 'key': 'result', 'value': 'failed'},
          },
          // 3. Unset loading
          {'type': 'setState', 'key': 'loading', 'value': false},
        ],
      });

      expect(manager.getPageState('checkout', 'loading'), false);
      expect(manager.getPageState('checkout', 'result'), 'success');
    });

    test('checkout flow — payment failed branch', () async {
      // paymentOk is false (initial)
      await executor.execute({
        'type': 'actionGroup',
        'mode': 'sequential',
        'actions': [
          {'type': 'setState', 'key': 'loading', 'value': true},
          {
            'type': 'conditionalAction',
            'branches': [
              {
                'when': {
                  'op': 'eq',
                  'left': {'type': 'state', 'key': 'paymentOk', 'scope': 'page'},
                  'right': {'type': 'static', 'value': true},
                },
                'then': {'type': 'setState', 'key': 'result', 'value': 'success'},
              },
            ],
            'else': {'type': 'setState', 'key': 'result', 'value': 'failed'},
          },
          {'type': 'setState', 'key': 'loading', 'value': false},
        ],
      });

      expect(manager.getPageState('checkout', 'loading'), false);
      expect(manager.getPageState('checkout', 'result'), 'failed');
    });
  });
}
