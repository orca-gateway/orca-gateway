import 'package:flutter/material.dart';
import '../models/debug_event.dart';
import '../models/device_session.dart';
import '../theme/theme_provider.dart';
import '../theme/typography.dart';
import '../widgets/network/network_inspector.dart';
import '../widgets/primitives/chip.dart';
import '../widgets/primitives/empty_state.dart';
import '../widgets/primitives/list_filter_bar.dart';
import '../widgets/primitives/table_header.dart';

class NetworkScreen extends StatefulWidget {
  final DeviceSession session;
  const NetworkScreen({super.key, required this.session});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  String? _selectedId;
  String _filter = '';
  bool _inspectorOpen = true;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries(widget.session.eventsByType('network'));
    if (entries.isEmpty) {
      return const EmptyState(
        icon: 'network',
        title: 'No network requests yet',
        body: 'HTTP traffic from the SDK will appear here.',
      );
    }
    final filtered = _filter.isEmpty
        ? entries
        : entries.where((e) => _matches(e, _filter)).toList();
    final selectedId = _selectedId ?? filtered.firstOrNull?.id;
    final selected = filtered.cast<NetworkEntry?>().firstWhere(
              (e) => e?.id == selectedId,
              orElse: () => filtered.isEmpty ? null : filtered.first,
            ) ??
        entries.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              ListFilterBar(
                placeholder: 'Filter requests (method, path, status)…',
                right: '${filtered.length} requests',
                onChanged: (v) => setState(() => _filter = v),
              ),
              const TableHeader(columns: [
                TableColumn(label: 'method', width: 70),
                TableColumn(label: 'status', width: 60),
                TableColumn(label: 'path'),
                TableColumn(label: 'host', width: 170),
                TableColumn(
                  label: 'duration',
                  width: 80,
                  align: TextAlign.right,
                ),
                TableColumn(label: 'size', width: 72, align: TextAlign.right),
                TableColumn(label: 'time', width: 92, align: TextAlign.right),
              ]),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final e = filtered[i];
                    return _NetworkRow(
                      entry: e,
                      zebra: i.isOdd,
                      selected: e.id == selectedId,
                      onTap: () => setState(() {
                        _selectedId = e.id;
                        _inspectorOpen = true;
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (_inspectorOpen)
          NetworkInspector(
            entry: selected,
            onClose: () => setState(() => _inspectorOpen = false),
          ),
      ],
    );
  }

  static bool _matches(NetworkEntry e, String q) {
    final needle = q.toLowerCase();
    return e.method.toLowerCase().contains(needle) ||
        e.path.toLowerCase().contains(needle) ||
        e.host.toLowerCase().contains(needle) ||
        e.statusCode.toString().contains(needle);
  }

  static List<NetworkEntry> _buildEntries(List<DebugEvent> events) {
    final sorted = [...events]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return [for (final e in sorted) _entryFromEvent(e)];
  }

  static NetworkEntry _entryFromEvent(DebugEvent e) {
    final p = e.payload;
    final rawUrl = p['url']?.toString() ?? '';
    Uri? uri;
    try {
      uri = Uri.parse(rawUrl);
    } catch (_) {}
    final host = uri?.host ?? '';
    final pathPart = uri?.hasEmptyPath == false
        ? (uri!.path + (uri.hasQuery ? '?${uri.query}' : ''))
        : rawUrl;
    final method = p['method']?.toString() ?? 'GET';
    final status =
        (p['statusCode'] as num?)?.toInt() ?? int.tryParse('${p['statusCode']}') ?? 0;
    final dur =
        (p['durationMs'] as num?)?.toDouble() ?? double.tryParse('${p['durationMs']}') ?? 0.0;
    final respSize = (p['responseSizeBytes'] as num?)?.toInt();

    Map<String, String>? headerMap(dynamic raw) {
      if (raw is! Map) return null;
      final out = <String, String>{};
      for (final entry in raw.entries) {
        out[entry.key.toString()] = entry.value?.toString() ?? '';
      }
      return out.isEmpty ? null : out;
    }

    final phases = p['phases'] is List
        ? List<Map<String, dynamic>>.from(
            (p['phases'] as List).whereType<Map>().map(
                  (m) => Map<String, dynamic>.from(m),
                ),
          )
        : null;

    return NetworkEntry(
      id: '${e.timestamp}-$rawUrl',
      timestampMs: e.timestamp,
      method: method,
      host: host,
      path: pathPart,
      statusCode: status,
      durationMs: dur,
      responseSizeBytes: respSize,
      requestHeaders: headerMap(p['requestHeaders']),
      responseHeaders: headerMap(p['responseHeaders']),
      requestBody: p['requestBody'],
      responseBody: p['responseBody'],
      phases: phases,
    );
  }
}

class _NetworkRow extends StatefulWidget {
  final NetworkEntry entry;
  final bool zebra;
  final bool selected;
  final VoidCallback onTap;

  const _NetworkRow({
    required this.entry,
    required this.zebra,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NetworkRow> createState() => _NetworkRowState();
}

class _NetworkRowState extends State<_NetworkRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final e = widget.entry;
    final bg = widget.selected
        ? theme.accent.muted
        : (_hover
            ? theme.surface.hover
            : (widget.zebra ? theme.surface.zebra : Colors.transparent));
    final statusColor = theme.toneColor(statusTone(e.statusCode));
    final monoStyle = TextStyle(
      fontFamily: kSfMono,
      fontFamilyFallback: kSfMonoFallback,
      fontSize: fs(11.5, theme.fontScale),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: theme.density.tableRow,
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OrcaChip(
                    tone: methodTone(e.method),
                    label: e.method,
                    size: OrcaChipSize.sm,
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  e.statusCode == 0 ? '—' : '${e.statusCode}',
                  style: monoStyle.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  e.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle.copyWith(color: theme.text.primary),
                ),
              ),
              SizedBox(
                width: 170,
                child: Text(
                  e.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle.copyWith(color: theme.text.secondary),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '${e.durationMs.toStringAsFixed(0)} ms',
                  textAlign: TextAlign.right,
                  style: monoStyle.copyWith(color: theme.text.primary),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  _fmtBytes(e.responseSizeBytes),
                  textAlign: TextAlign.right,
                  style: monoStyle.copyWith(color: theme.text.secondary),
                ),
              ),
              SizedBox(
                width: 92,
                child: Text(
                  _fmtTime(e.timestampMs),
                  textAlign: TextAlign.right,
                  style: monoStyle.copyWith(color: theme.text.tertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _fmtTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String p(int n) => n.toString().padLeft(2, '0');
    String pp(int n) => n.toString().padLeft(3, '0');
    return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${pp(d.millisecond)}';
  }
}
