import 'package:flutter/material.dart';

import 'models/app_settings.dart';
import 'models/debug_event.dart';
import 'models/device_session.dart';
import 'screens/action_log_screen.dart';
import 'screens/error_screen.dart';
import 'screens/network_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/state_inspector_screen.dart';
import 'screens/timeline_screen.dart';
import 'server/connection_manager.dart';
import 'server/session_exporter.dart';
import 'server/ws_server.dart';
import 'theme/theme_provider.dart';
import 'theme/typography.dart';
import 'widgets/chrome/command_palette.dart';
import 'widgets/chrome/shortcuts_host.dart';
import 'widgets/chrome/sidebar.dart';
import 'widgets/chrome/status_bar.dart';
import 'widgets/chrome/toolbar.dart';

/// Root widget. Wraps the app in [OrcaThemeBuilder] so every theme tweak
/// (mode / accent / density / font scale / translucency) rebuilds the tree.
class OrcaDevToolsApp extends StatelessWidget {
  final ConnectionManager connectionManager;
  final AppSettings settings;
  final DevToolsWsServer server;

  const OrcaDevToolsApp({
    super.key,
    required this.connectionManager,
    required this.settings,
    required this.server,
  });

  @override
  Widget build(BuildContext context) {
    return OrcaThemeBuilder(
      settings: settings,
      builder: (context, theme) {
        return MaterialApp(
          title: 'Orca DevTools',
          debugShowCheckedModeBanner: false,
          theme: theme.toFlutterThemeData(),
          home: MainShell(
            connectionManager: connectionManager,
            settings: settings,
            server: server,
          ),
        );
      },
    );
  }
}

const List<InspectorEntry> _kInspectors = [
  InspectorEntry(id: 'timeline', label: 'Timeline', icon: 'timeline'),
  InspectorEntry(id: 'state', label: 'State', icon: 'state'),
  InspectorEntry(id: 'actions', label: 'Actions', icon: 'actions'),
  InspectorEntry(id: 'network', label: 'Network', icon: 'network'),
  InspectorEntry(id: 'errors', label: 'Errors', icon: 'errors'),
];

const Map<String, String> _kInspectorShortcuts = {
  'timeline': '⌘1',
  'state': '⌘2',
  'actions': '⌘3',
  'network': '⌘4',
  'errors': '⌘5',
  'settings': '⌘,',
};

class MainShell extends StatefulWidget {
  final ConnectionManager connectionManager;
  final AppSettings settings;
  final DevToolsWsServer server;

