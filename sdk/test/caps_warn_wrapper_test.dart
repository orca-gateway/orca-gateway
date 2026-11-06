// Warn fallback wrapper (Epic 25b, task 25b.3; found in Epic 23b S4).
//
// Under the `warn` policy the engine wraps the page as
// Column(stretch)[FallbackPrompt `__caps_warn_banner__`, page root] under the
// reserved id `__caps_warn_root__` (engine/src/core/capability-filter.ts,
// pinned by schema/fixtures/render/13_caps_warn_banner.json). The page root
// is usually a Scaffold, which threw "RenderCustomMultiChildLayoutBox object
// was given an infinite size" inside the Column's unbounded height.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

/// `components` of the `degrade` page of examples/server/capability-demo,
/// served under ORCA_FALLBACK_POLICY=warn to a client whose caps lack
/// Checkbox (recorded as sdk-swift/Tests/Pages/degrade-warn.json).
const _degradeWarn = '''
[
  {"id": "__caps_warn_root__", "type": "Column", "kind": "layout", "childMode": "multi",
   "props": {"mainAxisAlignment": "start", "crossAxisAlignment": "stretch"},
   "children": ["__caps_warn_banner__", "0"], "watches": []},
  {"id": "__caps_warn_banner__", "type": "FallbackPrompt", "kind": "primitive", "childMode": "none",
   "props": {"title": "Some content needs an update",
             "body": "Parts of this screen use features that your current app version can't fully render (widget.Checkbox). Please update when convenient for the full experience.",
             "severity": "warn"},
   "children": [], "watches": []},
  {"id": "0", "type": "Scaffold", "kind": "structure", "childMode": "none",
   "props": {"appBar": "1", "body": "3"}, "children": ["1", "3"], "watches": []},
  {"id": "3", "type": "Padding", "kind": "layout", "childMode": "single",
   "props": {"padding": {"top": 16, "right": 16, "bottom": 16, "left": 16}},
   "children": ["4"], "watches": []},
  {"id": "4", "type": "Column", "kind": "layout", "childMode": "multi",
   "props": {"crossAxisAlignment": "stretch"}, "children": ["5", "6", "7"], "watches": []},
  {"id": "7", "type": "Text", "kind": "primitive", "childMode": "none",
   "props": {"data": "Below the checkbox."}, "children": [], "watches": []},
  {"id": "6", "type": "Checkbox", "kind": "input", "childMode": "none",
   "props": {"value": true, "label": "Only some SDKs draw this"}, "children": [], "watches": []},
  {"id": "5", "type": "Text", "kind": "primitive", "childMode": "none",
   "props": {"data": "Above the checkbox."}, "children": [], "watches": []},
  {"id": "1", "type": "AppBar", "kind": "structure", "childMode": "none",
   "props": {"centerTitle": true, "title": "2"}, "children": ["2"], "watches": []},
  {"id": "2", "type": "Text", "kind": "primitive", "childMode": "none",
   "props": {"data": "Degrade"}, "children": [], "watches": []}
]
''';

List<ComponentNode> _nodes(String json) => (jsonDecode(json) as List)
    .map((n) => ComponentNode.fromJson(n as Map<String, dynamic>))
    .toList();

/// The degrade-warn wrapper around a different page root.
List<ComponentNode> _wrapping(Map<String, dynamic> root,
    [List<Map<String, dynamic>> rest = const []]) {
  final all = jsonDecode(_degradeWarn) as List;
  final wrapper = Map<String, dynamic>.from(all[0] as Map)
    ..['children'] = ['__caps_warn_banner__', root['id']];
  return [wrapper, all[1], root, ...rest]
      .map((n) => ComponentNode.fromJson(Map<String, dynamic>.from(n as Map)))
      .toList();
}

Map<String, dynamic> _text(String id, String data) => {
      'id': id,
      'type': 'Text',
      'kind': 'primitive',
      'childMode': 'none',
      'props': {'data': data},
      'children': <String>[],
      'watches': <String>[],
    };

void main() {
  late ComponentRenderer renderer;

  setUp(() {
    final registry = ComponentRegistry()..registerDefaults();
    renderer = ComponentRenderer(registry: registry);
  });

  final banner = find.text('Some content needs an update');

  testWidgets('draws the banner above a Scaffold page without throwing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: renderer.render(_nodes(_degradeWarn))),
    );

    expect(tester.takeException(), isNull);
    expect(banner, findsOneWidget);
    expect(find.text('Degrade'), findsOneWidget);
    expect(find.text('Above the checkbox.'), findsOneWidget);
    expect(find.text('Below the checkbox.'), findsOneWidget);

    // The Scaffold takes the height left under the banner.
    final screen = tester.getSize(find.byType(MaterialApp));
    final scaffold = tester.getRect(find.byType(Scaffold));
    final bannerBox = tester.getRect(
      find.ancestor(of: banner, matching: find.byType(Container)).first,
    );
    expect(bannerBox.top, 0);
    expect(scaffold.top, bannerBox.bottom);
    expect(scaffold.bottom, screen.height);
    expect(scaffold.width, screen.width);
  });

  testWidgets('the banner, not the AppBar below it, takes the top inset',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: MaterialApp(home: renderer.render(_nodes(_degradeWarn))),
      ),
    );

    expect(tester.takeException(), isNull);
    final bannerBox = tester.getRect(
      find.ancestor(of: banner, matching: find.byType(Container)).first,
    );
    expect(bannerBox.top, 47, reason: 'banner sits under the status bar');
    final appBar = tester.getRect(find.byType(AppBar));
    expect(appBar.top, bannerBox.bottom);
    expect(appBar.height, 56, reason: 'no second status-bar gap');
  });

  testWidgets('a scrolling page root gets the height left under the banner',
      (tester) async {
    final nodes = _wrapping({
      'id': 'list',
      'type': 'ListView',
      'kind': 'structure',
      'childMode': 'multi',
      'props': <String, dynamic>{},
      'children': ['a'],
      'watches': <String>[],
    }, [
      _text('a', 'row a'),
    ]);
    await tester.pumpWidget(MaterialApp(home: renderer.render(nodes)));

    expect(tester.takeException(), isNull);
    expect(find.text('row a'), findsOneWidget);
  });

  testWidgets('an inline page in unbounded height keeps its own size',
      (tester) async {
    final nodes = _wrapping(_text('t', 'inline page'));
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(child: renderer.render(nodes)),
      ),
    );

    expect(tester.takeException(), isNull);
    final text = tester.getRect(find.text('inline page'));
    expect(text.height, lessThan(100));
  });
}
