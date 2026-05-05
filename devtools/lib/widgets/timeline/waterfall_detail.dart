import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../primitives/chip.dart';
import '../primitives/meta_table.dart';
import '../primitives/section_header.dart';

/// A single positioned bar in the waterfall chart.
class WaterfallTrack {
  final String key;
  final bool isServer;
  final double start;
  final double duration;
  const WaterfallTrack({
    required this.key,
    required this.isServer,
    required this.start,
    required this.duration,
  });
}

/// One full timing record surfaced as a detail-pane entry.
class TimelineEntry {
  final String id;
  final int timestampMs;
  final String path;
  final String? cacheStatus;
  final int? componentCount;
  final double? responseSizeBytes;
  final List<WaterfallTrack> tracks;
  final double totalMs;
  final double serverMs;
  final double clientMs;

  const TimelineEntry({
    required this.id,
    required this.timestampMs,
    required this.path,
    required this.cacheStatus,
    required this.componentCount,
    required this.responseSizeBytes,
    required this.tracks,
    required this.totalMs,
    required this.serverMs,
    required this.clientMs,
  });
}

/// Right-pane detail view for a selected timeline entry — Instruments-style
/// waterfall with 8 tracks, time axis + gridlines + hover tooltips.
class WaterfallDetail extends StatelessWidget {
  final TimelineEntry entry;
  const WaterfallDetail({super.key, required this.entry});

  static const List<String> _trackOrder = [
    'getInfo',
    'getState',
    'render',
    'flatten',
    'postRender',
    'network',
    'parse',
    'widgetBuild',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(entry: entry),
          const SizedBox(height: 16),
          const SectionHeader('Waterfall'),
          const SizedBox(height: 10),
          _WaterfallChart(
            tracks: _orderedTracks(),
            totalMs: entry.totalMs,
            theme: theme,
          ),
          const SizedBox(height: 20),
          const SectionHeader('Metadata'),
          const SizedBox(height: 10),
          MetaTable(rows: _metaRows()),
        ],
      ),
    );
  }

  List<WaterfallTrack> _orderedTracks() {
    final byKey = {for (final t in entry.tracks) t.key: t};
    return [
      for (final key in _trackOrder)
        if (byKey.containsKey(key)) byKey[key]!,
    ];
  }

  List<(String, String)> _metaRows() => [
        ('component count', entry.componentCount?.toString() ?? '—'),
        ('response size', _fmtBytes(entry.responseSizeBytes)),
        ('cache status', entry.cacheStatus ?? '—'),
        ('e2e total', '${entry.totalMs.toStringAsFixed(0)} ms'),
        ('server share', '${entry.serverMs.toStringAsFixed(0)} ms'),
        ('client share', '${entry.clientMs.toStringAsFixed(0)} ms'),
      ];
}

