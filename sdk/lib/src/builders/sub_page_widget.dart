import 'package:material_ui/material_ui.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import '../models/component_node.dart';
import '../models/page_response.dart';
import '../rendering/component_context.dart';
import '../rendering/component_renderer.dart';
import '../state/component_store.dart';
import '../state/sub_page_core.dart';

/// A stateful widget that fetches a sub-page and renders it inline.
///
/// Follows the SubPage contract (`schema/fixtures/subpage/README.md`, S1 to
/// S8). The rules live in `sub_page_core.dart`; this widget fetches, hands
/// the merged nodes to the parent page's [ComponentStore] and the state seeds
/// to the parent page's state, and draws the mounted pages.
class OrcaSubPageWidget extends StatefulWidget {
  /// The stable key of the SubPage node (used as namespace prefix).
  final String subPageKey;

  /// The page ID to fetch.
  final String pageId;

  /// Optional parameters for the page fetch.
  final Map<String, dynamic>? params;

  /// The parent component context (provides client, state, renderer access).
  final OrcaComponentContext parentContext;

  /// Optional loading placeholder from the onLoading child.
  final Widget? loadingWidget;

  const OrcaSubPageWidget({
    super.key,
    required this.subPageKey,
    required this.pageId,
    this.params,
    required this.parentContext,
    this.loadingWidget,
  });

  @override
  State<OrcaSubPageWidget> createState() => OrcaSubPageWidgetState();
}

class OrcaSubPageWidgetState extends State<OrcaSubPageWidget> {
  /// The pages mounted here, oldest first (page 0 `K:`, joined `K#j:`).
  late final SubPageMounts _mounts = SubPageMounts(widget.subPageKey);

  /// The parent page's node store, kept for [dispose].
  ComponentStore? _store;

  /// True until a first page is mounted or the first fetch fails.
  bool _loading = true;

  /// Why the widget's own fetch failed; drawn in the place of the pages.
  Object? _error;

  /// Counts the fetches this widget starts for its own props; an answer that
  /// is no longer the latest, or that an updateSubPage overtook, is dropped.
  int _load = 0;

  @override
  void initState() {
    super.initState();
    _store = widget.parentContext.actionExecutor?.componentStore;
    // Register this sub-page for updateSubPage action targeting.
    _store?.registerSubPage(widget.subPageKey, updateContent);
    _loadOwn();
  }

  @override
  void didUpdateWidget(OrcaSubPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // S4: fetch again, as a replace, when the resolved page or params change.
    if (subPageRequest(oldWidget.pageId, oldWidget.params).location !=
        subPageRequest(widget.pageId, widget.params).location) {
      _loadOwn();
    }
  }

  @override
  void dispose() {
    // S8: the nodes leave the store, the state keys stay.
    _store?.removeSubPageNodes(_mounts.nodeIds);
    _store?.setSubPagePrefixes(widget.subPageKey, const []);
    _store?.unregisterSubPage(widget.subPageKey);
    super.dispose();
  }

  /// The fetch for the widget's own `pageId` and `params`. What is mounted
  /// stays on screen while it runs.
  Future<void> _loadOwn() async {
    final load = ++_load;
    try {
      final response = await _fetchSubPage(widget.pageId, widget.params);
      if (!mounted || load != _load) return;
      setState(() => _mount('replace', response));
    } catch (error) {
      if (!mounted || load != _load) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  /// S4: the normal page route, the resolved params as the query string.
  Future<PageResponse> _fetchSubPage(
    String pageId,
    Map<String, dynamic>? params,
  ) async {
    final exec = widget.parentContext.actionExecutor;
    if (exec == null || exec.client == null || exec.appId == null) {
      throw StateError(
        'SubPage requires an ActionExecutor with client and appId',
      );
    }

    final appState = exec.stateManager.appStore.state;
    return exec.client!.fetchPage(
      exec.appId!,
      subPageRequest(pageId, params).location,
      appState: appState.isNotEmpty ? appState : null,
    );
  }

  /// Mounts a fetched page and applies the change to the parent page in the
  /// contract's order: nodes out, state keys out, nodes in, seeds written.
  void _mount(String mode, PageResponse response) {
    final exec = widget.parentContext.actionExecutor;
    final pageStore = exec?.stateManager.getPageStore(exec.pageId);
    final change = _mounts.apply(
      mode,
      response.toJson(),
      pageStore?.state.keys.toList() ?? const <String>[],
    );
    _store?.removeSubPageNodes(change.removedNodeIds);
    pageStore?.removeKeys(change.removedStateKeys);
    _store?.putSubPageNodes(change.nodes.map(ComponentNode.fromJson));
    _store?.setSubPagePrefixes(widget.subPageKey, _mounts.prefixes);
    if (change.seeds.isNotEmpty) pageStore?.dispatch(change.seeds);
    _loading = false;
    _error = null;
  }

  /// Called by the updateSubPage action to load new content (S7). The old
  /// content stays while the fetch runs; a fetch error leaves it and is
  /// thrown to the action chain.
  Future<void> updateContent(
    String pageId,
    Map<String, dynamic>? params,
    String mode,
  ) async {
    final response = await _fetchSubPage(pageId, params);
    if (!mounted) return;
    // The update wins over a fetch of the widget's own that is still out.
    _load++;
    setState(() => _mount(mode, response));
  }

  /// The nodes to draw for one mounted page: its subtree as the parent store
  /// has it now (so component mutations show), else as it was merged.
  List<ComponentNode> _nodesOf(SubPageMounted page) {
    final rootId = page.rootId;
    if (rootId == null) return const [];
    if (_store != null) return _store!.subtree(rootId);
    return page.nodes.map(ComponentNode.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          'SubPage error: $_error',
          style: const TextStyle(color: Color(0xFFFF0000)),
        ),
      );
    }

    final parentPageStore = widget.parentContext.pageStore;
    final parentAppStore = widget.parentContext.appStore;
    final renderer = ComponentRenderer(
      registry: widget.parentContext.registry!,
      state: {
        ...widget.parentContext.state,
        if (parentAppStore != null) ...parentAppStore.state,
        if (parentPageStore != null) ...parentPageStore.state,
      },
      actionExecutor: widget.parentContext.actionExecutor,
      pageStore: parentPageStore,
      appStore: parentAppStore,
    );

    // S5: the root of each mounted page, oldest first, one below the other;
    // one page draws exactly as its root.
    final drawn = <Widget>[
      for (final page in _mounts.pages)
        if (_nodesOf(page) case final nodes when nodes.isNotEmpty)
          KeyedSubtree(
            key: ValueKey(page.prefix),
            child: renderer.render(nodes),
          ),
    ];
    if (drawn.isEmpty) return const SizedBox.shrink();
    if (drawn.length == 1) return drawn.single;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: drawn,
    );
  }
}
