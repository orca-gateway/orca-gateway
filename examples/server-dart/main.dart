/// Dart backend examples — mirrors the TypeScript examples at
/// open-source/examples/server/index.ts.
///
/// Run: dart run main.dart
/// Then: curl http://localhost:8080/api/v1/app/counter/page/home
import 'package:orca_engine/orca_engine.dart';

import 'counter.dart';
import 'basic_actions.dart';
import 'server_actions.dart';

void main() async {
  final apps = [counterApp, basicActionsApp, serverActionsApp];

  final engine = OrcaEngine();
  for (final app in apps) {
    engine.registerApp(app);
  }
  engine.registerMonitor(ConsoleMonitor());

  await engine.start(const EngineConfig(port: 8080));

  print('');
  print('Orca Gateway Dart Examples running on http://localhost:8080');
  print('  - counter:        /api/v1/app/counter/page/home');
  print('  - basic-actions:  /api/v1/app/basic-actions/page/home');
  print('  - server-actions: /api/v1/app/server-actions/page/shop');
}
