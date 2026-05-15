import 'package:flutter/material.dart' show
    AppBar,
    CircularProgressIndicator,
    Scaffold,
    Theme,
    ThemeData,
    showModalBottomSheet;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/widgets.dart';
import '../client/orca_client.dart';
import '../client/static_flow_manager.dart';
import '../debug/orca_debug.dart';
import '../debug/debug_events.dart';
import '../debug/debug_overlay.dart';
import '../debug/timing_collector.dart';
import '../models/component_node.dart';
import '../models/page_response.dart';
import 'orca_error.dart';
import '../plugins/orca_plugin.dart';
import '../plugins/plugin_merger.dart';
import '../rendering/component_registry.dart';
import '../rendering/component_renderer.dart';
import '../state/action_executor.dart';
import '../state/animation_registry.dart';
import '../state/component_store.dart';
import '../state/elm_store.dart';
import '../state/state_manager.dart';

/// A widget that fetches a page from the Orca Gateway engine and renders it.
class OrcaPage extends StatefulWidget {
  /// The OrcaClient used to fetch pages.
  final OrcaClient client;

  /// The app ID to fetch the page for.
  final String appId;

  /// The page path to fetch.
  final String path;

  /// Optional app state to send with the request.
  final Map<String, dynamic>? appState;

  /// The component registry to use for rendering.
  /// If null, a default registry with all built-in builders is used.
  final ComponentRegistry? registry;

  /// Optional custom action handlers to register on the page's ActionExecutor.
  final Map<String, ActionHandler>? customActions;

  /// Optional plugins that bundle related custom widgets and actions.
  final List<OrcaPlugin>? plugins;

  /// Widget to show while loading.
  final Widget? loadingWidget;

  /// Widget builder to show on error.
  final Widget Function(Object error)? errorBuilder;

  /// Shared StateManager — if null, a page-local one is created.
  final StateManager? stateManager;

  /// Optional StaticFlowManager for cache-first static page loading.
  final StaticFlowManager? staticFlowManager;

  /// The flows from NavConfig, used to look up static pages in cache.
  final List<NavFlow>? flows;

  /// When true, wrap the rendered body in a Scaffold with an AppBar that
  /// reactively shows the loaded page's [PageResponse.title].
  final bool wrapInScaffold;

  /// Fallback AppBar title shown before the page response has loaded (used
  /// when [wrapInScaffold] is true).
  final String? scaffoldTitleFallback;

  const OrcaPage({
    super.key,
    required this.client,
    required this.appId,
    required this.path,
    this.appState,
    this.registry,
    this.customActions,
    this.plugins,
    this.loadingWidget,
    this.errorBuilder,
    this.stateManager,
    this.staticFlowManager,
    this.flows,
    this.wrapInScaffold = false,
    this.scaffoldTitleFallback,
  });

  @override
  State<OrcaPage> createState() => _OrcaPageState();
}

/// Wraps a page response with its associated timing data to avoid race conditions.
class _PageFetchResult {
  final PageResponse response;
  final ClientTimingCollector? timingCollector;
  final String? timingHeader;
  _PageFetchResult(this.response, {this.timingCollector, this.timingHeader});
}

class _OrcaPageState extends State<OrcaPage> {
  late Future<_PageFetchResult> _future;
  late StateManager _stateManager;
  PageResponse? _response;
  ElmStore? _pageStore;
  final ComponentStore _componentStore = ComponentStore();
  final AnimationRegistry _animationRegistry = AnimationRegistry();

  /// Whether the timing event has been reported for the current response.
  /// build() can re-run without a network fetch, so timing is reported at
  /// most once per page fetch (reset in [_initState]).
  bool _timingReported = false;

  @override
  void initState() {
    super.initState();
    _stateManager = widget.stateManager ?? StateManager();
    _future = _fetchPage();
  }

