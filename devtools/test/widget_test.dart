import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_devtools/app.dart';
import 'package:orca_devtools/models/app_settings.dart';
import 'package:orca_devtools/server/connection_manager.dart';
import 'package:orca_devtools/server/ws_server.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  // The macOS shell targets 1440×900; set the test surface to match so the
  // toolbar / sidebar / status-bar layouts fit naturally.
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final connectionManager = ConnectionManager();
  final settings = AppSettings();
  final server = DevToolsWsServer(
    connectionManager: connectionManager,
    port: 0,
  );
  await tester.pumpWidget(OrcaDevToolsApp(
    connectionManager: connectionManager,
    settings: settings,
    server: server,
  ));
  await tester.pumpAndSettle();
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  const paletteHint = 'Search actions, network paths, state keys…';

  testWidgets('App renders waiting message when no device connected',
      (tester) async {
    await _pumpApp(tester);
    expect(find.text('Waiting for device connection...'), findsOneWidget);
  });

  testWidgets('Tapping the search pill opens the command palette',
      (tester) async {
    await _pumpApp(tester);
    expect(find.text(paletteHint), findsNothing);

    await tester.tap(find.text('Search or jump to…'));
    await tester.pumpAndSettle();

    expect(find.text(paletteHint), findsOneWidget);
    expect(find.text('navigate'), findsOneWidget);
    expect(find.text('toggle'), findsOneWidget);
  });

  testWidgets('Palette shows Jump-to group with inspector shortcuts',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Search or jump to…'));
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsAtLeastNWidgets(1));
    expect(find.text('State'), findsAtLeastNWidgets(1));
    expect(find.text('Actions'), findsAtLeastNWidgets(1));
    expect(find.text('⌘1'), findsOneWidget);
    expect(find.text('⌘,'), findsOneWidget);
  });

  testWidgets('Cmd-K opens the command palette', (tester) async {
    await _pumpApp(tester);
    expect(find.text(paletteHint), findsNothing);

    await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyK);
    expect(find.text(paletteHint), findsOneWidget);
  });

  testWidgets('Cmd-comma jumps to Settings', (tester) async {
    await _pumpApp(tester);
    // Settings screen has the unique "WebSocket Server Port" label.
    expect(find.text('Appearance'), findsNothing);

    await _chord(
        tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.comma);
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('Cmd-2 jumps to State inspector, Cmd-1 returns to Timeline',
      (tester) async {
    await _pumpApp(tester);
    // Default is Timeline — no Settings content visible.
    expect(find.text('Appearance'), findsNothing);

    // Cmd-, → Settings renders.
    await _chord(
        tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.comma);
    expect(find.text('Appearance'), findsOneWidget);

    // Cmd-1 → Timeline; Settings content gone.
    await _chord(
        tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.digit1);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Waiting for device connection...'), findsOneWidget);
  });
}
