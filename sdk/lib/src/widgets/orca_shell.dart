import 'package:flutter/material.dart' show
    AppBar,
    BottomNavigationBar,
    BottomNavigationBarItem,
    Drawer,
    DrawerHeader,
    IconButton,
    Icons,
    ListTile,
    Scaffold,
    Theme,
    ThemeData;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../client/orca_client.dart';
import '../models/component_node.dart';
import '../models/page_response.dart';
import '../navigation/navigation_handler.dart';
import '../rendering/component_registry.dart';
import '../rendering/component_renderer.dart';
import '../state/action_executor.dart';
import '../state/state_manager.dart';

/// Shell widget that provides a Scaffold with bottom tab bar and optional drawer.
/// Supports server-driven component trees for full visual customization.
class OrcaShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<TabDef> tabs;
  final List<DrawerItemDef> drawerItems;
  final List<ComponentNode> tabBarComponents;
  final List<ComponentNode> drawerComponents;
  final StateManager? stateManager;
  final ComponentRegistry? registry;
  final Map<String, ActionHandler>? customActions;
  final OrcaClient? client;
  final String? appId;

  const OrcaShell({
    super.key,
    required this.navigationShell,
    required this.tabs,
    this.drawerItems = const [],
    this.tabBarComponents = const [],
    this.drawerComponents = const [],
    this.stateManager,
    this.registry,
    this.customActions,
    this.client,
    this.appId,
  });

  @override
  State<OrcaShell> createState() => _OrcaShellState();
}

class _OrcaShellState extends State<OrcaShell> {
  int _lastSyncedIndex = -1;

  @override
  void didUpdateWidget(OrcaShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTabIndex();
  }

  @override
  void initState() {
    super.initState();
    _syncTabIndex();
    // Listen for app state changes to _tabIndex (from BottomNavigationBar taps)
    widget.stateManager?.appStore.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    widget.stateManager?.appStore.removeListener(_onAppStateChanged);
    super.dispose();
  }

  /// Sync GoRouter's current branch index → app state `_tabIndex`.
  void _syncTabIndex() {
    final sm = widget.stateManager;
    if (sm == null) return;
    final goIndex = widget.navigationShell.currentIndex;
    if (goIndex != _lastSyncedIndex) {
      _lastSyncedIndex = goIndex;
      sm.setAppState('_tabIndex', goIndex);
    }
  }

  /// When `_tabIndex` changes in app state (from server-driven BottomNavigationBar tap),
  /// sync it back to GoRouter.
  void _onAppStateChanged() {
    final sm = widget.stateManager;
    if (sm == null) return;
    final stateIndex = sm.appStore.state['_tabIndex'];
    if (stateIndex is int && stateIndex != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(
        stateIndex,
        initialLocation: stateIndex == widget.navigationShell.currentIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasServerTabBar = widget.tabBarComponents.isNotEmpty;
    final hasServerDrawer = widget.drawerComponents.isNotEmpty;
    final hasDrawer = hasServerDrawer || widget.drawerItems.isNotEmpty;

    final currentTab = widget.navigationShell.currentIndex < widget.tabs.length
        ? widget.tabs[widget.navigationShell.currentIndex]
        : null;

    return Theme(
      data: ThemeData(),
      child: Scaffold(
        appBar: hasDrawer
            ? AppBar(
                title: Text(currentTab?.label ?? ''),
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              )
            : null,
        body: widget.navigationShell,
        bottomNavigationBar: hasServerTabBar
            ? _renderServerTabBar()
            : (widget.tabs.isNotEmpty ? _buildDefaultTabBar() : null),
        drawer: hasServerDrawer
            ? _renderServerDrawer()
            : (widget.drawerItems.isNotEmpty ? _buildDefaultDrawer(context) : null),
      ),
    );
  }

  // ── Server-driven rendering ─────────────────────────────

  Widget _renderServerTabBar() {
    final registry = widget.registry ?? (ComponentRegistry()..registerDefaults());
    final sm = widget.stateManager;
    final state = sm?.appStore.state ?? {};
    final actionExecutor = sm != null
        ? ActionExecutor(
            context: context,
            stateManager: sm,
            pageId: '__shell__',
            client: widget.client,
            appId: widget.appId,
          )
        : null;
    if (actionExecutor != null && widget.customActions != null) {
      for (final entry in widget.customActions!.entries) {
        actionExecutor.registerHandler(entry.key, entry.value);
      }
    }
    final renderer = ComponentRenderer(
      registry: registry,
      state: state,
      actionExecutor: actionExecutor,
    );
    return renderer.render(widget.tabBarComponents);
  }

  Widget _renderServerDrawer() {
    final registry = widget.registry ?? (ComponentRegistry()..registerDefaults());
    final sm = widget.stateManager;
    final state = sm?.appStore.state ?? {};
    final actionExecutor = sm != null
        ? ActionExecutor(
            context: context,
            stateManager: sm,
            pageId: '__shell__',
            client: widget.client,
            appId: widget.appId,
          )
        : null;
    if (actionExecutor != null && widget.customActions != null) {
      for (final entry in widget.customActions!.entries) {
        actionExecutor.registerHandler(entry.key, entry.value);
      }
    }
    final renderer = ComponentRenderer(
      registry: registry,
      state: state,
      actionExecutor: actionExecutor,
    );
    return renderer.render(widget.drawerComponents);
  }

  // ── Default (fallback) rendering ────────────────────────

  Widget _buildDefaultTabBar() {
    return BottomNavigationBar(
      currentIndex: widget.navigationShell.currentIndex,
      onTap: (index) => widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      ),
      items: widget.tabs
          .map((tab) => BottomNavigationBarItem(
                icon: Icon(NavigationHandler.resolveIcon(tab.icon)),
                label: tab.label,
              ))
          .toList(),
    );
  }

  Widget _buildDefaultDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1976D2)),
            child: Text(
              'Menu',
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 24),
            ),
          ),
          for (final item in widget.drawerItems)
            ListTile(
              leading: Icon(NavigationHandler.resolveIcon(item.icon)),
              title: Text(item.label),
              onTap: () {
                Navigator.of(context).pop();
                GoRouter.of(context).push(item.route);
              },
            ),
        ],
      ),
    );
  }
}
