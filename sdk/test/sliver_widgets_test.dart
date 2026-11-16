// CustomScrollView and the four sliver builders
// (sdk/lib/src/builders/structure_builders.dart).
//
// Part (a) pins what the builders draw: one Scrollable, list rows, grid cells
// with the size SliverGridDelegateWithFixedCrossAxisCount gives, the adapter's
// child, the bar's slots, and the defaults of absent props.
//
// Part (b) pins the SliverAppBar's geometry at chosen scroll offsets. The
// table `barCases` below is the reference the Swift and Kotlin cores copy as
// the cases of their `SliverAppBarGeometry` (design brief V3, V6). Wire shape:
// schema/fixtures/render/69_custom_scroll_view_slivers.json.

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:orca_gateway/orca_gateway.dart';

// ── The extents table ───────────────────────────────────────────────────────
//
// Viewport 800 x 600, toolbar height 56, content far taller than the viewport.
// A case is one bar and a sequence of rows, run in order with one finger held
// down (the direction of the drag matters to a floating bar). Each row:
//
//   _At(offset, paint, layout, box, opacity)
//
//   offset   the scroll offset the finger drags the view to
//   paint    the bar's drawn extent: how much of it is on screen
//            (SliverGeometry.paintExtent)
//   layout   how far the bar pushes the content below it: the y of the first
//            content, when that is on screen (SliverGeometry.layoutExtent).
//            It is max(0, maxExtent - offset) for every variant; smaller than
//            `paint` when the bar lies over the content (pinned, or floated
//            back in).
//   box      the height of the bar's own box (background, flexibleSpace);
//            its bottom edge sits at `paint`, so when box > paint the top of
//            the box is cut off above the viewport
//   opacity  the opacity of the toolbar row (AppBar.toolbarOpacity)
//
// `_At.released(...)` is the same reading after the finger is lifted and the
// view has settled: only a `snap` bar moves then, and the scroll offset does
// not change.

class _At {
  const _At(this.offset, this.paint, this.layout, this.box, this.opacity)
      : released = false;
  const _At.released(this.offset, this.paint, this.layout, this.box, this.opacity)
      : released = true;

  final double offset;
  final double paint;
  final double layout;
  final double box;
  final double opacity;
  final bool released;

  @override
  String toString() {
    String n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    final args = [offset, paint, layout, box, opacity].map(n).join(', ');
    return released ? '_At.released($args)' : '_At($args)';
  }
}

class _BarCase {
  const _BarCase(
    this.name, {
    this.pinned = false,
    this.floating = false,
    this.snap = false,
    this.expandedHeight,
    this.collapsedHeight,
    this.topPadding = 0,
    required this.rows,
  });

  final String name;
  final bool pinned;
  final bool floating;
  final bool snap;
  final double? expandedHeight;
  final double? collapsedHeight;
  final double topPadding;
  final List<_At> rows;
}

