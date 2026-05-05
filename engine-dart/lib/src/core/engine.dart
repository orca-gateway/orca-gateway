import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../types/context.dart';
import 'app.dart';
import 'cache.dart';
import 'monitor.dart';
import 'pipeline.dart';
import 'request_info.dart';
import 'server_action.dart';

/// Engine configuration.
class EngineConfig {
  final int port;
  final bool devMonitor;

  const EngineConfig({this.port = 8080, this.devMonitor = false});
}

/// The Orca Gateway SDUI Engine — Dart backend using shelf.
class OrcaEngine {
  final _apps = <String, App>{};
  HttpServer? _server;
  final _monitorEmitter = MonitorEmitter();
  CacheProvider? _cache;

  /// Register an app with the engine.
  OrcaEngine registerApp(App app) {
    _apps[app.id] = app;
    return this;
  }

  /// Register a monitor for observability.
  OrcaEngine registerMonitor(Monitor monitor) {
    _monitorEmitter.register(monitor);
    return this;
  }

  /// Start the HTTP server.
  Future<HttpServer> start([EngineConfig config = const EngineConfig()]) async {
    _cache = InMemoryCacheProvider();

    if (config.devMonitor) {
      registerMonitor(ConsoleMonitor());
    }

    final router = Router();

    // Health check
    router.get('/health', (shelf.Request req) {
      return shelf.Response.ok(
        jsonEncode({'status': 'ok', 'name': 'Orca Gateway Engine (Dart)'}),
        headers: {'content-type': 'application/json'},
      );
    });

    // App routes
    router.get('/api/v1/app/<appId>/config', _handleConfig);
    router.get('/api/v1/app/<appId>/version', _handleVersion);
    router.post('/api/v1/app/<appId>/action', _handleAction);
    router.post('/api/v1/app/<appId>/hook', _handleHook);
    router.post('/api/v1/app/<appId>/session', _handleSession);
    router.get('/api/v1/app/<appId>/page/<path|.*>', _handlePage);
    router.post('/api/v1/app/<appId>/page/<path|.*>', _handlePage);

    // 404 fallback
    router.all('/<ignored|.*>', (shelf.Request req) {
      return _jsonResponse({'error': 'Not Found'}, status: 404);
    });

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router.call);

    final port =
        int.tryParse(Platform.environment['PORT'] ?? '') ?? config.port;
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