  @override
  void didUpdateWidget(OrcaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appId != widget.appId ||
        oldWidget.path != widget.path ||
        oldWidget.appState != widget.appState) {
      _disposeCurrentPage();
      _future = _fetchPage();
    }
  }

  @override
  void dispose() {
    _disposeCurrentPage();
    super.dispose();
  }

  void _disposeCurrentPage() {
    if (_response != null) {
      _componentStore.removeListener(_onComponentsChanged);
      _stateManager.disposePage(_response!.pageId);
      _pageStore = null;
      _response = null;
    }
  }

  Future<_PageFetchResult> _fetchPage() async {
    // Check static flow cache first
    if (widget.staticFlowManager != null && widget.flows != null) {
      final cached = await widget.staticFlowManager!.getCachedPage(
        widget.path,
        widget.flows!,
      );
      if (cached != null) return _PageFetchResult(cached);
    }

    // Fall through to network fetch
    final appState = widget.appState ?? _stateManager.appStore.state;
    final response = await widget.client.fetchPage(
      widget.appId,
      widget.path,
      appState: appState.isNotEmpty ? appState : null,
    );
    // Capture timing data immediately — prevents race with concurrent fetches
    return _PageFetchResult(
      response,
      timingCollector: widget.client.lastTimingCollector,
      timingHeader: widget.client.lastTimingHeader,
    );
  }

  void _initState(PageResponse response) {
    _response = response;
    _timingReported = false;
    _stateManager.initPage(response.pageId, response.state);
    _pageStore = _stateManager.getPageStore(response.pageId);
    _componentStore.init(response.components);
    // State changes — in EITHER scope — are handled by the per-node
    // WatchBuilders in the component tree, so the page root deliberately
    // does NOT subscribe to either store: a SetState rebuilds only the
    // widgets that watch the changed key, never the whole page.
    // Component mutations (add/delete/update/replace) restructure the tree
    // itself, so those still trigger a full rebuild.
    _componentStore.addListener(_onComponentsChanged);
  }

  // State-change notifications can arrive while we're still inside a build
  // (e.g. `_initState` seeds app-scoped keys synchronously on the first
  // FutureBuilder build). Calling setState during build triggers a framework
  // assertion, so we defer to the next frame when the scheduler isn't idle.
  void _scheduleRebuild() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onComponentsChanged() => _scheduleRebuild();

  /// Build a merged state map (app state + page state, page wins on conflict).
  Map<String, dynamic> _mergedState() {
    final app = _stateManager.appStore.state;
    final page = _pageStore?.state ?? {};
    return {...app, ...page};
  }

  Widget _maybeWrapScaffold(Widget body, {String? overrideTitle}) {
    if (!widget.wrapInScaffold) return body;
    final title = overrideTitle ??
        _response?.title ??
        widget.scaffoldTitleFallback ??
        '';
    return Theme(
      data: ThemeData(),
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PageFetchResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _maybeWrapScaffold(widget.loadingWidget ??
              const Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return _maybeWrapScaffold(widget.errorBuilder!(snapshot.error!));
          }
          return _maybeWrapScaffold(buildOrcaError(snapshot.error!));
        }

        final result = snapshot.data!;
        final response = result.response;

        // Initialize state on first build for this response.
        if (_response?.pageId != response.pageId) {
          _initState(response);
        }

        // Use per-fetch timing data (not shared client state) to avoid race conditions
        final timingCollector = result.timingCollector;
        timingCollector?.mark('renderStart');

        final merged = mergePlugins(
          registry: widget.registry,
          customActions: widget.customActions,
          plugins: widget.plugins,
        );
        final actionExecutor = ActionExecutor(
          context: context,
          stateManager: _stateManager,
          pageId: response.pageId,
          client: widget.client,
          appId: widget.appId,
          componentStore: _componentStore,
          animationRegistry: _animationRegistry,
          pagePath: widget.path,
          onRefetchPage: () async {
            final appState = _stateManager.appStore.state;
            final freshResponse = await widget.client.fetchPage(
              widget.appId,
              widget.path,
              appState: appState.isNotEmpty ? appState : null,
            );
            // Schedule the tree update after the current frame to avoid
            // calling setState during build (componentStore.init notifies).
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _stateManager.initPage(freshResponse.pageId, freshResponse.state);
                _pageStore = _stateManager.getPageStore(freshResponse.pageId);
                _componentStore.init(freshResponse.components);
              });
            }
          },
          pageBuilder: (path) => OrcaPage(
            client: widget.client,
            appId: widget.appId,
            path: path,
            stateManager: _stateManager,
            registry: widget.registry,
            customActions: widget.customActions,
            plugins: widget.plugins,
          ),
        );
        for (final entry in merged.customActions.entries) {
          actionExecutor.registerHandler(entry.key, entry.value);
        }

        // openDialog handler — shows a Dialog node as a modal bottom sheet.
        actionExecutor.registerHandler('openDialog', (action, exec) async {
          final dialogId = action['dialogId'] as String?;
          if (dialogId == null) return;
          final heightFactor = (action['heightFactor'] as num?)?.toDouble() ?? 0.5;

          final dialogNode = _componentStore.nodeMap[dialogId];
          if (dialogNode == null) return;

          // Collect the dialog's child subtree.
          final subtree = <ComponentNode>[];
          void collect(String id) {
            final n = _componentStore.nodeMap[id];
            if (n == null) return;
            subtree.add(n);
            for (final cid in n.children) {
              collect(cid);
            }
          }
          for (final childId in dialogNode.children) {
            collect(childId);
          }
          if (subtree.isEmpty) return;

          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0x00000000),
            builder: (_) {
              final dialogRenderer = ComponentRenderer(
                registry: merged.registry,
                state: _mergedState(),
                actionExecutor: exec,
                pageStore: _pageStore,
                appStore: _stateManager.appStore,
              );
              return FractionallySizedBox(
                heightFactor: heightFactor,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: dialogRenderer.render(subtree),
                ),
              );
            },
          );
        });

        final renderer = ComponentRenderer(
          registry: merged.registry,
          state: _mergedState(),
          actionExecutor: actionExecutor,
          pageStore: _pageStore,
          appStore: _stateManager.appStore,
        );
        final nodes = _componentStore.toList();
        final rendered = renderer.render(nodes);

        timingCollector?.mark('renderComplete');

        // Report combined timing data to OrcaDebug — once per page fetch.
        // build() can re-run for reasons unrelated to a network fetch (e.g.
        // a component-tree mutation); re-emitting the timing event with the
        // stale collector would draw a phantom request on every rebuild.
        if (OrcaDebug.isEnabled && timingCollector != null && !_timingReported) {
          _timingReported = true;
          final combined = CombinedTimingData.merge(
            result.timingHeader,
            timingCollector,
          );
          OrcaDebug.instance?.reportTiming(DebugTimingEvent(
            pageId: response.pageId,
            path: widget.path,
            timing: combined,
          ));
        }

        // Wrap with debug overlay if enabled (M2: reuse nodes, M3: use renderCompleteMs)
        if (OrcaDebug.isEnabled && OrcaDebug.config.showOverlay) {
          final clientData = timingCollector?.toData();
          return _maybeWrapScaffold(OrcaDebugOverlay(
            lastLoadTimeMs: clientData?.renderCompleteMs,
            componentCount: nodes.length,
            child: rendered,
          ));
        }

        return _maybeWrapScaffold(rendered);
      },
    );
  }
}