const barCases = <_BarCase>[
  // ── expandedHeight 200 ──
  _BarCase('neither, expanded 200', expandedHeight: 200, rows: [
    _At(0, 200, 200, 200, 1),
    _At(100, 100, 100, 100, 1),
    _At(600, 0, 0, 56, 0),
    _At(580, 0, 0, 56, 0),
  ]),
  _BarCase('pinned, expanded 200', pinned: true, expandedHeight: 200, rows: [
    _At(0, 200, 200, 200, 1),
    _At(100, 100, 100, 100, 1),
    _At(600, 56, 0, 56, 1),
    _At(580, 56, 0, 56, 1),
  ]),
  _BarCase('floating, expanded 200', floating: true, expandedHeight: 200, rows: [
    _At(0, 200, 200, 200, 1),
    _At(100, 100, 100, 100, 1),
    _At(600, 0, 0, 56, 0),
    _At(580, 20, 0, 56, 0.3571),
    _At(500, 100, 0, 100, 1),
    _At(520, 80, 0, 80, 1),
    _At.released(520, 80, 0, 80, 1),
  ]),
  _BarCase('floating + pinned, expanded 200',
      floating: true, pinned: true, expandedHeight: 200, rows: [
    _At(0, 200, 200, 200, 1),
    _At(100, 100, 100, 100, 1),
    _At(600, 56, 0, 56, 1),
    _At(580, 56, 0, 56, 1),
    _At(500, 100, 0, 100, 1),
    _At(520, 80, 0, 80, 1),
  ]),

  // ── no expandedHeight (the bar is the toolbar: 56) ──
  _BarCase('neither, no expanded', rows: [
    _At(0, 56, 56, 56, 1),
    _At(30, 26, 26, 56, 0.4643),
    _At(600, 0, 0, 56, 0),
    _At(580, 0, 0, 56, 0),
  ]),
  _BarCase('pinned, no expanded', pinned: true, rows: [
    _At(0, 56, 56, 56, 1),
    _At(30, 56, 26, 56, 1),
    _At(600, 56, 0, 56, 1),
    _At(580, 56, 0, 56, 1),
  ]),
  _BarCase('floating, no expanded', floating: true, rows: [
    _At(0, 56, 56, 56, 1),
    _At(30, 26, 26, 56, 0.4643),
    _At(600, 0, 0, 56, 0),
    _At(580, 20, 0, 56, 0.3571),
    _At(500, 56, 0, 56, 1),
    _At(520, 36, 0, 56, 0.6429),
  ]),
  _BarCase('floating + pinned, no expanded', floating: true, pinned: true, rows: [
    _At(0, 56, 56, 56, 1),
    _At(30, 56, 26, 56, 1),
    _At(600, 56, 0, 56, 1),
    _At(580, 56, 0, 56, 1),
  ]),

  // ── collapsedHeight 80 ──
  _BarCase('neither, expanded 200, collapsed 80',
      expandedHeight: 200, collapsedHeight: 80, rows: [
    _At(0, 200, 200, 200, 1),
    _At(100, 100, 100, 100, 1),
    _At(150, 50, 50, 80, 0.4643),
    _At(600, 0, 0, 80, 0),
  ]),
  _BarCase('pinned, expanded 200, collapsed 80',
      pinned: true, expandedHeight: 200, collapsedHeight: 80, rows: [
    _At(0, 200, 200, 200, 1),
    _At(100, 100, 100, 100, 1),
    _At(150, 80, 50, 80, 1),
    _At(600, 80, 0, 80, 1),
  ]),
  _BarCase('floating + pinned, expanded 200, collapsed 80',
      floating: true, pinned: true, expandedHeight: 200, collapsedHeight: 80, rows: [
    _At(0, 200, 200, 200, 1),
    _At(600, 80, 0, 80, 1),
    _At(580, 80, 0, 80, 1),
    _At(500, 100, 0, 100, 1),
  ]),
  _BarCase('pinned, no expanded, collapsed 80',
      pinned: true, collapsedHeight: 80, rows: [
    _At(0, 80, 80, 80, 1),
    _At(600, 80, 0, 80, 1),
  ]),
  _BarCase('neither, no expanded, collapsed 80', collapsedHeight: 80, rows: [
    _At(0, 80, 80, 80, 1),
    _At(30, 50, 50, 80, 0.4643),
    _At(600, 0, 0, 80, 0),
  ]),

  // ── snap (floating + snap): the bar settles when the scroll ends ──
  _BarCase('floating + snap, expanded 200',
      floating: true, snap: true, expandedHeight: 200, rows: [
    _At(0, 200, 200, 200, 1),
    _At(600, 0, 0, 56, 0),
    _At(580, 20, 0, 56, 0.3571),
    _At.released(580, 200, 0, 200, 1),
    _At(600, 180, 0, 180, 1),
    _At.released(600, 0, 0, 56, 0),
  ]),
  _BarCase('floating + pinned + snap, expanded 200',
      floating: true, pinned: true, snap: true, expandedHeight: 200, rows: [
    _At(0, 200, 200, 200, 1),
    _At(600, 56, 0, 56, 1),
    _At(580, 56, 0, 56, 1),
    _At.released(580, 200, 0, 200, 1),
    _At(600, 180, 0, 180, 1),
    _At.released(600, 56, 0, 56, 1),
  ]),

  // ── top MediaQuery padding 24 (the bar reaches under the status bar) ──
  _BarCase('neither, expanded 200, top padding 24',
      expandedHeight: 200, topPadding: 24, rows: [
    _At(0, 224, 224, 224, 1),
    _At(100, 124, 124, 124, 1),
    _At(600, 0, 0, 80, 0),
    _At(580, 0, 0, 80, 0),
  ]),
  _BarCase('pinned, expanded 200, top padding 24',
      pinned: true, expandedHeight: 200, topPadding: 24, rows: [
    _At(0, 224, 224, 224, 1),
    _At(100, 124, 124, 124, 1),
    _At(600, 80, 0, 80, 1),
    _At(580, 80, 0, 80, 1),
  ]),
  _BarCase('floating, expanded 200, top padding 24',
      floating: true, expandedHeight: 200, topPadding: 24, rows: [
    _At(0, 224, 224, 224, 1),
    _At(100, 124, 124, 124, 1),
    _At(600, 0, 0, 80, 0),
    _At(580, 20, 0, 80, 0),
    _At(500, 100, 0, 100, 1),
  ]),
  _BarCase('floating + pinned, expanded 200, top padding 24',
      floating: true, pinned: true, expandedHeight: 200, topPadding: 24, rows: [
    _At(0, 224, 224, 224, 1),
    _At(100, 124, 124, 124, 1),
    _At(600, 80, 0, 80, 1),
    _At(580, 80, 0, 80, 1),
    _At(500, 100, 0, 100, 1),
  ]),
  _BarCase('pinned, no expanded, top padding 24', pinned: true, topPadding: 24, rows: [
    _At(0, 80, 80, 80, 1),
    _At(600, 80, 0, 80, 1),
  ]),
  _BarCase('pinned, expanded 200, collapsed 80, top padding 24',
      pinned: true, expandedHeight: 200, collapsedHeight: 80, topPadding: 24, rows: [
    _At(0, 224, 224, 224, 1),
    _At(600, 104, 0, 104, 1),
  ]),
];