  const MainShell({
    super.key,
    required this.connectionManager,
    required this.settings,
    required this.server,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  String _selected = 'timeline';
  bool _paletteOpen = false;

  void _jumpTo(String id) {
    setState(() {
      _selected = id;
      _paletteOpen = false;
    });
  }

  void _togglePalette() =>
      setState(() => _paletteOpen = !_paletteOpen);

  void _closePalette() {
    if (!_paletteOpen) return;
    setState(() => _paletteOpen = false);
  }

  Future<void> _restartServer() async {
    await widget.server.stop();
    await widget.server.restart(widget.settings.port);
  }

  Future<void> _export() async {
    final session = widget.connectionManager.activeSession;
    if (session == null) return;
    final file = await SessionExporter.export(
      session: session,
      settings: widget.settings,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported to ${file.path}')),
    );
  }

  /// Build the palette groups from the current live state.
  List<PaletteGroup> _buildGroups() {
    final cm = widget.connectionManager;
    final paused = cm.streamPaused;

    final jumpTo = <PaletteItem>[
      for (final ins in _kInspectors)
        PaletteItem(
          label: ins.label,
          icon: ins.icon,
          hint: _kInspectorShortcuts[ins.id],
          onActivate: () => _jumpTo(ins.id),
        ),
      PaletteItem(
        label: 'Settings',
        icon: 'settings',
        hint: _kInspectorShortcuts['settings'],
        onActivate: () => _jumpTo('settings'),
      ),
    ];

    final devices = <PaletteItem>[
      for (final id in cm.deviceIds)
        _deviceItem(cm.getSession(id)!, id),
    ];

    final recents = _recentPaths(cm.activeSession);

    final commands = <PaletteItem>[
      PaletteItem(
        label: paused ? 'Resume event stream' : 'Pause event stream',
        icon: paused ? 'play' : 'pause',
        onActivate: cm.toggleStream,
      ),
      PaletteItem(
        label: 'Export session as JSON…',
        icon: 'export',
        hint: '⌘E',
        onActivate: _export,
      ),
    ];

    return <PaletteGroup>[
      PaletteGroup(label: 'Jump to', items: jumpTo),
      if (devices.isNotEmpty)
        PaletteGroup(label: 'Devices', items: devices),
      if (recents.isNotEmpty)
        PaletteGroup(label: 'Recent paths', items: recents),
      PaletteGroup(label: 'Commands', items: commands),
    ];
  }

  PaletteItem _deviceItem(DeviceSession session, String id) {
    final info = session.deviceInfo;
    final label = info['deviceModel']?.toString() ??
        info['appName']?.toString() ??
        id;
    final app = info['appName']?.toString();
    final platform = (info['platform']?.toString() ?? '').toLowerCase();
    final icon = platform == 'ios' ? 'iphone' : 'android';
    return PaletteItem(
      label: app != null ? '$label · $app' : label,
      icon: icon,
      onActivate: () {
        widget.connectionManager.setActiveDevice(id);
        _closePalette();
      },
    );
  }

  List<PaletteItem> _recentPaths(DeviceSession? session) {
    if (session == null) return const <PaletteItem>[];
    final events = session.events;
    final seen = <String>{};
    final items = <PaletteItem>[];
    for (var i = events.length - 1; i >= 0 && items.length < 8; i--) {
      final DebugEvent e = events[i];
      if (e.type != 'timing') continue;
      final path = e.payload['path']?.toString();
      if (path == null || seen.contains(path)) continue;
      seen.add(path);
      items.add(PaletteItem(
        label: path,
        icon: 'timeline',
        onActivate: () => _jumpTo('timeline'),
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return ShortcutsHost(
      onTogglePalette: _togglePalette,
      onClosePalette: _closePalette,
      onExport: _export,
      onJumpToInspector: _jumpTo,
      child: ListenableBuilder(
        listenable: widget.connectionManager,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: theme.surface.content,
            body: Stack(
              children: [
                Row(
                  children: [
                    OrcaSidebar(
                      connectionManager: widget.connectionManager,
                      inspectors: _kInspectors,
                      selectedInspector: _selected,
                      onSelectInspector: _jumpTo,
                    ),
                    Expanded(
                      child: _ShellBody(
                        selected: _selected,
                        connectionManager: widget.connectionManager,
                        settings: widget.settings,
                        onOpenPalette: _togglePalette,
                        onExport: _export,
                        onRestartServer: _restartServer,
                      ),
                    ),
                  ],
                ),
                CommandPalette(
                  open: _paletteOpen,
                  onClose: _closePalette,
                  groups: _paletteOpen ? _buildGroups() : const [],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShellBody extends StatelessWidget {
  final String selected;
  final ConnectionManager connectionManager;
  final AppSettings settings;
  final VoidCallback onOpenPalette;
  final VoidCallback onExport;
  final VoidCallback onRestartServer;

  const _ShellBody({
    required this.selected,
    required this.connectionManager,
    required this.settings,
    required this.onOpenPalette,
    required this.onExport,
    required this.onRestartServer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      color: theme.surface.content,
      child: Column(
        children: [
          OrcaToolbar(
            connectionManager: connectionManager,
            onOpenPalette: onOpenPalette,
            onExport: onExport,
          ),
          Expanded(
            child: _InspectorHost(
              selected: selected,
              connectionManager: connectionManager,
              settings: settings,
              onRestartServer: onRestartServer,
            ),
          ),
          OrcaStatusBar(
            connectionManager: connectionManager,
            settings: settings,
          ),
        ],
      ),
    );
  }
}

class _InspectorHost extends StatelessWidget {
  final String selected;
  final ConnectionManager connectionManager;
  final AppSettings settings;
  final VoidCallback onRestartServer;

  const _InspectorHost({
    required this.selected,
    required this.connectionManager,
    required this.settings,
    required this.onRestartServer,
  });

  @override
  Widget build(BuildContext context) {
    if (selected == 'settings') {
      return SettingsScreen(
        settings: settings,
        onRestartServer: onRestartServer,
      );
    }
    final session = connectionManager.activeSession;
    if (session == null) return const _WaitingForDevice();
    return _InspectorForId(selected: selected, session: session);
  }
}

class _InspectorForId extends StatelessWidget {
  final String selected;
  final DeviceSession session;

  const _InspectorForId({required this.selected, required this.session});

  @override
  Widget build(BuildContext context) {
    switch (selected) {
      case 'timeline':
        return TimelineScreen(session: session);
      case 'state':
        return StateInspectorScreen(session: session);
      case 'actions':
        return ActionLogScreen(session: session);
      case 'network':
        return NetworkScreen(session: session);
      case 'errors':
        return ErrorScreen(session: session);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _WaitingForDevice extends StatelessWidget {
  const _WaitingForDevice();

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Center(
      child: Text(
        'Waiting for device connection...',
        style: TextStyle(
          fontFamily: kSfPro,
          fontFamilyFallback: kSfProFallback,
          fontSize: fs(13, theme.fontScale),
          color: theme.text.secondary,
        ),
      ),
    );
  }
}
