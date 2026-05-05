import 'package:flutter/material.dart';
import '../models/debug_event.dart';
import '../models/device_session.dart';
import '../theme/theme_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/action/action_inspector.dart';
import '../widgets/primitives/chip.dart';
import '../widgets/primitives/empty_state.dart';
import '../widgets/primitives/table_header.dart';

/// Two-pane Actions inspector: filterable table (left) + ActionInspector (right).
class ActionLogScreen extends StatefulWidget {
  final DeviceSession session;
  const ActionLogScreen({super.key, required this.session});

  @override
  State<ActionLogScreen> createState() => _ActionLogScreenState();
}

class _ActionLogScreenState extends State<ActionLogScreen> {
  String? _selectedId;
  String _family = 'all';
  bool _inspectorOpen = true;

  static const _families = [
    'all',
    'navigation',
    'state',
    'ui-feedback',
    'data',
    'lifecycle',
    'custom',
  ];

  @override
  Widget build(BuildContext context) {
    final actions = _buildEntries(widget.session.eventsByType('action'));
    if (actions.isEmpty) {
      return const EmptyState(
        icon: 'actions',
        title: 'No actions dispatched yet',
        body: 'Tap through the app to populate the log.',
      );
    }
    final filtered = _family == 'all'
        ? actions
        : actions.where((a) => a.family == _family).toList();

    final selectedId = _selectedId ?? filtered.firstOrNull?.id;
    final selected = filtered.cast<ActionEntry?>().firstWhere(
              (a) => a?.id == selectedId,
              orElse: () => filtered.isEmpty ? null : filtered.first,
            ) ??
        actions.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              _FamilyFilterBar(
                families: _families,
                current: _family,
                filteredCount: filtered.length,
                totalCount: actions.length,
                onChanged: (f) => setState(() => _family = f),
              ),
              const TableHeader(columns: [
                TableColumn(label: 'time', width: 92),
                TableColumn(label: 'type'),
                TableColumn(label: 'pageId', width: 180),
                TableColumn(
                  label: 'duration',
                  width: 90,
                  align: TextAlign.right,
                ),
              ]),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final a = filtered[i];
                    return _ActionRow(
                      action: a,
                      zebra: i.isOdd,
                      selected: a.id == selectedId,
                      onTap: () => setState(() {
                        _selectedId = a.id;
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
          ActionInspector(
            action: selected,
            session: widget.session,
            onClose: () => setState(() => _inspectorOpen = false),
          ),
      ],
    );
  }

  static List<ActionEntry> _buildEntries(List<DebugEvent> events) {
    final sorted = [...events]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return [for (final e in sorted) _entryFromEvent(e)];
  }

  static ActionEntry _entryFromEvent(DebugEvent e) {
    final p = e.payload;
    final type = p['actionType']?.toString() ?? '(unknown)';
    final data = p['data'];
    final pageId = p['pageId']?.toString();
    final duration = p['durationMs'];
    final durNum =
        duration is num ? duration.toDouble() : double.tryParse('$duration') ?? 0.0;
    final transform = (p['transformTrace'] as List?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        const <Map<String, dynamic>>[];
    final widgets = (p['affectedWidgets'] as List?)
            ?.map((w) => w is Map
                ? Map<String, dynamic>.from(w)
                : <String, dynamic>{'type': w.toString()})
            .toList() ??
        const <Map<String, dynamic>>[];
    // Protocol v2+ emits the family on the wire; fall back to the
    // client-side heuristic for v1 payloads.
    final wireFamily = p['family']?.toString();
    return ActionEntry(
      id: '${e.timestamp}-$type',
      timestampMs: e.timestamp,
      type: type,
      family: (wireFamily != null && wireFamily.isNotEmpty)
          ? wireFamily
          : inferActionFamily(type),
      pageId: pageId,
      durationMs: durNum,
      payload: data ?? const <String, dynamic>{},
      transformSteps: transform,
      affectedWidgets: widgets,
    );
  }
}

class _FamilyFilterBar extends StatelessWidget {
  final List<String> families;
  final String current;
  final int filteredCount;
  final int totalCount;
  final ValueChanged<String> onChanged;

  const _FamilyFilterBar({
    required this.families,
    required this.current,
    required this.filteredCount,
    required this.totalCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (final f in families) ...[
            _FamilyButton(
              label: f,
              selected: current == f,
              onTap: () => onChanged(f),
            ),
            const SizedBox(width: 4),
          ],
          const Spacer(),
          Text(
            '$filteredCount / $totalCount actions',
            style: TextStyle(
              fontFamily: kSfMono,
              fontFamilyFallback: kSfMonoFallback,
              fontSize: fs(10.5, theme.fontScale),
              color: theme.text.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FamilyButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? theme.accent.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kSfPro,
              fontFamilyFallback: kSfProFallback,
              fontSize: fs(11.5, theme.fontScale),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? theme.accent.base : theme.text.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  final ActionEntry action;
  final bool zebra;
  final bool selected;
  final VoidCallback onTap;

  const _ActionRow({
    required this.action,
    required this.zebra,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final a = widget.action;
    final bg = widget.selected
        ? theme.accent.muted
        : (_hover
            ? theme.surface.hover
            : (widget.zebra ? theme.surface.zebra : Colors.transparent));
    final tone = familyTone(a.family);
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
                width: 92,
                child: Text(
                  _fmtTime(a.timestampMs),
                  style: _bodyStyle(theme).copyWith(color: theme.text.secondary),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    OrcaChip(
                      tone: tone,
                      label: a.family,
                      size: OrcaChipSize.sm,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        a.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle(theme).copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.text.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: Text(
                  a.pageId?.isEmpty == true ? '—' : (a.pageId ?? '—'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      _bodyStyle(theme).copyWith(color: theme.text.secondary),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  '${a.durationMs.toStringAsFixed(0)} ms',
                  textAlign: TextAlign.right,
                  style: _bodyStyle(theme).copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.text.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static TextStyle _bodyStyle(OrcaTheme theme) => TextStyle(
        fontFamily: kSfMono,
        fontFamilyFallback: kSfMonoFallback,
        fontSize: fs(11.5, theme.fontScale),
        color: theme.text.primary,
      );

  static String _fmtTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String p(int n) => n.toString().padLeft(2, '0');
    String pp(int n) => n.toString().padLeft(3, '0');
    return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${pp(d.millisecond)}';
  }
}
