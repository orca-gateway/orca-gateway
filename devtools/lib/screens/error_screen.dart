import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/debug_event.dart';
import '../models/device_session.dart';
import '../theme/theme_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/primitives/chip.dart';
import '../widgets/primitives/empty_state.dart';
import '../widgets/primitives/orca_icon.dart';

/// Card-list Errors view with severity strip + expand-for-stack.
class ErrorScreen extends StatefulWidget {
  final DeviceSession session;
  const ErrorScreen({super.key, required this.session});

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  final Set<String> _expanded = <String>{};
  final Set<String> _cleared = <String>{};

  void _toggle(String id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  void _clearAll(Iterable<String> ids) {
    setState(() => _cleared.addAll(ids));
  }

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final entries = _buildEntries(widget.session.eventsByType('error'))
        .where((e) => !_cleared.contains(e.id))
        .toList();

    if (entries.isEmpty) {
      return const EmptyState(
        icon: 'errors',
        title: 'No errors',
        body: 'Runtime errors will appear here.',
      );
    }

    final dangerCount = entries.where((e) => e.severity == 'danger').length;
    final warningCount = entries.where((e) => e.severity == 'warning').length;

    // Auto-expand the first card so the user sees a populated state.
    if (_expanded.isEmpty && entries.isNotEmpty) {
      _expanded.add(entries.first.id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryBar(
          theme: theme,
          dangerCount: dangerCount,
          warningCount: warningCount,
          onClearAll: () => _clearAll(entries.map((e) => e.id)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = entries[i];
              return _ErrorCard(
                entry: e,
                expanded: _expanded.contains(e.id),
                onToggle: () => _toggle(e.id),
              );
            },
          ),
        ),
      ],
    );
  }

  static List<_ErrorEntry> _buildEntries(List<DebugEvent> events) {
    final sorted = [...events]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return [for (final e in sorted) _ErrorEntry.from(e)];
  }
}

class _ErrorEntry {
  final String id;
  final int timestampMs;
  final String message;
  final String? context;
  final List<String> stack;
  final String severity;

  const _ErrorEntry({
    required this.id,
    required this.timestampMs,
    required this.message,
    required this.context,
    required this.stack,
    required this.severity,
  });

  factory _ErrorEntry.from(DebugEvent e) {
    final p = e.payload;
    final msg = p['message']?.toString() ?? 'Unknown error';
    final ctx = p['context']?.toString();
    final trace = p['stackTrace']?.toString();
    final severity = _inferSeverity(msg, ctx);
    return _ErrorEntry(
      id: '${e.timestamp}-$msg',
      timestampMs: e.timestamp,
      message: msg,
      context: ctx,
      stack: trace == null ? const [] : trace.split('\n'),
      severity: severity,
    );
  }

  static String _inferSeverity(String message, String? context) {
    final haystack = '$message ${context ?? ''}'.toLowerCase();
    if (haystack.contains('warn') ||
        haystack.contains('notfound') ||
        haystack.contains('404')) {
      return 'warning';
    }
    return 'danger';
  }
}

class _SummaryBar extends StatelessWidget {
  final OrcaTheme theme;
  final int dangerCount;
  final int warningCount;
  final VoidCallback onClearAll;

  const _SummaryBar({
    required this.theme,
    required this.dangerCount,
    required this.warningCount,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: kSfPro,
      fontFamilyFallback: kSfProFallback,
      fontSize: fs(12, theme.fontScale),
      color: theme.text.secondary,
    );
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              style: style,
              children: [
                TextSpan(
                  text: '$dangerCount',
                  style: style.copyWith(
                    color: theme.semantic.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' errors'),
                TextSpan(
                  text: '  ·  ',
                  style: style.copyWith(color: theme.text.tertiary),
                ),
                TextSpan(
                  text: '$warningCount',
                  style: style.copyWith(
                    color: theme.semantic.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' warnings'),
              ],
            ),
          ),
          const Spacer(),
          _ToolbarInlineButton(
            icon: 'clear',
            label: 'Clear all',
            onTap: onClearAll,
          ),
        ],
      ),
    );
  }
}

class _ToolbarInlineButton extends StatefulWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarInlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ToolbarInlineButton> createState() => _ToolbarInlineButtonState();
}

class _ToolbarInlineButtonState extends State<_ToolbarInlineButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: _hover ? theme.surface.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrcaIcon(widget.icon, size: 12, color: theme.text.secondary),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(12, theme.fontScale),
                  color: theme.text.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatefulWidget {
  final _ErrorEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  const _ErrorCard({
    required this.entry,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final tone = widget.entry.severity == 'warning'
        ? theme.semantic.warning
        : theme.semantic.danger;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface.raised,
        border: Border.all(color: theme.border.hairline, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Severity strip — its own Container so the outer border stays
            // uniform. Non-uniform borders + borderRadius trigger a Flutter
            // renderer fallback that can collapse child layout silently.
            Container(width: 3, color: tone),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(theme, tone),
                  if (widget.expanded && widget.entry.stack.isNotEmpty)
                    _buildStack(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(OrcaTheme theme, Color tone) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hover ? theme.surface.hover : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: OrcaIcon('errors', size: 14, color: tone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.entry.message,
                      style: TextStyle(
                        fontFamily: kSfMono,
                        fontFamilyFallback: kSfMonoFallback,
                        fontSize: fs(12.5, theme.fontScale),
                        fontWeight: FontWeight.w600,
                        color: theme.text.primary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.entry.context != null)
                          OrcaChip(
                            tone: widget.entry.severity,
                            label: widget.entry.context!,
                            size: OrcaChipSize.sm,
                          ),
                        Text(
                          _relativeTime(widget.entry.timestampMs),
                          style: TextStyle(
                            fontFamily: kSfMono,
                            fontFamilyFallback: kSfMonoFallback,
                            fontSize: fs(11, theme.fontScale),
                            color: theme.text.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: _hover ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HoverButton(
                      icon: 'copy',
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                          text:
                              '${widget.entry.message}\n${widget.entry.stack.join('\n')}',
                        ));
                      },
                    ),
                    const SizedBox(width: 2),
                    _HoverButton(
                      icon: 'open-external',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              OrcaIcon(
                widget.expanded ? 'chevron-down' : 'chevron-right',
                size: 12,
                color: theme.text.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStack(OrcaTheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(38, 10, 14, 14),
      decoration: BoxDecoration(
        color: theme.surface.content,
        border: Border(
          top: BorderSide(color: theme.border.divider, width: 1),
        ),
      ),
      child: SelectableText(
        widget.entry.stack.join('\n'),
        style: TextStyle(
          fontFamily: kSfMono,
          fontFamilyFallback: kSfMonoFallback,
          fontSize: fs(11, theme.fontScale),
          color: theme.text.secondary,
          height: 1.6,
        ),
      ),
    );
  }

  static String _relativeTime(int ms) {
    final s = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
    if (s < 60) return '${s}s ago';
    final m = s ~/ 60;
    if (m < 60) return '${m}m ago';
    final h = m ~/ 60;
    return '${h}h ago';
  }
}

class _HoverButton extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;

  const _HoverButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: OrcaIcon(icon, size: 12, color: theme.text.secondary),
        ),
      ),
    );
  }
}