// ── Nodes ───────────────────────────────────────────────────────────────────

ComponentNode _node(
  String id,
  String type, {
  String kind = 'layout',
  String childMode = 'multi',
  Map<String, dynamic> props = const {},
  List<String> children = const [],
}) =>
    ComponentNode(
      id: id,
      type: type,
      kind: kind,
      childMode: childMode,
      props: props,
      children: children,
      watches: const <String>[],
    );

ComponentNode _text(String id, String data) =>
    _node(id, 'Text', kind: 'primitive', childMode: 'none', props: {'data': data});

/// A box of a fixed height holding the text `label`, ids `<id>` and `<id>_t`.
List<ComponentNode> _box(String id, String label, {double? height}) => [
      _node(id, 'SizedBox',
          childMode: 'single',
          props: {'height': ?height},
          children: ['${id}_t']),
      _text('${id}_t', label),
    ];

const _rowHeight = 50.0;
const _rowCount = 40;

/// CustomScrollView > [SliverAppBar, SliverToBoxAdapter('First'), SliverList of 40 rows].
List<ComponentNode> _barPage(Map<String, dynamic> barProps) => [
      _node('scroll', 'CustomScrollView', children: ['bar', 'adapter', 'list']),
      _node('bar', 'SliverAppBar',
          kind: 'structure',
          childMode: 'none',
          props: {...barProps, 'title': 'bar_title'},
          children: ['bar_title']),
      _text('bar_title', 'Title'),
      _node('adapter', 'SliverToBoxAdapter', childMode: 'single', children: ['first']),
      ..._box('first', 'First', height: _rowHeight),
      _node('list', 'SliverList', children: [for (var i = 0; i < _rowCount; i++) 'row$i']),
      for (var i = 0; i < _rowCount; i++) ..._box('row$i', 'Row $i', height: _rowHeight),
    ];

Future<void> _pump(
  WidgetTester tester,
  List<ComponentNode> nodes, {
  double topPadding = 0,
}) async {
  final renderer = ComponentRenderer(
    registry: ComponentRegistry()..registerDefaults(),
    actionExecutor: ActionExecutor(
      stateManager: StateManager(),
      pageId: 'p',
      onEffect: (_) {},
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(top: topPadding),
          ),
          child: Scaffold(body: renderer.render(nodes)),
        ),
      ),
    ),
  );
}

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

double _round(double v) => (v * 10000).roundToDouble() / 10000;

/// What the bar draws now, as a table row.
_At _read(WidgetTester tester, {required bool released}) {
  final sliver =
      tester.renderObject<RenderSliverPersistentHeader>(
    find.byType(SliverAppBar, skipOffstage: false),
  );
  final geometry = sliver.geometry!;
  final values = [
    _position(tester).pixels,
    geometry.paintExtent,
    geometry.layoutExtent,
    sliver.child!.size.height,
    tester.widget<AppBar>(find.byType(AppBar, skipOffstage: false)).toolbarOpacity,
  ].map(_round).toList();
  return released
      ? _At.released(values[0], values[1], values[2], values[3], values[4])
      : _At(values[0], values[1], values[2], values[3], values[4]);
}

/// Holds one finger down across the rows of a case and drags the view to a
/// scroll offset. A drag goes one way only, so a floating bar sees the same
/// deltas a real finger gives it.
class _Finger {
  _Finger(this.tester);
  final WidgetTester tester;
  TestGesture? _gesture;

