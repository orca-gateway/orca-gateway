// Regression tests for the 0.3.1 fixes:
//
//   1. CircularProgressIndicator honours `value` and `strokeWidth` (it used to
//      paint the same fixed arc whatever the props said).
//   2. closeDialog pops exactly one sheet and never the page underneath, so a
//      double tap (two queued closeDialogs) or a stray closeDialog can no
//      longer pop the last page.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

ComponentNode _progress(Map<String, dynamic> props) => ComponentNode(
      id: 'root',
      type: 'CircularProgressIndicator',
      kind: 'primitive',
      childMode: 'none',
      props: props,
      children: const <String>[],
      watches: const <String>[],
    );

Future<CustomPainter> _pumpProgress(WidgetTester tester, Map<String, dynamic> props) async {
  final renderer = ComponentRenderer(registry: ComponentRegistry()..registerDefaults());
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: renderer.render([_progress(props)])),
    ),
  );
  return tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!;
}

void _paintOnce(CustomPainter painter) {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Size(36, 36));
  recorder.endRecording().dispose();
}

void main() {
  group('CircularProgressIndicator', () {
    testWidgets('value changes what is painted', (tester) async {
      final half = await _pumpProgress(tester, {'value': 0.5, 'color': '#14B8C9'});
      final full = await _pumpProgress(tester, {'value': 1.0, 'color': '#14B8C9'});
      expect(full.shouldRepaint(half), isTrue);
      _paintOnce(half);
      _paintOnce(full);
    });

    testWidgets('value is clamped to 0..1', (tester) async {
      final over = await _pumpProgress(tester, {'value': 1.7});
      final one = await _pumpProgress(tester, {'value': 1});
      expect(one.shouldRepaint(over), isFalse);
      final under = await _pumpProgress(tester, {'value': -3});
      final zero = await _pumpProgress(tester, {'value': 0});
      expect(zero.shouldRepaint(under), isFalse);
      _paintOnce(zero);
    });

    testWidgets('strokeWidth is honoured', (tester) async {
      final thin = await _pumpProgress(tester, {'value': 0.3, 'strokeWidth': 2});
      final thick = await _pumpProgress(tester, {'value': 0.3, 'strokeWidth': 8});
      expect(thick.shouldRepaint(thin), isTrue);
    });

    testWidgets('without value it stays the indeterminate arc', (tester) async {
      final a = await _pumpProgress(tester, {});
      final b = await _pumpProgress(tester, {});
      expect(b.shouldRepaint(a), isFalse);
      _paintOnce(a);
    });
  });

  group('closeDialog', () {
    Future<ActionExecutor> pumpPage(WidgetTester tester) async {
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              pageContext = ctx;
              return const Scaffold(body: Text('page'));
            },
          ),
        ),
      );
      return ActionExecutor(context: pageContext, stateManager: StateManager(), pageId: 'p');
    }

    testWidgets('closes the open sheet', (tester) async {
      final exec = await pumpPage(tester);
      showModalBottomSheet<void>(context: exec.context!, builder: (_) => const SizedBox(height: 200, child: Text('sheet')));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);

      await exec.execute({'type': 'closeDialog'});
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('a double tap pops one sheet, not the page', (tester) async {
      final exec = await pumpPage(tester);
      showModalBottomSheet<void>(context: exec.context!, builder: (_) => const SizedBox(height: 200, child: Text('sheet')));
      await tester.pumpAndSettle();

      await exec.execute({'type': 'closeDialog'});
      await exec.execute({'type': 'closeDialog'});
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('stacked sheets close one per closeDialog', (tester) async {
      final exec = await pumpPage(tester);
      showModalBottomSheet<void>(context: exec.context!, builder: (_) => const SizedBox(height: 300, child: Text('first')));
      await tester.pumpAndSettle();
      showModalBottomSheet<void>(context: exec.context!, builder: (_) => const SizedBox(height: 200, child: Text('second')));
      await tester.pumpAndSettle();

      await exec.execute({'type': 'closeDialog'});
      await tester.pumpAndSettle();
      expect(find.text('second'), findsNothing);
      expect(find.text('first'), findsOneWidget);

      await exec.execute({'type': 'closeDialog'});
      await tester.pumpAndSettle();
      expect(find.text('first'), findsNothing);
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('with no sheet open it is a no-op', (tester) async {
      final exec = await pumpPage(tester);
      await exec.execute({'type': 'closeDialog'});
      await tester.pumpAndSettle();
      expect(find.text('page'), findsOneWidget);
    });
  });
}
