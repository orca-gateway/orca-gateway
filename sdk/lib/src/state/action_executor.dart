import 'dart:convert' show jsonEncode;
import 'dart:developer' as developer;

import 'package:flutter/material.dart' show
    MaterialPageRoute,
    Navigator,
    Scaffold,
    ScaffoldMessenger,
    SnackBar,
    SnackBarBehavior;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../client/orca_client.dart';
import '../debug/orca_debug.dart';
import '../debug/debug_events.dart';
import '../models/component_node.dart';
import '../widgets/orca_nav_config.dart';
import 'animation_registry.dart';
import 'component_store.dart';
import 'state_manager.dart';
import 'value_resolver.dart';

const _safeUrlSchemes = {'http', 'https', 'tel', 'mailto', 'sms'};

bool _isSafeUrlScheme(Uri uri) => _safeUrlSchemes.contains(uri.scheme.toLowerCase());

/// Identifies where an action chain originated so dedupe wrappers like
/// `Once(...)` can key by (widgetId, trigger). Passed by `fireAction(...)`
/// and inherited by nested `execute(...)` calls inside the chain.
class ActionSource {
  final String widgetId;
  final String trigger;
  const ActionSource({required this.widgetId, required this.trigger});

  String get dedupeKey => '$widgetId::$trigger';
}

/// Signature for an action handler.
typedef ActionHandler = Future<void> Function(
    Map<String, dynamic> action, ActionExecutor executor);

/// Execute a single action or a list of actions for lifecycle callbacks.
Future<void> _execLifecycle(ActionExecutor exec, dynamic actions) async {
  if (actions == null) return;
  if (actions is Map<String, dynamic>) {
    await exec.execute(actions);
  } else if (actions is List) {
    await exec.executeAll(actions);
  }
}

/// Executes actions dispatched from component event handlers.
class ActionExecutor {
  /// BuildContext for actions that need navigation/scaffold access.
  /// Null in unit-test scenarios where only setState is exercised.
  final BuildContext? context;
  final StateManager stateManager;
  final String pageId;
  final PipeTransformRegistry? transforms;

  /// Builds a page widget for the given path (used by navigate action).
  final Widget Function(String path)? pageBuilder;

  /// HTTP client for server action calls.
  final OrcaClient? client;

  /// The app ID (needed for server action endpoint).
  final String? appId;

  /// Mutable component tree (for updateComponent / addComponent / etc.).
  final ComponentStore? componentStore;

  /// Registry for animation controllers addressable by animationId.
  final AnimationRegistry? animationRegistry;

  /// The current page path (used by refetchPage action).
  final String? pagePath;

  /// Callback to refetch the current page and update the component tree.
  final Future<void> Function()? onRefetchPage;

  /// Callback to open a dialog by its stable key.
  final Future<void> Function(String dialogId, double heightFactor)? onOpenDialog;

  final Map<String, ActionHandler> _handlers = {};
  List<Map<String, dynamic>>? _lastTransformTrace;
  List<Map<String, dynamic>>? _lastAffectedWidgets;

  /// Event data from the trigger that fired the current action chain.
  Map<String, dynamic>? _currentEventData;

  /// Source of the current action chain — widgetId + trigger name — used by
  /// `Once(...)` to dedupe. Set by `execute(action, source: ...)` at the
  /// root of a chain; nested executions inherit it.
  ActionSource? _currentSource;

  /// Keys of `Once(...)` wrappers that have already fired, in the form
  /// "widgetId::trigger". Wrappers without source context (e.g. programmatic
  /// executions not tied to a widget) are never deduped.
  final Set<String> _firedOnceKeys = <String>{};

  ActionExecutor({
    this.context,
    required this.stateManager,
    required this.pageId,
    this.transforms,
    this.pageBuilder,
    this.client,
    this.appId,
    this.componentStore,
    this.animationRegistry,
    this.pagePath,
    this.onRefetchPage,
    this.onOpenDialog,
  }) {
    _registerDefaults();
  }

  /// Register a custom action handler (or override a default).
  void registerHandler(String type, ActionHandler handler) {
    _handlers[type] = handler;
  }

