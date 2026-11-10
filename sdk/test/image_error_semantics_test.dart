// An Image whose load fails is read by a screen reader as its `alt` with the
// image role, like a loaded Image is; the "!" it draws stays drawn but is
// hidden from semantics. Under flutter_test every HTTP GET answers 400, so a
// network `src` reaches the error builder without a mock.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

ComponentNode _image(Map<String, dynamic> props) => ComponentNode(
      id: 'root',
      type: 'Image',
      kind: 'primitive',
      childMode: 'none',
      props: props,
      children: const <String>[],
      watches: const <String>[],
    );

Future<void> _pumpFailedImage(
  WidgetTester tester,
  Map<String, dynamic> props,
) async {
  final renderer =
      ComponentRenderer(registry: ComponentRegistry()..registerDefaults());
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: renderer.render([_image(props)])),
    ),
  );
  // Let the network load fail and the error builder run.
  await tester.pumpAndSettle();
  expect(find.text('!'), findsOneWidget);
}

SemanticsFinder _imageNodes({String? label}) => find.semantics.byPredicate(
      (node) =>
          node.flagsCollection.isImage && (label == null || node.label == label),
    );

void main() {
  testWidgets('A1 failed Image is read as its alt with the image role',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpFailedImage(tester, {
      'src': 'https://example.com/photo.png',
      'alt': 'Photo',
      'width': 120,
      'height': 80,
    });

    expect(_imageNodes(label: 'Photo'), findsOne);
    expect(find.semantics.byLabel(RegExp('!')), findsNothing);
    expect(find.text('!'), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(120, 80));
    handle.dispose();
  });

  testWidgets('A1 failed Image with no alt keeps the image role, empty label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpFailedImage(tester, {
      'src': 'https://example.com/photo.png',
      'width': 120,
      'height': 80,
    });

    expect(_imageNodes(label: ''), findsOne);
    expect(find.semantics.byLabel(RegExp('!')), findsNothing);
    expect(find.text('!'), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(120, 80));
    handle.dispose();
  });
}
