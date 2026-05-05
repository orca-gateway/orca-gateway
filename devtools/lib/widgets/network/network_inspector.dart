import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../primitives/chip.dart';
import '../primitives/json_viewer.dart';
import '../primitives/orca_icon.dart';

/// A single parsed network request row, shared by the table and the inspector.
class NetworkEntry {
  final String id;
  final int timestampMs;
  final String method;
  final String host;
  final String path;
  final int statusCode;
  final double durationMs;
  final int? responseSizeBytes;
  final Map<String, String>? requestHeaders;
  final Map<String, String>? responseHeaders;
  final dynamic requestBody;
  final dynamic responseBody;
  final List<Map<String, dynamic>>? phases;

  const NetworkEntry({
    required this.id,
    required this.timestampMs,
    required this.method,
    required this.host,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    required this.responseSizeBytes,
    required this.requestHeaders,
    required this.responseHeaders,
    required this.requestBody,
    required this.responseBody,
    required this.phases,
  });
}

/// HTTP-method → chip tone.
String methodTone(String method) {
  switch (method.toUpperCase()) {
    case 'POST':
      return 'success';
    case 'PATCH':
    case 'PUT':
      return 'scopePage';
    case 'DELETE':
      return 'danger';
    case 'GET':
    default:
      return 'info';
  }
}

/// HTTP status-code → chip tone.
String statusTone(int status) {
  if (status >= 500) return 'danger';
  if (status >= 400) return 'warning';
  if (status >= 300) return 'info';
  if (status >= 200) return 'success';
  return 'info';
}

/// 320px right-pane inspector for a selected request, with Headers / Body /
/// Timing tabs. Phase 4 ships the layout; Phase 5 fills the three tabs with
/// real SDK-emitted headers, bodies, and phase durations.
class NetworkInspector extends StatefulWidget {
  final NetworkEntry entry;
  final VoidCallback onClose;

  const NetworkInspector({
    super.key,
    required this.entry,
    required this.onClose,
  });

  @override
  State<NetworkInspector> createState() => _NetworkInspectorState();
}

class _NetworkInspectorState extends State<NetworkInspector> {
  String _tab = 'headers';

