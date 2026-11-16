// ReorderableListView builder (sdk/lib/src/builders/layout_builders.dart).
//
// The builder draws the node's children in the order sent, and a drop fires
// `onReorder` with event data {oldIndex, newIndex}. newIndex is Flutter's raw
// value: the insertion index before the dragged item is removed, so the first
// row dropped below the second gives 2. The builder never reorders locally;
// only an action that changes state or the tree moves a row. Wire shape:
// schema/fixtures/render/68_reorderable_list_view.json.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

const _labels = ['Alpha', 'Bravo', 'Charlie'];
const _rowHeight = 48.0;

Map<String, dynamic> _event(String key) => {'type': 'event', 'key': key};

List<ComponentNode> _page() => [
      ComponentNode(
        id: 'rows',
        type: 'ReorderableListView',
        kind: 'layout',
        childMode: 'multi',
        props: const {
          'padding': {'top': 8, 'right': 16, 'bottom': 8, 'left': 16},
        },
        children: [for (final l in _labels) 'row_$l'],
        watches: const <String>[],
        actions: {
          'onReorder': {
            'type': 'serverAction',
            'id': 'moveRow',
            'params': {
              'oldIndex': _event('oldIndex'),
              'newIndex': _event('newIndex'),
            },
          },
        },
      ),
      for (final l in _labels) ...[
        ComponentNode(
          id: 'row_$l',
          type: 'SizedBox',
          kind: 'layout',
          childMode: 'single',
          props: const {'height': _rowHeight},
          children: ['text_$l'],
          watches: const <String>[],
        ),
        ComponentNode(
          id: 'text_$l',
          type: 'Text',
          kind: 'primitive',
          childMode: 'none',
          props: {'data': l},
          children: const <String>[],
          watches: const <String>[],
        ),
      ],
    ];

Future<List<ActionEffect>> _pump(WidgetTester tester) async {
  final effects = <ActionEffect>[];
  final executor = ActionExecutor(
    stateManager: StateManager(),
    pageId: 'p',
    onEffect: effects.add,
  );
  final renderer = ComponentRenderer(
    registry: ComponentRegistry()..registerDefaults(),
    actionExecutor: executor,
  );
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: renderer.render(_page()))),
  );
  return effects;
}

List<String> _drawnOrder(WidgetTester tester) {
  final sorted = [..._labels]..sort((a, b) =>
      tester.getTopLeft(find.text(a)).dy.compareTo(tester.getTopLeft(find.text(b)).dy));
  return sorted;
}

/// Long-press the row `label`, drag it by `dy` and drop it.
Future<void> _drag(WidgetTester tester, String label, double dy) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text(label)));
  await tester.pump(const Duration(milliseconds: 600));
  const steps = 8;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('B13.3-F draws the children in the order sent, inside the padding',
      (tester) async {
    await _pump(tester);
    expect(_drawnOrder(tester), _labels);
    expect(tester.getTopLeft(find.text('Alpha')).dx, greaterThanOrEqualTo(16));
    expect(
      tester.widget<ReorderableListView>(find.byType(ReorderableListView)).padding,
      const EdgeInsets.fromLTRB(16, 8, 16, 8),
    );
  });

  testWidgets(
      'B13.3-F a drop fires onReorder with the raw newIndex and does not reorder locally',
      (tester) async {
    final effects = await _pump(tester);

    // The first row dropped below the second: raw newIndex 2, not 1.
    await _drag(tester, 'Alpha', _rowHeight * 1.25);
    expect(effects.map((e) => e.toJson()).toList(), [
      {
        'type': 'serverAction',
        'id': 'moveRow',
        'params': {'oldIndex': 0, 'newIndex': 2},
      },
    ]);
    // No action changed the tree, so the row is back where the page has it.
    expect(_drawnOrder(tester), _labels);

    // The last row dropped above the first: moving up, newIndex is the target.
    effects.clear();
    await _drag(tester, 'Charlie', -_rowHeight * 2.25);
    expect(effects.single.toJson()['params'], {'oldIndex': 2, 'newIndex': 0});
    expect(_drawnOrder(tester), _labels);
  });

  testWidgets('B13.3-F a drop that leaves the row where it was fires nothing',
      (tester) async {
    final effects = await _pump(tester);
    await _drag(tester, 'Bravo', 4);
    expect(effects, isEmpty);
    expect(_drawnOrder(tester), _labels);
  });
}