  /// Execute a single action map.
  ///
  /// When [eventData] is provided, it becomes available to value resolution
  /// via `V.event("key")` expressions for the duration of this action.
  /// When [source] is provided, `Once(...)` wrappers can dedupe by
  /// (widgetId, trigger) — only `fireAction` supplies it; nested executions
  /// inherit the outer source via `_currentSource`.
  Future<void> execute(
    Map<String, dynamic> action, {
    Map<String, dynamic>? eventData,
    ActionSource? source,
  }) async {
    final type = action['type'] as String?;
    if (type == null) return;
    // Plugin actions are TS-typed as `custom:${string}` so the Action
    // discriminated union stays exhaustive. Strip that prefix at dispatch
    // time so plugins can register handlers under their bare name
    // (`moveCamera`) without knowing the wire-format detail.
    final bareType =
        type.startsWith('custom:') ? type.substring('custom:'.length) : type;
    final handler = _handlers[type] ?? _handlers[bareType];
    if (handler != null) {
      final previousEventData = _currentEventData;
      final previousSource = _currentSource;
      if (eventData != null) _currentEventData = eventData;
      if (source != null) _currentSource = source;
      final sw = OrcaDebug.isEnabled ? (Stopwatch()..start()) : null;
      _lastTransformTrace = null;
      _lastAffectedWidgets = null;
      await handler(action, this);
      if (sw != null) {
        sw.stop();
        OrcaDebug.instance?.reportAction(DebugActionEvent(
          actionType: type,
          actionData: action,
          pageId: pageId,
          durationMs: sw.elapsedMicroseconds / 1000.0,
          transformTrace: _lastTransformTrace,
          affectedWidgets: _lastAffectedWidgets,
        ));
        _lastTransformTrace = null;
        _lastAffectedWidgets = null;
      }
      _currentEventData = previousEventData;
      _currentSource = previousSource;
    }
  }

  /// Execute a list of actions sequentially, awaiting each.
  ///
  /// [eventData] is propagated to each action in the list.
  Future<void> executeAll(
    List<dynamic> actions, {
    Map<String, dynamic>? eventData,
    ActionSource? source,
  }) async {
    for (final action in actions) {
      if (action is Map<String, dynamic>) {
        await execute(action, eventData: eventData, source: source);
      }
    }
  }

  /// Resolve a dynamic value expression to a concrete value.
  dynamic resolveValue(dynamic raw) {
    final state = _mergedState();
    final resolver = ValueResolver(
      state: state,
      transforms: transforms,
      eventData: _currentEventData,
    );
    return resolver.resolve(raw);
  }

  /// Resolve a dynamic value expression to a String.
  String resolveString(dynamic raw) {
    final resolved = resolveValue(raw);
    return resolved?.toString() ?? '';
  }

  Map<String, dynamic> _mergedState() {
    return <String, dynamic>{
      ...stateManager.appStore.state,
      ...?stateManager.getPageStore(pageId)?.state,
    };
  }

