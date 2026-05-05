import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import '../models/component_node.dart';
import '../models/page_response.dart';
import '../rendering/component_context.dart';
import '../rendering/component_renderer.dart';

/// A stateful widget that fetches a sub-page and renders it inline.
///
/// Sub-page component IDs are prefixed with `{subPageKey}:` to prevent
/// collisions with the parent page. State keys from the sub-page are also
/// prefixed and merged into the parent's page state.
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
  Future<PageResponse>? _future;
  PageResponse? _response;
  List<ComponentNode> _prefixedComponents = [];

  /// Components from a previous "join" that should be kept.
  List<ComponentNode> _joinedComponents = [];

  @override
  void initState() {
    super.initState();
    _future = _fetchSubPage(widget.pageId, widget.params);
    // Register this sub-page for updateSubPage action targeting.
    widget.parentContext.actionExecutor?.componentStore
        ?.registerSubPage(widget.subPageKey, updateContent);
  }

  @override
  void didUpdateWidget(OrcaSubPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageId != widget.pageId) {
      _joinedComponents = [];
      _future = _fetchSubPage(widget.pageId, widget.params);
    }
  }

  @override
  void dispose() {
    widget.parentContext.actionExecutor?.componentStore
        ?.unregisterSubPage(widget.subPageKey);
    super.dispose();
  }

  Future<PageResponse> _fetchSubPage(String pageId, Map<String, dynamic>? params) async {
    final exec = widget.parentContext.actionExecutor;
    if (exec == null || exec.client == null || exec.appId == null) {
      throw StateError('SubPage requires an ActionExecutor with client and appId');
    }

    final appState = exec.stateManager.appStore.state;
    final response = await exec.client!.fetchPage(
      exec.appId!,
      pageId,
      appState: appState.isNotEmpty ? appState : null,
    );
    return response;
  }

  /// Prefix all component IDs with `{subPageKey}:` to avoid collisions.
  List<ComponentNode> _prefixComponents(List<ComponentNode> components) {
    final prefix = '${widget.subPageKey}:';
    return components.map((node) {
      return node.copyWith(
        id: '$prefix${node.id}',
        children: node.children.map((id) => '$prefix$id').toList(),
      );
    }).toList();
  }

  /// Merge sub-page state definitions into the parent's page store with prefix.
  void _mergeSubPageState(PageResponse response) {
    final exec = widget.parentContext.actionExecutor;
    if (exec == null) return;
    final prefix = '${widget.subPageKey}:';
    for (final def in response.state) {
      if (def.scope == 'page') {
        exec.stateManager.setPageState(
          exec.pageId,
          '$prefix${def.key}',
          def.initial,
        );
      }
    }
  }

  /// Called by the updateSubPage action to load new content.
  Future<void> updateContent(String pageId, Map<String, dynamic>? params, String mode) async {
    final response = await _fetchSubPage(pageId, params);
    final prefixed = _prefixComponents(response.components);

    if (!mounted) return;

    setState(() {
      _response = response;
      if (mode == 'join') {
        _joinedComponents = [..._joinedComponents, ..._prefixedComponents];
        _prefixedComponents = prefixed;
      } else {
        // replace
        _joinedComponents = [];
        _prefixedComponents = prefixed;
      }
    });

    _mergeSubPageState(response);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PageResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'SubPage error: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFFFF0000)),
            ),
          );
        }

        final response = snapshot.data!;

        // On first successful load, prefix and merge state.
        if (_response?.pageId != response.pageId) {
          _response = response;
          _prefixedComponents = _prefixComponents(response.components);
          _mergeSubPageState(response);
        }

        final allComponents = [..._joinedComponents, ..._prefixedComponents];
        if (allComponents.isEmpty) return const SizedBox.shrink();

        final exec = widget.parentContext.actionExecutor;
        final parentStore = widget.parentContext.store;

        final renderer = ComponentRenderer(
          registry: widget.parentContext.registry!,
          state: {
            ...widget.parentContext.state,
            if (parentStore != null) ...parentStore.state,
          },
          actionExecutor: exec,
          store: parentStore,
        );

        return renderer.render(allComponents);
      },
    );
  }
}
