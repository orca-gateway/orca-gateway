import 'package:flutter/material.dart';
import '../models/debug_event.dart';
import '../models/device_session.dart';
import '../theme/theme_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/primitives/chip.dart';
import '../widgets/primitives/json_viewer.dart';
import '../widgets/primitives/list_filter_bar.dart';
import '../widgets/primitives/section_header.dart';
import '../widgets/primitives/tree.dart';

/// Three-pane State inspector: tree (left) · JSON viewer (top-right) ·
/// change history (bottom-right).
class StateInspectorScreen extends StatefulWidget {
  final DeviceSession session;
  const StateInspectorScreen({super.key, required this.session});

  @override
  State<StateInspectorScreen> createState() => _StateInspectorScreenState();
}

class _StateInspectorScreenState extends State<StateInspectorScreen> {
  String? _selected;
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final changes = widget.session.eventsByType('state_change');
    final snapshot = _buildSnapshot(changes);

    if (snapshot.isEmpty) {
      return Center(
        child: Text(
          'No state changes yet',
          style: TextStyle(
            fontFamily: kSfPro,
            fontFamilyFallback: kSfProFallback,
            fontSize: fs(13, theme.fontScale),
            color: theme.text.tertiary,
          ),
        ),
      );
    }

    final sel = _selected ?? snapshot.defaultSelection();
    final (label, type, value) = snapshot.resolve(sel);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tree column.
        SizedBox(
          width: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.border.hairline, width: 1),
              ),
            ),
            child: Column(
              children: [
                ListFilterBar(
                  placeholder: 'Filter keys…',
                  onChanged: (v) => setState(() => _filter = v),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      if (snapshot.app.isNotEmpty)
                        TreeGroup(
                          label: 'App State',
                          defaultOpen: true,
                          children: [
                            for (final entry in snapshot.app.entries)
                              if (_matchesFilter(entry.key))
                                TreeLeaf(
                                  keyName: entry.key,
                                  valuePreview: _preview(entry.value),
                                  selected: sel == 'app.${entry.key}',
                                  onTap: () => setState(
                                      () => _selected = 'app.${entry.key}'),
                                ),
                          ],
                        ),
                      for (final pageEntry in snapshot.pages.entries)
                        TreeGroup(
                          label: pageEntry.key,
                          defaultOpen: true,
                          children: [
                            for (final entry in pageEntry.value.entries)
                              if (_matchesFilter(entry.key))
                                TreeLeaf(
                                  keyName: entry.key,
                                  valuePreview: _preview(entry.value),
                                  selected: sel ==
                                      'page:${pageEntry.key}:${entry.key}',
                                  onTap: () => setState(() => _selected =
                                      'page:${pageEntry.key}:${entry.key}'),
                                ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right split: JSON viewer + change history.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(color: theme.border.hairline, width: 1),
                    ),
                  ),
                  child: _ValueDetail(
                    label: label,
                    type: type,
                    value: value,
                  ),
                ),
              ),
              Expanded(
                flex: 45,
                child: _ChangeHistoryPane(changes: changes),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _matchesFilter(String key) =>
      _filter.isEmpty || key.toLowerCase().contains(_filter.toLowerCase());

  String _preview(dynamic v) {
    if (v == null) return 'null';
    if (v is String) return '"$v"';
    return v.toString();
  }

  static _StateSnapshot _buildSnapshot(List<DebugEvent> changes) {
    final app = <String, dynamic>{};
    final pages = <String, Map<String, dynamic>>{};
    // Iterate oldest-first so the last write wins.
    for (final e in changes) {
      final scope = e.payload['scope'] as String? ?? 'page';
      final key = e.payload['key'] as String?;
      if (key == null) continue;
      final value = e.payload['newValue'];
      if (scope == 'app') {
        app[key] = value;
      } else {
        final pageId = e.payload['pageId']?.toString() ?? '(unknown)';
        pages.putIfAbsent(pageId, () => <String, dynamic>{})[key] = value;
      }
    }
    return _StateSnapshot(app: app, pages: pages);
  }
}

class _StateSnapshot {
  final Map<String, dynamic> app;
  final Map<String, Map<String, dynamic>> pages;

  const _StateSnapshot({required this.app, required this.pages});

  bool get isEmpty => app.isEmpty && pages.isEmpty;

  String defaultSelection() {
    if (app.isNotEmpty) return 'app.${app.keys.first}';
    final pageId = pages.keys.first;
    final key = pages[pageId]!.keys.first;
    return 'page:$pageId:$key';
  }

  (String label, String type, dynamic value) resolve(String sel) {
    if (sel.startsWith('app.')) {
      final key = sel.substring(4);
      final value = app[key];
      return ('app · $key', _typeOf(value), value);
    }
    if (sel.startsWith('page:')) {
      final parts = sel.split(':');
      if (parts.length >= 3) {
        final pageId = parts[1];
        final key = parts.sublist(2).join(':');
        final value = pages[pageId]?[key];
        return ('$pageId · $key', _typeOf(value), value);
      }
    }
    return (sel, 'unknown', null);
  }

  static String _typeOf(dynamic v) {
    if (v == null) return 'null';
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'number';
    if (v is String) return 'string';
    if (v is List) return 'array';
    if (v is Map) return 'object';
    return v.runtimeType.toString();
  }
}

class _ValueDetail extends StatelessWidget {
  final String label;
  final String type;
  final dynamic value;

  const _ValueDetail({
    required this.label,
    required this.type,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSfMono,
                    fontFamilyFallback: kSfMonoFallback,
                    fontSize: fs(14, theme.fontScale),
                    fontWeight: FontWeight.w600,
                    color: theme.text.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OrcaChip(tone: 'info', label: type, size: OrcaChipSize.sm),
            ],
          ),
          const SizedBox(height: 10),
          JsonViewer(value: value),
        ],
      ),
    );
  }
}