    developer.log(
      'Orca Gateway Engine (Dart) running on http://localhost:${_server!.port}',
      name: 'orca',
    );
    return _server!;
  }

  /// Stop the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ── Route handlers ──────────────────────────────────────

  Future<shelf.Response> _handleConfig(
      shelf.Request req, String appId) async {
    final app = _apps[appId];
    if (app == null) return _appNotFound(appId);

    final requestInfo = extractRequestInfo(req, {});
    return _jsonResponse(await app.getNavConfig(requestInfo));
  }

  Future<shelf.Response> _handleVersion(
      shelf.Request req, String appId) async {
    final app = _apps[appId];
    if (app == null) return _appNotFound(appId);
    return _jsonResponse(app.getVersionInfo());
  }

  Future<shelf.Response> _handleAction(
      shelf.Request req, String appId) async {
    final app = _apps[appId];
    if (app == null) return _appNotFound(appId);

    Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _jsonResponse({'error': 'Invalid JSON body'}, status: 400);
    }

    final actionId = body['action'] as String?;
    if (actionId == null || actionId.isEmpty) {
      return _jsonResponse(
        {'error': 'Missing required field: "action"'},
        status: 400,
      );
    }

    final actionDef = app.getAction(actionId);
    if (actionDef == null) {
      return _jsonResponse(
        {'error': 'Server action "$actionId" not found'},
        status: 404,
      );
    }

    final params =
        (body['params'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    // Schema validation
    if (actionDef.schema != null) {
      final error = validateParams(params, actionDef.schema!);
      if (error != null) {
        return _jsonResponse({'error': error}, status: 400);
      }
    }

    final requestInfo = extractRequestInfo(req, {});
    final context = ActionContext(
      requestInfo: requestInfo,
      pageState: (body['pageState'] as Map<String, dynamic>?) ?? {},
      appState: (body['appState'] as Map<String, dynamic>?) ?? {},
      actionParams: params,
    );

    try {
      final responseActions = await actionDef.execute(context);
      final wireActions = resolveResponseActions(responseActions);
      _monitorEmitter.emit('onServerActionCall', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'actionId': actionId,
        'success': true,
      });
      return _jsonResponse({'actions': wireActions});
    } catch (e) {
      developer.log(
        'Error executing server action "$actionId": $e',
        name: 'orca',
        level: 1000,
      );
      _monitorEmitter.emit('onError', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'error': '$e',
        'stage': 'serverAction',
      });
      return _jsonResponse({
        'error': 'Server action failed',
        'actions': [
          {'type': 'showSnackbar', 'message': '$e'},
        ],
      }, status: 500);
    }
  }

  Future<shelf.Response> _handleHook(
      shelf.Request req, String appId) async {
    final app = _apps[appId];
    if (app == null) return _appNotFound(appId);

    Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _jsonResponse({'error': 'Invalid JSON body'}, status: 400);
    }

    final hookType = body['type'] as String?;
    final path = body['path'] as String?;
    if (hookType == null || path == null) {
      return _jsonResponse(
        {'error': 'Missing required fields: "type" and "path"'},
        status: 400,
      );
    }

    if (hookType != 'enter' && hookType != 'exit') {
      return _jsonResponse(
        {'error': 'Hook type must be "enter" or "exit"'},
        status: 400,
      );
    }

    final routeMatch = app.resolve(path);
    if (routeMatch == null) return _jsonResponse({'ok': true});

    final hook = hookType == 'enter'
        ? routeMatch.hooks?.onEnter
        : routeMatch.hooks?.onExit;
    if (hook == null) return _jsonResponse({'ok': true});

    try {
      final requestInfo = extractRequestInfo(req, routeMatch.params);
      final context = PageContext(
        requestInfo: requestInfo,
        pageId: routeMatch.page.id,
        routePath: '/$path',
        routeParams: routeMatch.params,
      );
      await hook(context);
      return _jsonResponse({'ok': true});
    } catch (e) {
      developer.log(
        'Error executing $hookType hook for "/$path": $e',
        name: 'orca',
        level: 1000,
      );
      return _jsonResponse({'error': 'Hook execution failed'}, status: 500);
    }
  }

  Future<shelf.Response> _handleSession(
      shelf.Request req, String appId) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _jsonResponse({'error': 'Invalid JSON body'}, status: 400);
    }

    final type = body['type'] as String?;
    if (type != 'start' && type != 'end') {
      return _jsonResponse(
        {'error': 'Session type must be "start" or "end"'},
        status: 400,
      );
    }

    final event = type == 'start' ? 'onSessionStart' : 'onSessionEnd';
    _monitorEmitter.emit(event, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'deviceId': body['deviceId'],
    });

    return _jsonResponse({'ok': true});
  }

  Future<shelf.Response> _handlePage(
      shelf.Request req, String appId, String path) async {
    final app = _apps[appId];
    if (app == null) return _appNotFound(appId);

    final routeMatch = app.resolve(path);
    if (routeMatch == null) {
      return _jsonResponse(
        {'error': 'No page found for path "/$path"'},
        status: 404,
      );
    }

    final flowStart = DateTime.now();
    _monitorEmitter.emit('onFlowStart', {
      'timestamp': flowStart.millisecondsSinceEpoch,
      'flowName': routeMatch.flowName ?? 'unknown',
      'path': '/$path',
    });

    try {
      final requestInfo = extractRequestInfo(req, routeMatch.params);

      // Read appState from body if POST
      Map<String, dynamic> appState = {};
      if (req.method == 'POST') {
        try {
          final bodyStr = await req.readAsString();
          if (bodyStr.isNotEmpty) {
            final body = jsonDecode(bodyStr) as Map<String, dynamic>;
            final allowedKeys = routeMatch.page.requiredAppState();
            if (allowedKeys.isNotEmpty && body['appState'] is Map) {
              final sent = body['appState'] as Map;
              for (final key in allowedKeys) {
                if (sent.containsKey(key)) appState[key] = sent[key];
              }
            }
          }
        } catch (_) {
          // Ignore body parse errors for page requests
        }
      }

      final context = PageContext(
        requestInfo: requestInfo,
        pageId: routeMatch.page.id,
        routePath: '/$path',
        routeParams: routeMatch.params,
        appState: appState,
      );

      final pageResponse = await runPipeline(
        routeMatch.page,
        context,
        hooks: routeMatch.hooks,
        cache: _cache,
      );

      final body = jsonEncode(pageResponse.toJson());

      _monitorEmitter.emit('onPageRender', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'pageId': routeMatch.page.id,
        'path': '/$path',
        'durationMs': DateTime.now().difference(flowStart).inMilliseconds,
      });

      // ETag support
      final etag = generateETag(body);
      final ifNoneMatch = req.headers['if-none-match'];
      if (ifNoneMatch == etag) {
        return shelf.Response.notModified(headers: {'etag': etag});
      }

      return shelf.Response.ok(
        body,
        headers: {
          'content-type': 'application/json',
          'etag': etag,
          'vary': 'Accept-Encoding',
        },
      );
    } catch (e) {
      developer.log(
        'Error rendering page "/$path": $e',
        name: 'orca',
        level: 1000,
      );
      _monitorEmitter.emit('onError', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'error': '$e',
        'path': '/$path',
        'stage': 'pipeline',
      });
      return _jsonResponse({'error': 'Internal Server Error'}, status: 500);
    } finally {
      _monitorEmitter.emit('onFlowEnd', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'flowName': routeMatch.flowName ?? 'unknown',
        'path': '/$path',
        'durationMs': DateTime.now().difference(flowStart).inMilliseconds,
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  shelf.Response _appNotFound(String appId) =>
      _jsonResponse({'error': 'App "$appId" not found'}, status: 404);
}

shelf.Response _jsonResponse(dynamic body, {int status = 200}) {
  return shelf.Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );
}
