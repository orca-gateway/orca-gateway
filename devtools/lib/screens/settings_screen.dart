import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../theme/theme_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/primitives/orca_icon.dart';
import '../widgets/primitives/segmented_control.dart';
import '../widgets/primitives/toggle.dart';

const String kSettingsVersion = '0.9.2';
const String kSettingsBuild = '214';
const String kSettingsProtocol = 'orca-ws/3';

/// Side-nav Settings screen with four sections.
/// Keeps the original `(settings, onRestartServer)` signature so the rest of
/// the app wiring doesn't change.
class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onRestartServer;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onRestartServer,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _section = 'general';

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.border.hairline, width: 1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final nav in _sections)
                    _SideNavItem(
                      id: nav.$1,
                      label: nav.$2,
                      icon: nav.$3,
                      selected: _section == nav.$1,
                      onTap: () => setState(() => _section = nav.$1),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
            child: _sectionContent(),
          ),
        ),
      ],
    );
  }

  static const _sections = [
    ('general', 'General', 'settings'),
    ('server', 'Server', 'network'),
    ('export', 'Export', 'export'),
    ('about', 'About', 'dot'),
  ];

  Widget _sectionContent() {
    switch (_section) {
      case 'general':
        return _GeneralSection(settings: widget.settings);
      case 'server':
        return _ServerSection(
          settings: widget.settings,
          onRestart: widget.onRestartServer,
        );
      case 'export':
        return _ExportSection(settings: widget.settings);
      case 'about':
        return const _AboutSection();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SideNavItem extends StatefulWidget {
  final String id;
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final bg = widget.selected
        ? theme.accent.muted
        : (_hover ? theme.surface.hover : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              OrcaIcon(
                widget.icon,
                size: 13,
                color: widget.selected
                    ? theme.accent.base
                    : theme.text.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(12.5, theme.fontScale),
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.selected
                      ? theme.accent.base
                      : theme.text.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared section layout primitives ──────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: kSfPro,
          fontFamilyFallback: kSfProFallback,
          fontSize: fs(16, theme.fontScale),
          fontWeight: FontWeight.w600,
          color: theme.text.primary,
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String? help;
  final Widget child;

  const _SettingRow({
    required this.label,
    required this.child,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(12.5, theme.fontScale),
                  color: theme.text.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.centerLeft, child: child),
                if (help != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    help!,
                    style: TextStyle(
                      fontFamily: kSfPro,
                      fontFamilyFallback: kSfProFallback,
                      fontSize: fs(11, theme.fontScale),
                      color: theme.text.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section: General ──────────────────────────────────────────

class _GeneralSection extends StatelessWidget {
  final AppSettings settings;
  const _GeneralSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(title: 'General'),
            _SettingRow(
              label: 'Appearance',
              help: 'Theme follows macOS by default; override here.',
              child: OrcaSegmentedControl<OrcaThemeMode>(
                options: const [
                  (OrcaThemeMode.system, 'System'),
                  (OrcaThemeMode.light, 'Light'),
                  (OrcaThemeMode.dark, 'Dark'),
                ],
                value: settings.themeMode,
                onChanged: settings.setThemeMode,
              ),
            ),
            _SettingRow(
              label: 'Accent',
              child: OrcaSegmentedControl<OrcaAccent>(
                options: const [
                  (OrcaAccent.teal, 'Teal'),
                  (OrcaAccent.blue, 'Blue'),
                  (OrcaAccent.graphite, 'Graphite'),
                ],
                value: settings.accent,
                onChanged: settings.setAccent,
              ),
            ),
            _SettingRow(
              label: 'Row density',
              child: OrcaSegmentedControl<OrcaDensity>(
                options: const [
                  (OrcaDensity.comfy, 'Comfy'),
                  (OrcaDensity.regular, 'Default'),
                  (OrcaDensity.compact, 'Compact'),
                ],
                value: settings.density,
                onChanged: settings.setDensity,
              ),
            ),
            _SettingRow(
              label: 'Data font size',
              help:
                  '${(settings.fontScale * 12).round()}pt default · '
                  '${(settings.fontScale * 11).round()}pt in tables',
              child: SizedBox(
                width: 220,
                child: Slider(
                  value: settings.fontScale,
                  min: 0.85,
                  max: 1.2,
                  divisions: 7,
                  activeColor: OrcaThemeScope.of(context).accent.base,
                  onChanged: settings.setFontScale,
                ),
              ),
            ),
            _SettingRow(
              label: 'Sidebar translucency',
              help:
                  'Disable for a solid sidebar on slow hardware. Real macOS '
                  'vibrancy lands with the native-window integration.',
              child: OrcaToggle(
                value: settings.translucent,
                onChanged: settings.setTranslucent,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Section: Server ───────────────────────────────────────────

class _ServerSection extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onRestart;

  const _ServerSection({required this.settings, required this.onRestart});

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<_ServerSection> {
  late final TextEditingController _portCtrl =
      TextEditingController(text: widget.settings.port.toString());

  @override
  void dispose() {
    _portCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final port = int.tryParse(_portCtrl.text);
    if (port == null || port < 1 || port > 65535) return;
    widget.settings.setPort(port);
    widget.onRestart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WebSocket server restarted on port $port')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'WebSocket Server'),
        _SettingRow(
          label: 'Listen port',
          help: 'Default 6363. Restart server to apply.',
          child: SizedBox(
            width: 120,
            child: _MonoField(
              controller: _portCtrl,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ),
        _SettingRow(
          label: 'Max event buffer',
          help: 'Per-device in-memory cap before dropping.',
          child: SizedBox(
            width: 120,
            child: _MonoField(
              controller: TextEditingController(text: '5000'),
              readOnly: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _apply,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accent.base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Apply & Restart',
                    style: TextStyle(
                      fontFamily: kSfPro,
                      fontFamilyFallback: kSfProFallback,
                      fontSize: fs(12.5, theme.fontScale),
                      fontWeight: FontWeight.w600,
                      color: theme.text.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Section: Export ───────────────────────────────────────────

class _ExportSection extends StatefulWidget {
  final AppSettings settings;
  const _ExportSection({required this.settings});

  @override
  State<_ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends State<_ExportSection> {
  late final TextEditingController _dirCtrl = TextEditingController(
    text: widget.settings.exportDirectory.isEmpty
        ? Directory.current.path
        : widget.settings.exportDirectory,
  );

  @override
  void dispose() {
    _dirCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      _dirCtrl.text = result;
      widget.settings.setExportDirectory(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Session Export'),
        _SettingRow(
          label: 'Destination',
          help: 'Exported sessions are JSON files.',
          child: Row(
            children: [
              Expanded(
                child: _MonoField(
                  controller: _dirCtrl,
                  onSubmitted: widget.settings.setExportDirectory,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _pick,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.surface.raised,
                    border: Border.all(color: theme.border.hairline, width: 1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'Choose…',
                    style: TextStyle(
                      fontFamily: kSfPro,
                      fontFamilyFallback: kSfProFallback,
                      fontSize: fs(12, theme.fontScale),
                      color: theme.text.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _SettingRow(
          label: 'Filename format',
          child: _MonoField(
            controller: TextEditingController(
              text: 'orca-debug-{device}-{ts}.json',
            ),
            readOnly: true,
          ),
        ),
      ],
    );
  }
}

// ─── Section: About ────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final body = TextStyle(
      fontFamily: kSfPro,
      fontFamilyFallback: kSfProFallback,
      fontSize: fs(12.5, theme.fontScale),
      color: theme.text.secondary,
      height: 1.7,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'About'),
        RichText(
          text: TextSpan(
            style: body,
            children: [
              TextSpan(
                text: 'Orca DevTools ',
                style: body.copyWith(
                  color: theme.text.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: '$kSettingsVersion (build $kSettingsBuild)\n'),
              const TextSpan(text: 'Flutter Desktop · macOS / Linux / Windows\n'),
              TextSpan(text: 'Protocol: $kSettingsProtocol\n\n'),
              const TextSpan(
                text: 'Debug companion for apps using the Orca Gateway SDK. '
                    'Connect a device by pointing the SDK at this machine\'s '
                    'IP on the configured port.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonoField extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  const _MonoField({
    required this.controller,
    this.readOnly = false,
    this.onSubmitted,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      cursorColor: theme.accent.base,
      style: TextStyle(
        fontFamily: kSfMono,
        fontFamilyFallback: kSfMonoFallback,
        fontSize: fs(12, theme.fontScale),
        color: theme.text.primary,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: true,
        fillColor: theme.surface.content,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.border.hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.border.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.accent.base, width: 1),
        ),
      ),
    );
  }
}