class _Header extends StatelessWidget {
  final TimelineEntry entry;
  const _Header({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                entry.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSfMono,
                  fontFamilyFallback: kSfMonoFallback,
                  fontSize: fs(15, theme.fontScale),
                  fontWeight: FontWeight.w600,
                  color: theme.text.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (entry.cacheStatus != null)
              OrcaChip(
                tone: entry.cacheStatus == 'hit' ? 'success' : 'warning',
                label: 'cache ${entry.cacheStatus}',
                size: OrcaChipSize.md,
              ),
            const Spacer(),
            Text(
              _fmtTime(entry.timestampMs),
              style: TextStyle(
                fontFamily: kSfMono,
                fontFamilyFallback: kSfMonoFallback,
                fontSize: fs(11, theme.fontScale),
                color: theme.text.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: kSfPro,
              fontFamilyFallback: kSfProFallback,
              fontSize: fs(11, theme.fontScale),
              color: theme.text.secondary,
            ),
            children: [
              const TextSpan(text: 'End-to-end '),
              TextSpan(
                text: '${entry.totalMs.toStringAsFixed(0)} ms',
                style: TextStyle(
                  fontFamily: kSfMono,
                  fontFamilyFallback: kSfMonoFallback,
                  fontWeight: FontWeight.w700,
                  color: theme.text.primary,
                ),
              ),
              TextSpan(
                text: '  ·  ',
                style: TextStyle(color: theme.text.tertiary),
              ),
              TextSpan(
                text: '${entry.componentCount ?? '—'} components',
              ),
              TextSpan(
                text: '  ·  ',
                style: TextStyle(color: theme.text.tertiary),
              ),
              TextSpan(text: _fmtBytes(entry.responseSizeBytes)),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaterfallChart extends StatelessWidget {
  final List<WaterfallTrack> tracks;
  final double totalMs;
  final OrcaTheme theme;

  const _WaterfallChart({
    required this.tracks,
    required this.totalMs,
    required this.theme,
  });

  static const double _labelColumnWidth = 130;
  static const double _rightPad = 32;
  static const double _rowHeight = 22;
  static const double _axisHeight = 18;

  List<double> _ticks() {
    if (totalMs <= 0) return [0];
    final step = totalMs > 400 ? 100.0 : (totalMs > 200 ? 50.0 : 25.0);
    final ticks = <double>[];
    for (var v = 0.0; v <= totalMs; v += step) {
      ticks.add(v);
    }
    return ticks;
  }

  @override
  Widget build(BuildContext context) {
    final ticks = _ticks();
    return LayoutBuilder(
      builder: (context, c) {
        final barArea =
            (c.maxWidth - _labelColumnWidth - _rightPad).clamp(1.0, c.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time axis
            SizedBox(
              height: _axisHeight,
              child: Row(
                children: [
                  SizedBox(width: _labelColumnWidth),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: _rightPad),
                      child: _AxisTicks(
                        ticks: ticks,
                        totalMs: totalMs,
                        theme: theme,
                      ),
                    ),
                  ),
                  const SizedBox(width: _rightPad),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Tracks
            for (final track in tracks)
              SizedBox(
                height: _rowHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: _labelColumnWidth - 10,
                      child: _TrackLabel(track: track, theme: theme),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: barArea,
                      child: _TrackBar(
                        track: track,
                        totalMs: totalMs,
                        ticks: ticks,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: _rightPad),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AxisTicks extends StatelessWidget {
  final List<double> ticks;
  final double totalMs;
  final OrcaTheme theme;

  const _AxisTicks({
    required this.ticks,
    required this.totalMs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final v in ticks)
              Positioned(
                left: (v / (totalMs == 0 ? 1 : totalMs)) * c.maxWidth - 20,
                top: 0,
                width: 40,
                child: Text(
                  '${v.toInt()}ms',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kSfMono,
                    fontFamilyFallback: kSfMonoFallback,
                    fontSize: fs(9.5, theme.fontScale),
                    color: theme.text.tertiary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TrackLabel extends StatelessWidget {
  final WaterfallTrack track;
  final OrcaTheme theme;

  const _TrackLabel({required this.track, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: kSfMono,
            fontFamilyFallback: kSfMonoFallback,
            fontSize: fs(10.5, theme.fontScale),
            color: theme.text.secondary,
            letterSpacing: 0.2,
          ),
          children: [
            TextSpan(
              text: track.isServer ? 'srv ' : 'cli ',
              style: TextStyle(color: theme.text.tertiary),
            ),
            TextSpan(text: track.key),
          ],
        ),
      ),
    );
  }
}

class _TrackBar extends StatelessWidget {
  final WaterfallTrack track;
  final double totalMs;
  final List<double> ticks;
  final OrcaTheme theme;

  const _TrackBar({
    required this.track,
    required this.totalMs,
    required this.ticks,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = theme.stage.byKey(track.key);
    return LayoutBuilder(
      builder: (context, c) {
        final total = totalMs == 0 ? 1 : totalMs;
        final barLeft = (track.start / total) * c.maxWidth;
        final barWidth = ((track.duration / total) * c.maxWidth).clamp(
          2.0,
          c.maxWidth,
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Gridlines behind the bar.
            Positioned.fill(
              child: CustomPaint(
                painter: _GridlinesPainter(
                  ticks: ticks,
                  totalMs: total.toDouble(),
                  color: theme.border.divider,
                ),
              ),
            ),
            // Bar with hover tooltip.
            Positioned(
              left: barLeft,
              top: 3,
              bottom: 3,
              width: barWidth,
              child: Tooltip(
                message:
                    '${track.key}\nstart ${track.start.toInt()}ms · ${track.duration.toInt()}ms',
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 5),
                  child: track.duration > 20
                      ? Text(
                          track.duration.toInt().toString(),
                          style: TextStyle(
                            fontFamily: kSfMono,
                            fontFamilyFallback: kSfMonoFallback,
                            fontSize: fs(9.5, theme.fontScale),
                            fontWeight: FontWeight.w600,
                            color: theme.isDark
                                ? const Color(0xFF0A0A0A)
                                : const Color(0xFFFFFFFF),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GridlinesPainter extends CustomPainter {
  final List<double> ticks;
  final double totalMs;
  final Color color;

  _GridlinesPainter({
    required this.ticks,
    required this.totalMs,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final v in ticks) {
      final x = (v / totalMs) * size.width;
      _drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 3.0;
    const gap = 3.0;
    final dy = (to.dy - from.dy).abs();
    var y = from.dy;
    while (y < from.dy + dy) {
      final next = (y + dash).clamp(from.dy, from.dy + dy);
      canvas.drawLine(Offset(from.dx, y), Offset(from.dx, next), paint);
      y = next + gap;
    }
  }

  @override
  bool shouldRepaint(_GridlinesPainter old) =>
      old.ticks != ticks || old.totalMs != totalMs || old.color != color;
}

// ─── utility helpers shared across file ─────────────────────────

String _fmtBytes(double? bytes) {
  if (bytes == null) return '—';
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _fmtTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String p(int n) => n.toString().padLeft(2, '0');
  String pp(int n) => n.toString().padLeft(3, '0');
  return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${pp(d.millisecond)}';
}