class _ChangeHistoryPane extends StatelessWidget {
  final List<DebugEvent> changes;
  const _ChangeHistoryPane({required this.changes});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    // Most recent first.
    final sorted = [...changes]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              SectionHeader('Change History'),
              const Spacer(),
              Text(
                '${sorted.length} events',
                style: TextStyle(
                  fontFamily: kSfMono,
                  fontFamilyFallback: kSfMonoFallback,
                  fontSize: fs(10.5, theme.fontScale),
                  color: theme.text.tertiary,
                ),
              ),
            ],
          ),
        ),
        _HistoryHeader(theme: theme),
        Expanded(
          child: ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, i) =>
                _HistoryRow(event: sorted[i], zebra: i.isOdd, theme: theme),
          ),
        ),
      ],
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final OrcaTheme theme;
  const _HistoryHeader({required this.theme});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: kSfPro,
      fontFamilyFallback: kSfProFallback,
      fontSize: fs(10.5, theme.fontScale),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: theme.text.tertiary,
    );
    Widget cell(String label, {int flex = 1, double? width}) => width != null
        ? SizedBox(
            width: width,
            child: Text(label.toUpperCase(), style: style),
          )
        : Expanded(
            flex: flex,
            child: Text(label.toUpperCase(), style: style),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          cell('time', width: 90),
          cell('scope', width: 68),
          cell('key', width: 150),
          cell('old'),
          cell('new'),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final DebugEvent event;
  final bool zebra;
  final OrcaTheme theme;
  const _HistoryRow({
    required this.event,
    required this.zebra,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final p = event.payload;
    final scope = p['scope'] as String? ?? 'page';
    final bodyStyle = TextStyle(
      fontFamily: kSfMono,
      fontFamilyFallback: kSfMonoFallback,
      fontSize: fs(11, theme.fontScale),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: zebra ? theme.surface.zebra : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: theme.border.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              _fmtTime(event.timestamp),
              style: bodyStyle.copyWith(color: theme.text.secondary),
            ),
          ),
          SizedBox(
            width: 68,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OrcaChip(
                tone: scope == 'app' ? 'scopeApp' : 'scopePage',
                label: scope,
                size: OrcaChipSize.sm,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              p['key']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle.copyWith(color: theme.text.primary),
            ),
          ),
          Expanded(
            child: Text(
              _preview(p['oldValue']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle.copyWith(color: theme.text.secondary),
            ),
          ),
          Expanded(
            child: Text(
              _preview(p['newValue']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle.copyWith(color: theme.text.primary),
            ),
          ),
        ],
      ),
    );
  }

  static String _preview(dynamic v) {
    if (v == null) return 'null';
    if (v is String) return '"$v"';
    return v.toString();
  }

  static String _fmtTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String p(int n) => n.toString().padLeft(2, '0');
    String pp(int n) => n.toString().padLeft(3, '0');
    return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${pp(d.millisecond)}';
  }
}
