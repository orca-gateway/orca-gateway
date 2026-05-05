import 'package:flutter/material.dart';

import 'app.dart';
import 'models/app_settings.dart';
import 'server/connection_manager.dart';
import 'server/ws_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  final connectionManager = ConnectionManager();
  final server = DevToolsWsServer(
    connectionManager: connectionManager,
    port: settings.port,
  );
  await server.start();
  runApp(OrcaDevToolsApp(
    connectionManager: connectionManager,
    settings: settings,
    server: server,
  ));
}
