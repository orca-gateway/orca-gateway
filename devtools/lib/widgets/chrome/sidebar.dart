import 'package:flutter/material.dart';
import '../../models/device_session.dart';
import '../../server/connection_manager.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';
import '../primitives/orca_icon.dart';

/// One inspector entry in the sidebar list.
class InspectorEntry {
  final String id;
  final String label;
  final String icon;
  final int badge;
  const InspectorEntry({
    required this.id,
    required this.label,
    required this.icon,
    this.badge = 0,
  });
}

class OrcaSidebar extends StatelessWidget {
  final ConnectionManager connectionManager;
  final List<InspectorEntry> inspectors;
  final String selectedInspector;
  final ValueChanged<String> onSelectInspector;

  const OrcaSidebar({
    super.key,
    required this.connectionManager,
    required this.inspectors,
    required this.selectedInspector,
    required this.onSelectInspector,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    // Opaque sidebar colour. Real macOS vibrancy requires a transparent
    // native window (flutter_acrylic + macos/Runner config); until we opt in,
    // use the solid fallbacks the design defined for translucent=off.
    final bg = theme.isDark ? const Color(0xFF242428) : const Color(0xFFE4E8EE);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: theme.border.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarSectionLabel(label: 'Devices'),
          _DeviceList(connectionManager: connectionManager),
          _SidebarSectionLabel(label: 'Inspectors'),
          ...inspectors.map((ins) => _InspectorRow(
                entry: ins,
                selected: ins.id == selectedInspector,
                onTap: () => onSelectInspector(ins.id),
              )),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.border.divider),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _InspectorRow(
              entry: const InspectorEntry(
                id: 'settings',
                label: 'Settings',
                icon: 'settings',
              ),
              selected: selectedInspector == 'settings',
              onTap: () => onSelectInspector('settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  final String label;
  const _SidebarSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: kSfPro,
          fontFamilyFallback: kSfProFallback,
          fontSize: fs(10, theme.fontScale),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: theme.text.tertiary,
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  final ConnectionManager connectionManager;
  const _DeviceList({required this.connectionManager});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final ids = connectionManager.deviceIds;
    if (ids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          'No devices connected',
          style: TextStyle(
            fontFamily: kSfPro,
            fontFamilyFallback: kSfProFallback,
            fontSize: fs(11.5, theme.fontScale),
            color: theme.text.tertiary,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ids.map((id) {
        final session = connectionManager.getSession(id)!;
        final active = id == connectionManager.activeDeviceId;
        return _DeviceBadge(
          session: session,
          selected: active,
          onTap: () => connectionManager.setActiveDevice(id),
        );
      }).toList(),
    );
  }
}

class _DeviceBadge extends StatefulWidget {
  final DeviceSession session;
  final bool selected;
  final VoidCallback onTap;

  const _DeviceBadge({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_DeviceBadge> createState() => _DeviceBadgeState();
}

class _DeviceBadgeState extends State<_DeviceBadge> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final info = widget.session.deviceInfo;
    final platform = (info['platform']?.toString() ?? '').toLowerCase();
    final isIos = platform == 'ios';
    final label = info['deviceModel']?.toString() ??
        info['appName']?.toString() ??
        platform;

    final bg = widget.selected
        ? theme.accent.muted
        : (_hover ? theme.surface.hover : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: theme.density.sidebarRow,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              OrcaIcon(
                isIos ? 'iphone' : 'android',
                size: 13,
                color: widget.selected
                    ? theme.accent.base
                    : theme.text.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSfPro,
                    fontFamilyFallback: kSfProFallback,
                    fontSize: fs(12.5, theme.fontScale),
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: theme.text.primary,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.semantic.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorRow extends StatefulWidget {
  final InspectorEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _InspectorRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_InspectorRow> createState() => _InspectorRowState();
}

class _InspectorRowState extends State<_InspectorRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final bg = widget.selected
        ? theme.accent.muted
        : (_hover ? theme.surface.hover : Colors.transparent);
    final iconColor =
        widget.selected ? theme.accent.base : theme.text.secondary;
    final isErrors = widget.entry.id == 'errors';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: theme.density.sidebarRow,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              OrcaIcon(widget.entry.icon, size: 14, color: iconColor),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.entry.label,
                  style: TextStyle(
                    fontFamily: kSfPro,
                    fontFamilyFallback: kSfProFallback,
                    fontSize: fs(12.5, theme.fontScale),
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: theme.text.primary,
                  ),
                ),
              ),
              if (widget.entry.badge > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isErrors
                        ? theme.semantic.danger.withValues(alpha: 0.13)
                        : theme.surface.raised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.entry.badge.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kSfMono,
                      fontFamilyFallback: kSfMonoFallback,
                      fontSize: fs(10, theme.fontScale),
                      fontWeight: FontWeight.w600,
                      color: isErrors
                          ? theme.semantic.danger
                          : theme.text.secondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