  void _registerDefaults() {
    // setState
    _handlers['setState'] = (action, exec) async {
      final key = action['key'] as String;
      final scope = action['scope'] as String? ?? 'page';

      // Resolve with trace when debug is enabled and value is a transform
      List<Map<String, dynamic>>? trace;
      final dynamic resolvedValue;
      final rawValue = action['value'];
      if (OrcaDebug.isEnabled && rawValue is Map && rawValue['type'] == 'transform') {
        final state = exec._mergedState();
        final resolver = ValueResolver(state: state, transforms: exec.transforms, eventData: exec._currentEventData);
        final (value, steps) = resolver.resolveWithTrace(rawValue);
        resolvedValue = value;
        trace = steps.map((s) => s.toJson()).toList();
      } else {
        resolvedValue = exec.resolveValue(rawValue);
      }

      if (scope == 'app') {
        exec.stateManager.setAppState(key, resolvedValue);
      } else {
        exec.stateManager.setPageState(exec.pageId, key, resolvedValue);
      }

      if (OrcaDebug.isEnabled) {
        exec._lastTransformTrace = trace;
        // Find widgets that watch this key — omit props (captured in widget_rebuild events)
        final store = exec.componentStore;
        if (store != null) {
          final affected = <Map<String, dynamic>>[];
          for (final node in store.nodeMap.values) {
            if (node.watches.contains(key)) {
              affected.add({
                'id': node.id,
                'type': node.type,
                'watches': node.watches,
              });
            }
          }
          if (affected.isNotEmpty) {
            exec._lastAffectedWidgets = affected;
          }
        }
      }
    };

    // navigate — GoRouter-first with Navigator fallback
    _handlers['navigate'] = (action, exec) async {
      final ctx = exec.context;
      if (ctx == null) return;
      final path = exec.resolveString(action['route'] ?? action['path']);
      if (path.isEmpty) return;
      final replace = action['replace'] == true;

      if (GoRouter.maybeOf(ctx) != null) {
        final router = GoRouter.of(ctx);
        if (replace) {
          router.go(path);
        } else {
          router.push(path);
        }
      } else if (exec.pageBuilder != null) {
        Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => exec.pageBuilder!(path)),
        );
      }
    };

    // goBack — GoRouter-first with Navigator fallback
    _handlers['goBack'] = (action, exec) async {
      final ctx = exec.context;
      if (ctx == null) return;
      if (GoRouter.maybeOf(ctx) != null) {
        GoRouter.of(ctx).pop();
      } else {
        Navigator.of(ctx).pop();
      }
    };

    // switchTab — resolve tab's initial route and go to it
    _handlers['switchTab'] = (action, exec) async {
      final ctx = exec.context;
      if (ctx == null) return;
      final tabId = action['tabId'] as String?;
      if (tabId == null) return;
      final navConfig = OrcaNavConfig.configOf(ctx);
      if (navConfig == null) return;
      final tab = navConfig.tabs.where((t) => t.id == tabId).firstOrNull;
      if (tab == null) return;
      GoRouter.of(ctx).go(tab.initialRoute);
    };

    // openDrawer
    _handlers['openDrawer'] = (action, exec) async {
      final ctx = exec.context;
      if (ctx == null) return;
      Scaffold.of(ctx).openDrawer();
    };

    // showSnackbar
    _handlers['showSnackbar'] = (action, exec) async {
      final ctx = exec.context;
      if (ctx == null) return;
      final message = exec.resolveString(action['message']);
      final duration = action['duration'] as int? ?? 4000;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(milliseconds: duration),
        ),
      );
    };

    // showToast (floating SnackBar)
    _handlers['showToast'] = (action, exec) async {
      final ctx = exec.context;
      if (ctx == null) return;
      final message = exec.resolveString(action['message']);
      final duration = action['duration'] as int? ?? 2000;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(milliseconds: duration),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    };

    // copyToClipboard
    _handlers['copyToClipboard'] = (action, exec) async {
      final text = exec.resolveString(action['text']);
      await Clipboard.setData(ClipboardData(text: text));
    };

    // once — fire the wrapped action at most once per (widgetId, trigger).
    // Re-firing the same trigger on the same node is a no-op. When there's
    // no source context (e.g. the action was executed programmatically),
    // dedupe is disabled and the wrapped action fires every time.
    _handlers['once'] = (action, exec) async {
      final inner = action['action'];
      if (inner is! Map<String, dynamic>) return;
      final src = exec._currentSource;
      if (src != null) {
        if (exec._firedOnceKeys.contains(src.dedupeKey)) return;
        exec._firedOnceKeys.add(src.dedupeKey);
      }
      await exec.execute(inner, eventData: exec._currentEventData);
    };

    // always — fire the wrapped action unconditionally. This is a no-op
    // wrapper whose purpose is authoring clarity (pairs with `once` at the
    // call site): `onVisible: Always(DebugLog(...))` vs `Once(...)`.
    _handlers['always'] = (action, exec) async {
      final inner = action['action'];
      if (inner is! Map<String, dynamic>) return;
      await exec.execute(inner, eventData: exec._currentEventData);
    };

    // debugLog — client-side diagnostic sink. Writes a structured entry to
    // `dart:developer` (visible in DevTools) and `debugPrint` (visible in
    // the terminal). Every payload field is resolved against the current
    // state + event payload so authors can reference V.pageState /
    // V.event(...) inside message/data.
    //
    // CRITICAL INVARIANT: this handler MUST NOT throw under any condition.
    // It's typically used in Sequential(DebugLog(...), ServerAction(...))
    // — if debugLog throws, Sequential's for-loop aborts and the server
    // action never fires, which looks like a broken button to the user.
    // Every potentially-throwing operation (resolveValue on unexpected
    // shapes, jsonEncode on non-JSON-encodable state) is wrapped so the
    // sink is fire-and-forget.
    _handlers['debugLog'] = (action, exec) async {
      try {
        final level = (action['level'] as String?) ?? 'debug';
        final tag = (action['tag'] as String?) ?? 'orca';
        String? message;
        try {
          message = action['message'] != null
              ? exec.resolveString(action['message'])
              : null;
        } catch (_) {
          message = action['message']?.toString();
        }

        // data can be a single Value, a plain record, or absent.
        dynamic data;
        final rawData = action['data'];
        if (rawData is Map) {
          final resolved = <String, dynamic>{};
          rawData.forEach((k, v) {
            try {
              resolved[k.toString()] = exec.resolveValue(v);
            } catch (_) {
              resolved[k.toString()] = '<unresolvable>';
            }
          });
          data = resolved;
        } else if (rawData != null) {
          try {
            data = exec.resolveValue(rawData);
          } catch (_) {
            data = '<unresolvable>';
          }
        }

        final entry = <String, dynamic>{
          'level': level,
          'tag': tag,
          'timestamp': DateTime.now().toIso8601String(),
          'message': ?message,
          'data': ?data,
        };

        if (action['includeState'] == true) {
          final pageStore = exec.stateManager.getPageStore(exec.pageId);
          if (pageStore != null) {
            entry['pageState'] = Map<String, dynamic>.from(pageStore.state);
          }
          entry['appState'] =
              Map<String, dynamic>.from(exec.stateManager.appStore.state);
        }
        if (action['includeEvent'] == true && exec._currentEventData != null) {
          entry['event'] = Map<String, dynamic>.from(exec._currentEventData!);
        }
        // includeRequest is accepted for forward compatibility, but the SDK
        // doesn't hold RequestInfo on ActionExecutor today — skip silently
        // so authors can set the flag now and benefit once the field lands.
        if (action['includeStackTrace'] == true) {
          entry['stackTrace'] = StackTrace.current.toString();
        }

        // Mirror to both sinks so authors see the entry in DevTools AND the
        // plain terminal. level affects the `dart:developer` severity level
        // argument; debugPrint stays as a prefixed string for terminal grep.
        final severity = switch (level) {
          'error' => 1000,
          'warn' => 900,
          'info' => 800,
          _ => 700, // debug
        };
        developer.log(
          message ?? '',
          name: tag,
          level: severity,
          error: data,
          stackTrace: action['includeStackTrace'] == true
              ? StackTrace.current
              : null,
        );

        // jsonEncode can throw JsonUnsupportedObjectError when state
        // contains any non-encodable value (custom class instances,
        // cyclic maps, etc.). Fall back to a string representation so
        // debugLog's guarantee ("never abort a Sequential") holds.
        String rendered;
        try {
          rendered = jsonEncode(entry);
        } catch (_) {
          rendered = entry.toString();
        }
        debugPrint('[$level][$tag] $rendered');
      } catch (e, s) {
        // Last-resort: debugLog itself failed in an unexpected way.
        // Swallow the error but surface it via debugPrint so the author
        // can see something went wrong without crashing the action chain.
        debugPrint('[debugLog] handler failed: $e\n$s');
      }
    };

    // openUrl
    _handlers['openUrl'] = (action, exec) async {
      final urlString = exec.resolveString(action['url']);
      final uri = Uri.tryParse(urlString);
      if (uri != null && _isSafeUrlScheme(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    };

    // actionGroup — Sequential: await each. Parallel: Future.wait() all.
    _handlers['actionGroup'] = (action, exec) async {
      final actions = action['actions'] as List?;
      if (actions == null) return;
      final mode = action['mode'] as String? ?? 'sequential';

      if (mode == 'parallel') {
        await Future.wait(
          actions
              .whereType<Map<String, dynamic>>()
              .map((a) => exec.execute(a)),
        );
      } else {
        await exec.executeAll(actions);
      }
    };

    // conditionalAction — evaluate branches, run matching action
    _handlers['conditionalAction'] = (action, exec) async {
      final branches = action['branches'] as List?;
      final state = exec._mergedState();
      final resolver = ValueResolver(state: state, transforms: transforms, eventData: exec._currentEventData);

      if (branches != null) {
        for (final branch in branches) {
          if (branch is! Map) continue;
          final branchMap = branch as Map<String, dynamic>;
          final when = branchMap['when'] as Map<String, dynamic>?;
          if (when != null && resolver.evaluateBoolExpr(when)) {
            final then = branchMap['then'];
            if (then is Map<String, dynamic>) {
              await exec.execute(then);
            }
            return;
          }
        }
      }

      // No branch matched — run else action if present
      final elseAction = action['else'];
      if (elseAction is Map<String, dynamic>) {
        await exec.execute(elseAction);
      }
    };

    // lifecycle — wraps any action with onLoading/onSuccess/onError/onComplete
    _handlers['lifecycle'] = (action, exec) async {
      final innerAction = action['action'] as Map<String, dynamic>?;
      if (innerAction == null) return;

      final onLoading = action['onLoading'];
      final onSuccess = action['onSuccess'];
      final onError = action['onError'];
      final onComplete = action['onComplete'];

      await _execLifecycle(exec, onLoading);

      try {
        await exec.execute(innerAction);
        await _execLifecycle(exec, onSuccess);
      } catch (e) {
        if (onError != null) {
          await _execLifecycle(exec, onError);
        } else {
          rethrow;
        }
      } finally {
        await _execLifecycle(exec, onComplete);
      }
    };

    // share
    _handlers['share'] = (action, exec) async {
      final text = exec.resolveString(action['text'] ?? action['message']);
      final subject = exec.resolveString(action['subject'] ?? action['title']);
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject.isNotEmpty ? subject : null,
        ),
      );
    };

    // ── Server Action ──────────────────────────────────────
    _handlers['serverAction'] = (action, exec) async {
      final actionClient = exec.client;
      final actionAppId = exec.appId;
      if (actionClient == null || actionAppId == null) return;

      final id = action['id'] as String;

      // Resolve params (Value expressions → concrete values)
      final rawParams = action['params'] as Map<String, dynamic>?;
      Map<String, dynamic>? resolvedParams;
      if (rawParams != null) {
        resolvedParams = <String, dynamic>{};
        for (final entry in rawParams.entries) {
          resolvedParams[entry.key] = exec.resolveValue(entry.value);
        }
      }

      try {
        final response = await actionClient.executeAction(
          actionAppId,
          action: id,
          params: resolvedParams,
          pageState: exec.stateManager.getPageStore(exec.pageId)?.state,
          appState: exec.stateManager.appStore.state,
        );

        // Execute each response action sequentially
        await exec.executeAll(response.actions);
      } on OrcaClientException catch (e) {
        // Server returned error — show error snackbar
        await exec.execute({
          'type': 'showSnackbar',
          'message': e.message,
        });
      }
    };

    // ── Component Mutations ────────────────────────────────

    _handlers['updateComponent'] = (action, exec) async {
      final store = exec.componentStore;
      if (store == null) return;
      final id = action['id'] as String;
      final props = Map<String, dynamic>.from(action['props'] as Map);
      store.updateComponent(id, props);
    };

    _handlers['deleteComponent'] = (action, exec) async {
      final store = exec.componentStore;
      if (store == null) return;
      final id = action['id'] as String;
      store.deleteComponent(id);
    };

    _handlers['addComponent'] = (action, exec) async {
      final store = exec.componentStore;
      if (store == null) return;
      final parentId = action['parentId'] as String;
      final componentsList = action['components'] as List;
      final components = componentsList
          .map((e) => ComponentNode.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final position = action['position'] as int?;
      store.addComponent(parentId, components, position: position);
    };

    // ── Animation Debug Helper ────────────────────────────

    /// Walk a props map and return a list of dot-paths that contain
    /// tween or tweenSequence values (e.g. ["left", "style.fontSize"]).
    List<String> findTweenProps(Map<String, dynamic> props, [String prefix = '']) {
      final result = <String>[];
      for (final entry in props.entries) {
        final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        final val = entry.value;
        if (val is Map<String, dynamic>) {
          final type = val['type'];
          if (type == 'tween' || type == 'tweenSequence') {
            result.add(path);
          } else {
            result.addAll(findTweenProps(val, path));
          }
        }
      }
      return result;
    }

    List<Map<String, dynamic>>? findAnimationAffectedWidgets(
        ActionExecutor exec, String animationId) {
      final store = exec.componentStore;
      if (store == null) return null;

      // Find the AnimatedBuilder node with matching animationId prop.
      String? builderId;
      for (final node in store.nodeMap.values) {
        if (node.type == 'AnimatedBuilder' &&
            node.props['animationId'] == animationId) {
          builderId = node.id;
          break;
        }
      }
      if (builderId == null) return null;

      // Collect the builder and all its descendants, noting tween props.
      final affected = <Map<String, dynamic>>[];
      void collect(String id) {
        final node = store.nodeMap[id];
        if (node == null) return;
        final tweenProps = findTweenProps(node.props);
        final entry = <String, dynamic>{'id': node.id, 'type': node.type};
        if (tweenProps.isNotEmpty) entry['tweenProps'] = tweenProps;
        affected.add(entry);
        for (final childId in node.children) {
          collect(childId);
        }
      }
      collect(builderId);
      return affected.isNotEmpty ? affected : null;
    }

    _handlers['replaceComponent'] = (action, exec) async {
      final store = exec.componentStore;
      if (store == null) return;
      final targetId = action['targetId'] as String;
      final componentsList = action['components'] as List;
      final components = componentsList
          .map((e) => ComponentNode.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      store.replaceComponent(targetId, components);
    };

    // ── Animation Control ─────────────────────────────────

    _handlers['animateForward'] = (action, exec) async {
      final id = action['animationId'] as String?;
      if (id == null) return;
      // Reset to start so the animation replays on every trigger.
      exec.animationRegistry?.getController(id)?.forward(from: 0.0);
      if (OrcaDebug.isEnabled) {
        exec._lastAffectedWidgets = findAnimationAffectedWidgets(exec, id);
      }
    };

    _handlers['animateReverse'] = (action, exec) async {
      final id = action['animationId'] as String?;
      if (id == null) return;
      exec.animationRegistry?.getController(id)?.reverse();
      if (OrcaDebug.isEnabled) {
        exec._lastAffectedWidgets = findAnimationAffectedWidgets(exec, id);
      }
    };

    // refetchPage — re-fetches the current page from the server and replaces
    // the component tree. Used with PullToRefresh or manual refresh buttons.
    _handlers['refetchPage'] = (action, exec) async {
      if (exec.onRefetchPage != null) {
        await exec.onRefetchPage!();
      }
    };

    // openDialog — shows a Dialog node (identified by stableKey) as a
    // modal bottom sheet at the specified height factor (0.0–1.0).
    _handlers['openDialog'] = (action, exec) async {
      final dialogId = action['dialogId'] as String?;
      if (dialogId == null) return;
      final heightFactor = (action['heightFactor'] as num?)?.toDouble() ?? 0.5;
      if (exec.onOpenDialog != null) {
        await exec.onOpenDialog!(dialogId, heightFactor);
      }
    };

    // updateSubPage — fetches a new page and updates a SubPage widget's content.
    _handlers['updateSubPage'] = (action, exec) async {
      final store = exec.componentStore;
      if (store == null) return;
      final subPageId = exec.resolveString(action['subPageId']);
      final pageId = exec.resolveString(action['pageId']);
      final mode = exec.resolveString(action['mode'] ?? 'replace');

      // Resolve params if present.
      final rawParams = action['params'] as Map<String, dynamic>?;
      Map<String, dynamic>? resolvedParams;
      if (rawParams != null) {
        resolvedParams = <String, dynamic>{};
        for (final entry in rawParams.entries) {
          resolvedParams[entry.key] = exec.resolveValue(entry.value);
        }
      }

      await store.updateSubPage(subPageId, pageId, resolvedParams, mode);
    };

    // closeDialog — pops the modal bottom sheet. Deferred to next frame
    // to avoid Navigator locked assertion when called from a server action chain.
    _handlers['closeDialog'] = (action, exec) async {
      if (exec.context != null) {
        final ctx = exec.context!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
      }
    };
  }
}