  Future<void> dragTo(double offset) async {
    final position = _position(tester);
    if (position.pixels == offset) return;
    final down = offset > position.pixels; // content moves up, offset grows
    if (_gesture == null) {
      _gesture = await tester.startGesture(const Offset(400, 400));
      // Spend the touch slop without passing the target.
      await _gesture!.moveBy(Offset(0, down ? -kTouchSlop : kTouchSlop));
      await tester.pump();
    }
    final rest = position.pixels - offset;
    if (rest != 0) {
      await _gesture!.moveBy(Offset(0, rest));
      await tester.pump();
    }
  }

  Future<void> release() async {
    await _gesture?.up();
    _gesture = null;
    await tester.pumpAndSettle();
  }
}

void main() {
  // ── (a) what the builders draw ────────────────────────────────────────────

  List<ComponentNode> fullPage({Map<String, dynamic>? gridProps}) => [
        _node('scroll', 'CustomScrollView', children: ['bar', 'adapter', 'grid', 'list']),
        _node('bar', 'SliverAppBar',
            kind: 'structure',
            childMode: 'none',
            props: const {
              'pinned': true,
              'expandedHeight': 200,
              'title': 'bar_title',
              'leading': 'bar_leading',
              'flexibleSpace': 'bar_space',
              'action_0': 'bar_a0',
              'action_1': 'bar_a1',
            },
            children: ['bar_title', 'bar_leading', 'bar_space', 'bar_a0', 'bar_a1']),
        _text('bar_title', 'Title'),
        _text('bar_leading', 'Lead'),
        _node('bar_space', 'Container',
            childMode: 'single', props: const {'color': '#3949AB'}),
        _text('bar_a0', 'Act0'),
        _text('bar_a1', 'Act1'),
        _node('adapter', 'SliverToBoxAdapter', childMode: 'single', children: ['first']),
        ..._box('first', 'First', height: _rowHeight),
        _node('grid', 'SliverGrid',
            props: gridProps ??
                const {
                  'crossAxisCount': 3,
                  'mainAxisSpacing': 8,
                  'crossAxisSpacing': 4,
                  'childAspectRatio': 1.5,
                },
            children: [for (var i = 0; i < 5; i++) 'cell$i']),
        for (var i = 0; i < 5; i++) ..._box('cell$i', 'Cell $i'),
        _node('list', 'SliverList', children: [for (var i = 0; i < _rowCount; i++) 'row$i']),
        for (var i = 0; i < _rowCount; i++) ..._box('row$i', 'Row $i', height: _rowHeight),
      ];

  final space = find.byWidgetPredicate(
    (w) => w is ColoredBox && w.color == const Color(0xFF3949AB),
  );

  Rect cell(WidgetTester tester, int i) => tester.getRect(
        find.ancestor(of: find.text('Cell $i'), matching: find.byType(SizedBox)).first,
      );

  testWidgets('C-flutter one Scrollable holds the bar, the adapter, the grid and the list',
      (tester) async {
    await _pump(tester, fullPage());

    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);

    // The bar's slots.
    for (final label in ['Title', 'Lead', 'Act0', 'Act1']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(tester.getCenter(find.text('Lead')).dx,
        lessThan(tester.getCenter(find.text('Title')).dx));
    expect(tester.getCenter(find.text('Act0')).dx,
        lessThan(tester.getCenter(find.text('Act1')).dx));
    expect(tester.getCenter(find.text('Act0')).dx,
        greaterThan(tester.getCenter(find.text('Title')).dx));
    // flexibleSpace is drawn raw, filling the bar's extent.
    expect(tester.getRect(space), const Rect.fromLTWH(0, 0, 800, 200));

    // The adapter's child, right under the bar, at the cross extent.
    expect(
      tester.getRect(find.ancestor(of: find.text('First'), matching: find.byType(SizedBox)).first),
      const Rect.fromLTWH(0, 200, 800, _rowHeight),
    );

    // Grid: 3 across, crossAxisSpacing 4 -> (800 - 2 * 4) / 3 = 264 wide,
    // ratio 1.5 -> 176 high; mainAxisSpacing 8 between the two lines.
    expect(cell(tester, 0), const Rect.fromLTWH(0, 250, 264, 176));
    expect(cell(tester, 1), const Rect.fromLTWH(268, 250, 264, 176));
    expect(cell(tester, 2), const Rect.fromLTWH(536, 250, 264, 176));
    expect(cell(tester, 3), const Rect.fromLTWH(0, 434, 264, 176));
    expect(cell(tester, 4), const Rect.fromLTWH(268, 434, 264, 176));

    // The list starts right after the second grid line (no spacing after it).
    await _Finger(tester).dragTo(300);
    expect(
      tester.getRect(find.ancestor(of: find.text('Row 0'), matching: find.byType(SizedBox)).first),
      const Rect.fromLTWH(0, 250 + 176 + 8 + 176 - 300, 800, _rowHeight),
    );
    expect(
      tester.getRect(find.ancestor(of: find.text('Row 1'), matching: find.byType(SizedBox)).first),
      const Rect.fromLTWH(0, 250 + 176 + 8 + 176 - 300 + _rowHeight, 800, _rowHeight),
    );
    // The bar is pinned: collapsed to the toolbar, flexibleSpace still filling it.
    expect(tester.getRect(space), const Rect.fromLTWH(0, 0, 800, 56));
    // Rows far below the viewport are not built.
    expect(find.text('Row ${_rowCount - 1}'), findsNothing);
  });

  testWidgets('C-flutter SliverGrid defaults: 2 across, no spacing, square cells',
      (tester) async {
    await _pump(tester, fullPage(gridProps: const {}));
    expect(cell(tester, 0), const Rect.fromLTWH(0, 250, 400, 400));
    expect(cell(tester, 1), const Rect.fromLTWH(400, 250, 400, 400));
  });

  testWidgets('C-flutter CustomScrollView props and defaults; an adapter with no child draws nothing',
      (tester) async {
    await _pump(tester, [
      _node('scroll', 'CustomScrollView', children: ['empty', 'adapter']),
      _node('empty', 'SliverToBoxAdapter', childMode: 'single'),
      _node('adapter', 'SliverToBoxAdapter', childMode: 'single', children: ['first']),
      ..._box('first', 'First', height: _rowHeight),
    ]);
    var view = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(view.scrollDirection, Axis.vertical);
    expect(view.reverse, isFalse);
    expect(view.shrinkWrap, isFalse);
    expect(tester.getTopLeft(find.text('First')).dy, 0);

    await _pump(tester, [
      _node('box', 'SizedBox', childMode: 'single', props: const {'height': 100}, children: ['scroll']),
      _node('scroll', 'CustomScrollView',
          props: const {'scrollDirection': 'horizontal', 'reverse': true, 'shrinkWrap': true},
          children: ['list']),
      _node('list', 'SliverList', children: ['a', 'b']),
      _node('a', 'SizedBox', childMode: 'single', props: const {'width': 120}, children: ['a_t']),
      _text('a_t', 'A'),
      _node('b', 'SizedBox', childMode: 'single', props: const {'width': 120}, children: ['b_t']),
      _text('b_t', 'B'),
    ]);
    view = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(view.scrollDirection, Axis.horizontal);
    expect(view.reverse, isTrue);
    expect(view.shrinkWrap, isTrue);
    // Reversed: the first child sits at the right edge.
    expect(tester.getCenter(find.text('A')).dx, greaterThan(tester.getCenter(find.text('B')).dx));
  });

  testWidgets('C-flutter SliverAppBar defaults: not pinned, not floating, 56 high',
      (tester) async {
    await _pump(tester, _barPage(const {}));
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.pinned, isFalse);
    expect(bar.floating, isFalse);
    expect(bar.snap, isFalse);
    expect(bar.expandedHeight, isNull);
    expect(bar.collapsedHeight, isNull);
    expect(tester.getTopLeft(find.text('First')).dy, 56);
  });

  // ── (b) the bar's extents ─────────────────────────────────────────────────

  for (final c in barCases) {
    testWidgets('C-flutter bar extents · ${c.name}', (tester) async {
      await _pump(
        tester,
        _barPage({
          if (c.pinned) 'pinned': true,
          if (c.floating) 'floating': true,
          if (c.snap) 'snap': true,
          if (c.expandedHeight != null) 'expandedHeight': c.expandedHeight,
          if (c.collapsedHeight != null) 'collapsedHeight': c.collapsedHeight,
        }),
        topPadding: c.topPadding,
      );
      final finger = _Finger(tester);
      final got = <_At>[];
      for (final row in c.rows) {
        if (row.released) {
          await finger.release();
        } else {
          await finger.dragTo(row.offset);
        }
        got.add(_read(tester, released: row.released));

        // `layout` is where the content below the bar starts, while the
        // first content is still on screen.
        final first = find.text('First');
        if (first.evaluate().isNotEmpty) {
          final top = tester
              .getTopLeft(find.ancestor(of: first, matching: find.byType(SizedBox)).first)
              .dy;
          if (top >= 0) expect(top, got.last.layout, reason: 'content top, $row');
        }
      }
      await finger.release();
      expect(
        got.map((r) => '$r').toList(),
        c.rows.map((r) => '$r').toList(),
        reason: '${c.name} measured:\n${got.map((r) => '    $r,').join('\n')}',
      );
    });
  }
}