  @override
  void didUpdateWidget(NetworkInspector old) {
    super.didUpdateWidget(old);
    if (old.entry.id != widget.entry.id) {
      _tab = 'headers';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final entry = widget.entry;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: theme.surface.raised,
        border: Border(
          left: BorderSide(color: theme.border.hairline, width: 1),
        ),
        boxShadow: theme.floatShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(entry: entry, onClose: widget.onClose),
          _MetaRow(entry: entry),
          _Tabs(current: _tab, onChange: (t) => setState(() => _tab = t)),
          Expanded(
            child: _TabContent(tab: _tab, entry: entry),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final NetworkEntry entry;
  final VoidCallback onClose;

  const _Header({required this.entry, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          OrcaChip(
            tone: methodTone(entry.method),
            label: entry.method,
            size: OrcaChipSize.sm,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kSfMono,
                fontFamilyFallback: kSfMonoFallback,
                fontSize: fs(12.5, theme.fontScale),
                fontWeight: FontWeight.w600,
                color: theme.text.primary,
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child:
                    OrcaIcon('close', size: 12, color: theme.text.tertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final NetworkEntry entry;
  const _MetaRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final monoStyle = TextStyle(
      fontFamily: kSfMono,
      fontFamilyFallback: kSfMonoFallback,
      fontSize: fs(11, theme.fontScale),
      color: theme.text.secondary,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${entry.statusCode}',
            style: monoStyle.copyWith(
              color: theme.toneColor(statusTone(entry.statusCode)),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text('·', style: TextStyle(color: theme.text.tertiary)),
          const SizedBox(width: 10),
          Text('${entry.durationMs.toStringAsFixed(0)}ms', style: monoStyle),
          const SizedBox(width: 10),
          Text('·', style: TextStyle(color: theme.text.tertiary)),
          const SizedBox(width: 10),
          Text(_fmtBytes(entry.responseSizeBytes), style: monoStyle),
          const Spacer(),
          Text(
            _fmtTime(entry.timestampMs),
            style: monoStyle.copyWith(color: theme.text.tertiary),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChange;
  const _Tabs({required this.current, required this.onChange});

  static const _ids = ['headers', 'body', 'timing'];

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (final id in _ids) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onChange(id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: current == id
                            ? theme.accent.base
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    id[0].toUpperCase() + id.substring(1),
                    style: TextStyle(
                      fontFamily: kSfPro,
                      fontFamilyFallback: kSfProFallback,
                      fontSize: fs(12, theme.fontScale),
                      fontWeight: current == id
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: current == id
                          ? theme.text.primary
                          : theme.text.secondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
          ],
        ],
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  final String tab;
  final NetworkEntry entry;

  const _TabContent({required this.tab, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    switch (tab) {
      case 'headers':
        final headers = entry.responseHeaders ?? entry.requestHeaders;
        if (headers == null || headers.isEmpty) {
          return _PlaceholderMessage(
            theme: theme,
            message: 'Headers are not yet emitted over the wire.\n'
                'Coming in protocol v4.',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < headers.length; i++)
                _HeaderRow(
                  name: headers.keys.elementAt(i),
                  value: headers.values.elementAt(i),
                  isLast: i == headers.length - 1,
                  theme: theme,
                ),
            ],
          ),
        );
      case 'body':
        final body = entry.responseBody ?? entry.requestBody;
        if (body == null) {
          return _PlaceholderMessage(
            theme: theme,
            message:
                'Bodies are not captured by default.\n\n'
                'Pass `includeBodies: true` to OrcaDebugConfig when calling '
                'OrcaDebug.init:\n\n'
                'OrcaDebug.init(OrcaDebugConfig(\n'
                '  enabled: true,\n'
                '  includeBodies: true,\n'
                '));\n\n'
                'Bodies commonly contain auth tokens or PII, so this is '
                'off unless you explicitly opt in.',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: JsonViewer(value: body),
        );
      case 'timing':
        final phases = entry.phases;
        if (phases == null || phases.isEmpty) {
          return _PlaceholderMessage(
            theme: theme,
            message:
                'Per-phase timings (dns, connect, tls, wait, download) land '
                'with protocol v4.',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: _PhaseBars(
            phases: phases,
            totalMs: entry.durationMs,
            theme: theme,
          ),
        );
    }
    return const SizedBox.shrink();
  }
}

class _HeaderRow extends StatelessWidget {
  final String name;
  final String value;
  final bool isLast;
  final OrcaTheme theme;

  const _HeaderRow({
    required this.name,
    required this.value,
    required this.isLast,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: theme.border.divider, width: 1),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontFamily: kSfMono,
              fontFamilyFallback: kSfMonoFallback,
              fontSize: fs(10, theme.fontScale),
              color: theme.text.tertiary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: kSfMono,
              fontFamilyFallback: kSfMonoFallback,
              fontSize: fs(11, theme.fontScale),
              color: theme.text.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseBars extends StatelessWidget {
  final List<Map<String, dynamic>> phases;
  final double totalMs;
  final OrcaTheme theme;

  const _PhaseBars({
    required this.phases,
    required this.totalMs,
    required this.theme,
  });

  static const _phaseStageKeys = [
    'getInfo',
    'getState',
    'render',
    'flatten',
    'postRender',
    'network',
  ];

  @override
  Widget build(BuildContext context) {
    final sum = phases.fold<double>(
      0,
      (s, p) => s + ((p['durationMs'] ?? p['dur']) as num? ?? 0).toDouble(),
    );
    final scale = sum == 0 ? 1 : sum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < phases.length; i++)
          _PhaseRow(
            phase: phases[i],
            scaleMs: scale.toDouble(),
            colorKey: _phaseStageKeys[i % _phaseStageKeys.length],
            theme: theme,
          ),
      ],
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final Map<String, dynamic> phase;
  final double scaleMs;
  final String colorKey;
  final OrcaTheme theme;

  const _PhaseRow({
    required this.phase,
    required this.scaleMs,
    required this.colorKey,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final name = phase['phase']?.toString() ?? '—';
    final dur = ((phase['durationMs'] ?? phase['dur']) as num? ?? 0).toDouble();
    final pct = (dur / scaleMs).clamp(0.0, 1.0);
    final monoStyle = TextStyle(
      fontFamily: kSfMono,
      fontFamilyFallback: kSfMonoFallback,
      fontSize: fs(11, theme.fontScale),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              name,
              style: monoStyle.copyWith(color: theme.text.secondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: theme.surface.content,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.stage.byKey(colorKey),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '${dur.toStringAsFixed(0)} ms',
              textAlign: TextAlign.right,
              style: monoStyle.copyWith(
                color: theme.text.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderMessage extends StatelessWidget {
  final OrcaTheme theme;
  final String message;

  const _PlaceholderMessage({required this.theme, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSfPro,
            fontFamilyFallback: kSfProFallback,
            fontSize: fs(12, theme.fontScale),
            color: theme.text.tertiary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

String _fmtBytes(int? bytes) {
  if (bytes == null) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _fmtTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String p(int n) => n.toString().padLeft(2, '0');
  String pp(int n) => n.toString().padLeft(3, '0');
  return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${pp(d.millisecond)}';
}
