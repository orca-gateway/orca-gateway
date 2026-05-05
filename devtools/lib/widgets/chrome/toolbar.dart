import 'package:flutter/material.dart';
import '../../server/connection_manager.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';
import '../primitives/kbd.dart';
import '../primitives/orca_icon.dart';

class OrcaToolbar extends StatelessWidget {
  final ConnectionManager connectionManager;
  final VoidCallback onOpenPalette;
  final VoidCallback onExport;
  final VoidCallback? onToggleInspector;
  final bool inspectorOpen;

  const OrcaToolbar({
    super.key,
    required this.connectionManager,
    required this.onOpenPalette,
    required this.onExport,
    this.onToggleInspector,
    this.inspectorOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final session = connectionManager.activeSession;
    final info = session?.deviceInfo ?? const <String, dynamic>{};
    final deviceLabel = info['deviceModel']?.toString() ??
        info['platform']?.toString() ??
        'No device';
    final appName = info['appName']?.toString() ?? '';
    final paused = connectionManager.streamPaused;

    // Opaque toolbar background; the translucent/vibrancy variant is deferred
    // until we switch the native window to a transparent surface.
    final bg =
        theme.isDark ? const Color(0xFF2B2B2F) : const Color(0xFFF2F2F4);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: theme.border.hairline),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Text(
            'Orca DevTools',
            style: TextStyle(
              fontFamily: kSfPro,
              fontFamilyFallback: kSfProFallback,
              fontSize: fs(13.5, theme.fontScale),
              fontWeight: FontWeight.w600,
              color: theme.text.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '—',
            style: TextStyle(
              fontFamily: kSfPro,
              fontFamilyFallback: kSfProFallback,
              fontSize: fs(13, theme.fontScale),
              color: theme.text.tertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(13, theme.fontScale),
                  color: theme.text.secondary,
                ),
                children: [
                  TextSpan(text: deviceLabel),
                  if (appName.isNotEmpty) ...[
                    TextSpan(
                      text: ' · ',
                      style: TextStyle(color: theme.text.tertiary),
                    ),
                    TextSpan(
                      text: appName,
                      style: TextStyle(
                        fontFamily: kSfMono,
                        fontFamilyFallback: kSfMonoFallback,
                        fontSize: fs(12, theme.fontScale),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _SearchPill(onTap: onOpenPalette),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: paused ? 'play' : 'pause',
            label: paused ? 'Resume' : 'Pause',
            tone: paused ? 'warning' : null,
            onTap: connectionManager.toggleStream,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            icon: 'export',
            label: 'Export',
            onTap: session == null ? null : onExport,
          ),
          if (onToggleInspector != null) ...[
            const SizedBox(width: 4),
            _ToolbarButton(
              icon: 'inspector',
              active: inspectorOpen,
              onTap: onToggleInspector,
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.fromLTRB(9, 4, 10, 4),
          decoration: BoxDecoration(
            color: theme.surface.raised,
            border: Border.all(color: theme.border.hairline, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrcaIcon('search', size: 12, color: theme.text.tertiary),
              const SizedBox(width: 7),
              Text(
                'Search or jump to…',
                style: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(12, theme.fontScale),
                  color: theme.text.secondary,
                ),
              ),
              const SizedBox(width: 20),
              const Kbd('⌘K'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final String icon;
  final String? label;
  final String? tone;
  final bool active;
  final VoidCallback? onTap;

  const _ToolbarButton({
    required this.icon,
    this.label,
    this.tone,
    this.active = false,
    this.onTap,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final disabled = widget.onTap == null;
    final bg = widget.active
        ? theme.accent.muted
        : (_hover && !disabled ? theme.surface.hover : Colors.transparent);
    final fg = disabled
        ? theme.text.tertiary
        : widget.tone != null
            ? theme.toneColor(widget.tone!)
            : (widget.active ? theme.accent.base : theme.text.secondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor:
          disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 26,
          padding: EdgeInsets.symmetric(
            horizontal: widget.label == null ? 6 : 9,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
              color: widget.active ? theme.accent.ring : Colors.transparent,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrcaIcon(widget.icon, size: 13, color: fg),
              if (widget.label != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label!,
                  style: TextStyle(
                    fontFamily: kSfPro,
                    fontFamilyFallback: kSfProFallback,
                    fontSize: fs(12, theme.fontScale),
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
