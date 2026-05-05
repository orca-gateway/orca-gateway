import 'package:flutter/material.dart';
import '../models/debug_event.dart';
import '../models/device_session.dart';
import '../theme/theme_provider.dart';
import '../theme/typography.dart';
import '../widgets/primitives/list_filter_bar.dart';
import '../widgets/timeline/waterfall_detail.dart';

/// Two-pane Timeline: left list of requests, right waterfall detail.
class TimelineScreen extends StatefulWidget {
  final DeviceSession session;
  const TimelineScreen({super.key, required this.session});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String? _selectedId;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final entries = _buildEntries(widget.session.eventsByType('timing'));
    final filtered = _query.isEmpty
        ? entries
        : entries
            .where((e) => e.path.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No timing data yet',
          style: TextStyle(
            fontFamily: kSfPro,
            fontFamilyFallback: kSfProFallback,
            fontSize: fs(13, theme.fontScale),
            color: theme.text.tertiary,
          ),
        ),
      );
    }

    final selectedId = _selectedId ?? filtered.firstOrNull?.id;
    final selected = filtered.cast<TimelineEntry?>().firstWhere(
          (e) => e?.id == selectedId,
          orElse: () => filtered.isEmpty ? null : filtered.first,
        ) ??
        entries.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left list — 42% of width.
        Expanded(
          flex: 42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.border.hairline, width: 1),
              ),
            ),
            child: Column(
              children: [
                ListFilterBar(
                  placeholder: 'Filter requests…',
                  right: '${filtered.length} requests',
                  onChanged: (v) => setState(() => _query = v),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final entry = filtered[i];
                      return _TimelineRow(
                        entry: entry,
                        zebra: i.isOdd,
                        selected: entry.id == selectedId,
                        onTap: () =>
                            setState(() => _selectedId = entry.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right detail — 58% of width.
        Expanded(
          flex: 58,
          child: WaterfallDetail(entry: selected),
        ),
      ],
    );
  }

  static List<TimelineEntry> _buildEntries(List<DebugEvent> events) {
    // Most recent first.
    final sorted = [...events]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return [for (final e in sorted) _entryFromEvent(e)];
  }

  static TimelineEntry _entryFromEvent(DebugEvent e) {
    final p = e.payload;
    final server = p['server'] is Map<String, dynamic>
        ? p['server'] as Map<String, dynamic>
        : <String, dynamic>{};
    final client = p['client'] is Map<String, dynamic>
        ? p['client'] as Map<String, dynamic>
        : <String, dynamic>{};

    final path = (server['path'] ?? p['path'])?.toString() ?? '(unknown)';
    final cache = (server['cacheStatus'] ?? p['cacheStatus'])?.toString();
    final componentCount =
        _asInt(server['componentCount'] ?? p['componentCount']);
    final responseSize =
        _asNum(server['responseSizeBytes'] ?? p['responseSizeBytes']);

    // Server stages are already durations (ms).
    const serverOrder = [
      'getInfo',
      'getState',
      'render',
      'flatten',
      'postRender',
    ];
    final serverStages = server['stages'] is Map<String, dynamic>
        ? server['stages'] as Map<String, dynamic>
        : server;
    final tracks = <WaterfallTrack>[];
    double offset = 0;
    for (final key in serverOrder) {
      final d = _asNum(serverStages[key]);
      if (d == null) continue;
      tracks.add(WaterfallTrack(
        key: key,
        isServer: true,
        start: offset,
        duration: d,
      ));
      offset += d;
    }

    // Client stages are cumulative ms from request-start. Convert to
    // sequential durations in the design's 3 buckets: network, parse,
    // widgetBuild (merging the build-queue interval into widgetBuild).
    final network = _asNum(client['responseReceivedMs']);
    final parseCum = _asNum(client['parseCompleteMs']);
    final renderComplete = _asNum(client['renderCompleteMs']) ??
        _asNum(client['firstFrameMs']);

    if (network != null) {
      tracks.add(WaterfallTrack(
        key: 'network',
        isServer: false,
        start: offset,
        duration: network,
      ));
      offset += network;
    }
    if (parseCum != null && network != null) {
      final dur = (parseCum - network).clamp(0, double.infinity).toDouble();
      tracks.add(WaterfallTrack(
        key: 'parse',
        isServer: false,
        start: offset,
        duration: dur,
      ));
      offset += dur;
    }
    if (renderComplete != null) {
      final baseline = parseCum ?? network ?? 0;
      final dur =
          (renderComplete - baseline).clamp(0, double.infinity).toDouble();
      tracks.add(WaterfallTrack(
        key: 'widgetBuild',
        isServer: false,
        start: offset,
        duration: dur,
      ));
      offset += dur;
    }

    final serverMs = tracks
        .where((t) => t.isServer)
        .fold<double>(0, (s, t) => s + t.duration);
    final clientMs = tracks
        .where((t) => !t.isServer)
        .fold<double>(0, (s, t) => s + t.duration);

    return TimelineEntry(
      id: '${e.timestamp}-$path',
      timestampMs: e.timestamp,
      path: path,
      cacheStatus: cache,
      componentCount: componentCount,
      responseSizeBytes: responseSize,
      tracks: tracks,
      totalMs: serverMs + clientMs,
      serverMs: serverMs,
      clientMs: clientMs,
    );
  }

  static double? _asNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class _TimelineRow extends StatefulWidget {
  final TimelineEntry entry;
  final bool zebra;
  final bool selected;
  final VoidCallback onTap;

  const _TimelineRow({
    required this.entry,
    required this.zebra,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<_TimelineRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final e = widget.entry;
    final cacheColor = e.cacheStatus == 'hit'
        ? theme.semantic.success
        : theme.semantic.warning;
    final bg = widget.selected
        ? theme.accent.muted
        : (_hover
            ? theme.surface.hover
            : (widget.zebra ? theme.surface.zebra : Colors.transparent));
    final total = e.totalMs == 0 ? 1 : e.totalMs;
    final serverFrac = (e.serverMs / total).clamp(0.0, 1.0);
    final clientFrac = (e.clientMs / total).clamp(0.0, 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                color: widget.selected
                    ? theme.accent.base
                    : Colors.transparent,
                width: 2,
              ),
              bottom: BorderSide(color: theme.border.divider, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: path · cache · total ms
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      e.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSfMono,
                        fontFamilyFallback: kSfMonoFallback,
                        fontSize: fs(12, theme.fontScale),
                        fontWeight: FontWeight.w600,
                        color: theme.text.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (e.cacheStatus ?? 'NONE').toUpperCase(),
                    style: TextStyle(
                      fontFamily: kSfMono,
                      fontFamilyFallback: kSfMonoFallback,
                      fontSize: fs(10, theme.fontScale),
                      fontWeight: FontWeight.w600,
                      color: cacheColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.totalMs.toInt()} ms',
                    style: TextStyle(
                      fontFamily: kSfMono,
                      fontFamilyFallback: kSfMonoFallback,
                      fontSize: fs(12, theme.fontScale),
                      fontWeight: FontWeight.w600,
                      color: theme.text.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Mini dual-color proportion bar.
              SizedBox(
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Row(
                    children: [
                      Flexible(
                        flex: (serverFrac * 1000).round().clamp(0, 1000),
                        child: Container(
                          color: theme.stage.render.withValues(alpha: 0.85),
                        ),
                      ),
                      Flexible(
                        flex: (clientFrac * 1000).round().clamp(0, 1000),
                        child: Container(
                          color:
                              theme.stage.widgetBuild.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Row 3: totals + relative time.
              DefaultTextStyle.merge(
                style: TextStyle(
                  fontFamily: kSfMono,
                  fontFamilyFallback: kSfMonoFallback,
                  fontSize: fs(10, theme.fontScale),
                  color: theme.text.tertiary,
                ),
                child: Row(
                  children: [
                    Text('server ${e.serverMs.toInt()}ms'),
                    const SizedBox(width: 10),
                    Text('client ${e.clientMs.toInt()}ms'),
                    const Spacer(),
                    Text(_relativeTime(e.timestampMs)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(int ms) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final s = (now - ms) ~/ 1000;
    if (s < 60) return '${s}s ago';
    final m = s ~/ 60;
    if (m < 60) return '${m}m ago';
    final h = m ~/ 60;
    return '${h}h ago';
  }
}
