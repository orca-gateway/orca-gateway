import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import '../debug/orca_debug.dart';
import '../debug/debug_events.dart';
import '../models/component_node.dart';
import '../state/action_executor.dart';
import '../state/elm_store.dart';
import '../state/watch_builder.dart';
import '../telemetry/orca_telemetry.dart';
import '../widgets/lifecycle_wrapper.dart';
import 'component_context.dart';
import 'component_registry.dart';

/// Renders a flat list of ComponentNodes into a Flutter widget tree.
class ComponentRenderer {
  final ComponentRegistry registry;
  final Map<String, dynamic> state;
  final ActionExecutor? actionExecutor;

  /// Optional page- and app-scoped stores for watch-based selective
  /// rebuilding. When either is provided, nodes with non-empty
  /// [ComponentNode.watches] are wrapped in a [WatchBuilder] that rebuilds
  /// only when one of its watched keys changes — in either scope.
  final ElmStore? pageStore;
  final ElmStore? appStore;

  const ComponentRenderer({
    required this.registry,
    this.state = const {},
    this.actionExecutor,
    this.pageStore,
    this.appStore,
  });

  /// Render the component tree from a flat node list.
  /// The first node in the list is treated as the root.
  Widget render(List<ComponentNode> nodes) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final nodeMap = <String, ComponentNode>{};
    for (final node in nodes) {
      nodeMap[node.id] = node;
    }

    return _renderNode(nodes.first.id, nodeMap);
  }

  Widget _renderNode(String nodeId, Map<String, ComponentNode> nodeMap) {
    final node = nodeMap[nodeId];
    if (node == null) {
      return ErrorWidget('Node not found: $nodeId');
    }

    // If this node has watches and we have a store, wrap in WatchBuilder
    // so it only rebuilds when watched keys change.
    if ((pageStore != null || appStore != null) && node.watches.isNotEmpty) {
      return WatchBuilder(
        key: ValueKey('watch_$nodeId'),
        pageStore: pageStore,
        appStore: appStore,
        watches: node.watches.toSet(),
        builder: (_, watchedState) {
          // Merge the full base state (which includes app state) with
          // the watched page-state snapshot so V.appState() refs resolve.
          final merged = {...state, ...watchedState};
          return _buildNode(node, nodeMap, merged, isWatchedRebuild: true);
        },
      );
    }

    return _buildNode(node, nodeMap, state);
  }

  Widget _buildNode(
    ComponentNode node,
    Map<String, ComponentNode> nodeMap,
    Map<String, dynamic> currentState, {
    bool isWatchedRebuild = false,
  }) {
    // Epic 38 tasks 38.1–38.3. When we're rendering on web (kIsWeb — true
    // under the Flutter Web preview editor AND any production web client)
    // AND the widget is marked unsupported, walk the fallback chain:
    //
    //   1. Prefer a registered web stub — plugin authors use this hook to
    //      ship a purpose-built preview substitute (static map image, stub
    //      card, whatever communicates the shape honestly).
    //   2. Otherwise substitute an UnsupportedWidgetPlaceholder node so the
    //      viewer sees an explicit "runs in the compiled app" card instead
    //      of a blank region. Metadata (display name, icon, docs URL) comes
    //      from the plugin's widget metadata when present, so the card is
    //      informative without the server having to re-send it.
    //
    // We intentionally perform this check BEFORE the unknown-widget safe
    // degrade path below, because an unsupported-on-web widget IS known to
    // the registry — it just isn't renderable here. If we fell through to
    // the unknown-widget branch it would synthesize a generic FallbackPrompt
    // and erase the specific "Google Maps isn't supported on web" signal the
    // tenant needs to see.
    if (kIsWeb && registry.isUnsupportedOnWeb(node.type)) {
      final stub = registry.getWebStub(node.type);
      if (stub != null) {
        final stubContext = OrcaComponentContext(
          node: node,
          nodeMap: nodeMap,
          renderChild: (childId) => _renderNode(childId, nodeMap),
          state: currentState,
          actionExecutor: actionExecutor,
          registry: registry,
          pageStore: pageStore,
          appStore: appStore,
        );
        return stub(stubContext);
      }

      final placeholderBuilder = registry.get('UnsupportedWidgetPlaceholder');
      if (placeholderBuilder != null) {
        OrcaTelemetry.reportUnknownWidgetOnce(node.type);
        final meta = registry.getMetadata(node.type);
        final syntheticNode = node.copyWith(
          type: 'UnsupportedWidgetPlaceholder',
          kind: 'primitive',
          childMode: 'none',
          props: <String, dynamic>{
            'widgetType': node.type,
            if (meta?.displayName != null) 'displayName': meta!.displayName,
            if (meta?.iconName != null) 'iconName': meta!.iconName,
            if (meta?.docsUrl != null) 'docsUrl': meta!.docsUrl,
          },
          children: const <String>[],
          watches: const <String>[],
        );
        final placeholderContext = OrcaComponentContext(
          node: syntheticNode,
          nodeMap: nodeMap,
          renderChild: (childId) => _renderNode(childId, nodeMap),
          state: currentState,
          actionExecutor: actionExecutor,
          registry: registry,
        );
        return placeholderBuilder(placeholderContext);
      }
      // If even UnsupportedWidgetPlaceholder isn't registered (very old SDK
      // build), fall through to the unknown-widget path below — a
      // FallbackPrompt is a strictly safer last resort than a red overlay.
    }

    final builder = registry.get(node.type);
    if (builder == null) {
      // Safe-degrade path (Epic 25b, task 25b.9). This branch fires when the
      // server emits a component type this SDK build does not recognize —
      // typically a forward-compat miss (server runs a newer protocol than
      // this app shipped with) or a stale-cache scenario where the policy
      // lookup upstream picked the wrong fallback. Rather than showing a red
      // error overlay (hostile to end users) we synthesize a FallbackPrompt
      // node — the frozen, v1-forever widget guaranteed to exist in every
      // SDK build — and hand it back to the renderer. Telemetry reports the
      // occurrence once per session so the tenant can see forward-compat
      // drift in their dashboards without spamming per render.
      OrcaTelemetry.reportUnknownWidgetOnce(node.type);
      final fallbackBuilder = registry.get('FallbackPrompt');
      if (fallbackBuilder != null) {
        final syntheticNode = node.copyWith(
          type: 'FallbackPrompt',
          kind: 'primitive',
          childMode: 'none',
          props: <String, dynamic>{
            'title': 'Unsupported content',
            'body':
                'This screen includes a "${node.type}" component that this app version cannot display. Please update to the latest version for the full experience.',
            'severity': 'warn',
          },
          children: const <String>[],
          watches: const <String>[],
        );
        final fallbackContext = OrcaComponentContext(
          node: syntheticNode,
          nodeMap: nodeMap,
          renderChild: (childId) => _renderNode(childId, nodeMap),
          state: currentState,
          actionExecutor: actionExecutor,
          registry: registry,
        );
        return fallbackBuilder(fallbackContext);
      }
      // Last-resort: FallbackPrompt isn't registered either (shouldn't happen
      // with default builders, but guard anyway). Render a zero-height box so
      // we never throw or flash red, per 25b.9.
      return const SizedBox.shrink();
    }

    final shouldTrace = isWatchedRebuild && OrcaDebug.isEnabled;
    final context = OrcaComponentContext(
      node: node,
      nodeMap: nodeMap,
      renderChild: (childId) => _renderNode(childId, nodeMap),
      state: currentState,
      actionExecutor: actionExecutor,
      registry: registry,
      pageStore: pageStore,
      appStore: appStore,
      captureTraces: shouldTrace,
    );

    Widget widget = builder(context);

    if (shouldTrace && context.propTraces.isNotEmpty) {
      OrcaDebug.instance?.reportWidgetRebuild(DebugWidgetRebuildEvent(
        widgetId: node.id,
        widgetType: node.type,
        watches: node.watches,
        propTraces: context.propTraces,
      ));
    }

    final actions = node.actions;
    final hasOnInit = actions?.containsKey('onInit') ?? false;
    final hasOnVisible = actions?.containsKey('onVisible') ?? false;
    // App-lifecycle triggers accept either the new `onApp*` name or the
    // older `on*` alias. Emitting the trigger name that was actually set
    // (onAppBackground vs onBackground) keeps the authoring intent clear in
    // the action executor logs.
    final onBackgroundTrigger = (actions?.containsKey('onAppBackground') ?? false)
        ? 'onAppBackground'
        : ((actions?.containsKey('onBackground') ?? false) ? 'onBackground' : null);
    final onForegroundTrigger = (actions?.containsKey('onAppForeground') ?? false)
        ? 'onAppForeground'
        : ((actions?.containsKey('onForeground') ?? false) ? 'onForeground' : null);

    if (hasOnInit || hasOnVisible || onBackgroundTrigger != null || onForegroundTrigger != null) {
      widget = OrcaLifecycleWrapper(
        onInit: hasOnInit ? () => context.fireAction('onInit') : null,
        onVisible: hasOnVisible ? () => context.fireAction('onVisible') : null,
        onBackground: onBackgroundTrigger != null
            ? () => context.fireAction(onBackgroundTrigger)
            : null,
        onForeground: onForegroundTrigger != null
            ? () => context.fireAction(onForegroundTrigger)
            : null,
        child: widget,
      );
    }

    return widget;
  }
}
