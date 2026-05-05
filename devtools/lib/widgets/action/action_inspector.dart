import 'package:flutter/material.dart';
import '../../models/debug_event.dart';
import '../../models/device_session.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../primitives/json_viewer.dart';
import '../primitives/orca_icon.dart';
import '../primitives/section_header.dart';

/// Parsed action row (what the list shows + what the inspector drills into).
class ActionEntry {
  final String id;
  final int timestampMs;
  final String type;
  final String family;
  final String? pageId;
  final double durationMs;
  final dynamic payload;
  final List<Map<String, dynamic>> transformSteps;
  final List<Map<String, dynamic>> affectedWidgets;

  const ActionEntry({
    required this.id,
    required this.timestampMs,
    required this.type,
    required this.family,
    required this.pageId,
    required this.durationMs,
    required this.payload,
    required this.transformSteps,
    required this.affectedWidgets,
  });
}

/// Classify a raw `actionType` string into one of the six design families.
/// This is a heuristic; Phase 5 replaces it with an explicit SDK `family`
/// field on the wire event.
String inferActionFamily(String type) {
  const exact = {
    'setState': 'state',
    'navigate': 'navigation',
    'goBack': 'navigation',
    'switchTab': 'navigation',
    'showSnackbar': 'ui-feedback',
    'showToast': 'ui-feedback',
    'openDrawer': 'ui-feedback',
    'serverAction': 'data',
    'actionGroup': 'lifecycle',
    'conditionalAction': 'data',
    'openUrl': 'ui-feedback',
    'copyToClipboard': 'ui-feedback',
    'share': 'ui-feedback',
    'updateComponent': 'state',
    'deleteComponent': 'state',
    'addComponent': 'state',
    'replaceComponent': 'state',
  };
  if (exact.containsKey(type)) return exact[type]!;
  final upper = type.toUpperCase();
  if (upper.startsWith('NAVIGATE') ||
      upper.startsWith('GO_') ||
      upper.contains('ROUTE')) {
    return 'navigation';
  }
  if (upper.startsWith('SET_') ||
      upper.startsWith('UPDATE_') ||
      upper.startsWith('TOGGLE_')) {
    return 'state';
  }
  if (upper.contains('TOAST') ||
      upper.contains('SNACKBAR') ||
      upper.contains('MODAL') ||
      upper.contains('ALERT') ||
      upper.contains('SCROLL')) {
    return 'ui-feedback';
  }
  if (upper.startsWith('APP_') ||
      upper.contains('LIFECYCLE') ||
      upper.contains('AUTH_')) {
    return 'lifecycle';
  }
  if (upper.contains('FETCH') ||
      upper.contains('LOAD') ||
      upper.contains('CART') ||
      upper.contains('SUBMIT') ||
      upper.contains('APPLY_')) {
    return 'data';
  }
  return 'custom';
}

/// Design-spec tone for each family.
String familyTone(String family) {
  switch (family) {
    case 'navigation':
      return 'info';
    case 'state':
      return 'scopePage';
    case 'ui-feedback':
      return 'warning';
    case 'data':
      return 'success';
    case 'lifecycle':
      return 'info';
    case 'custom':
    default:
      return 'scopeApp';
  }
}

/// 320px right-pane slide-in inspector showing Payload / Transform / Widgets
/// tabs for a selected action, with drill-down into a widget's prop
/// pipelines via the push-back navigation in the header.
class ActionInspector extends StatefulWidget {
  final ActionEntry action;
  final DeviceSession session;
  final VoidCallback onClose;

  const ActionInspector({
    super.key,
    required this.action,
    required this.session,
    required this.onClose,
  });

  @override
  State<ActionInspector> createState() => _ActionInspectorState();
}

class _ActionInspectorState extends State<ActionInspector> {
  String _tab = 'payload';
  String? _pushedWidgetId;
  String? _pushedWidgetType;

  @override
  void didUpdateWidget(ActionInspector old) {
    super.didUpdateWidget(old);
    if (old.action.id != widget.action.id) {
      // Reset push state when switching to a different action.
      _pushedWidgetId = null;
      _pushedWidgetType = null;
      _tab = 'payload';
    }
  }

  void _pushWidget(Map<String, dynamic> w) {
    setState(() {
      _pushedWidgetId = w['id']?.toString() ?? w['widgetId']?.toString();
      _pushedWidgetType = w['type']?.toString() ?? w['widgetType']?.toString();
    });
  }

  void _popWidget() {
    setState(() {
      _pushedWidgetId = null;
      _pushedWidgetType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
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
          _Header(
            title: _pushedWidgetId != null
                ? (_pushedWidgetType ?? _pushedWidgetId!)
                : widget.action.type,
            onBack: _pushedWidgetId != null ? _popWidget : null,
            onClose: widget.onClose,
          ),
          if (_pushedWidgetId != null)
            Expanded(
              child: _WidgetDetail(
                widgetId: _pushedWidgetId!,
                session: widget.session,
              ),
            )
          else ...[
            _MetaRow(action: widget.action),
            _Tabs(
              current: _tab,
              counts: {
                'widgets': widget.action.affectedWidgets.length,
              },
              onChange: (t) => setState(() => _tab = t),
            ),
            Expanded(
              child: _TabContent(
                tab: _tab,
                action: widget.action,
                onPushWidget: _pushWidget,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  const _Header({
    required this.title,
    required this.onBack,
    required this.onClose,
  });

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
          if (onBack != null) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onBack,
                child: Row(
                  children: [
                    OrcaIcon(
                      'chevron-right',
                      size: 11,
                      color: theme.accent.base,
                    ),
                    const SizedBox(width: 2),
                    Transform.rotate(
                      angle: 3.14159,
                      child: OrcaIcon(
                        'chevron-right',
                        size: 11,
                        color: theme.accent.base,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'back',
                      style: TextStyle(
                        fontFamily: kSfPro,
                        fontFamilyFallback: kSfProFallback,
                        fontSize: fs(12, theme.fontScale),
                        color: theme.accent.base,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
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
                child: OrcaIcon('close', size: 12, color: theme.text.tertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final ActionEntry action;
  const _MetaRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final style = TextStyle(
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
          Text(_fmtIso(action.timestampMs), style: style),
          const SizedBox(width: 10),
          Text('·', style: TextStyle(color: theme.text.tertiary)),
          const SizedBox(width: 10),
          Text('${action.durationMs.toStringAsFixed(0)}ms', style: style),
          if (action.pageId != null && action.pageId!.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text('·', style: TextStyle(color: theme.text.tertiary)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                action.pageId!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final String current;
  final Map<String, int> counts;
  final ValueChanged<String> onChange;

  const _Tabs({
    required this.current,
    required this.counts,
    required this.onChange,
  });

  static const _ids = ['payload', 'pipeline', 'widgets'];
  static const _labels = {
    'payload': 'Payload',
    'pipeline': 'Transform',
    'widgets': 'Widgets',
  };

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
            _Tab(
              id: id,
              label: _labels[id]!,
              badge: id == 'widgets' ? counts['widgets'] : null,
              selected: current == id,
              onTap: () => onChange(id),
            ),
            const SizedBox(width: 18),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String id;
  final String label;
  final int? badge;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.id,
    required this.label,
    required this.badge,
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? theme.accent.base : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(12, theme.fontScale),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      selected ? theme.text.primary : theme.text.secondary,
                ),
              ),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 5),
                Text(
                  badge.toString(),
                  style: TextStyle(
                    fontFamily: kSfMono,
                    fontFamilyFallback: kSfMonoFallback,
                    fontSize: fs(10, theme.fontScale),
                    color: theme.text.tertiary,
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

class _TabContent extends StatelessWidget {
  final String tab;
  final ActionEntry action;
  final ValueChanged<Map<String, dynamic>> onPushWidget;

  const _TabContent({
    required this.tab,
    required this.action,
    required this.onPushWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    switch (tab) {
      case 'payload':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: JsonViewer(value: action.payload),
        );
      case 'pipeline':
        if (action.transformSteps.isEmpty) {
          return Center(
            child: Text(
              'No transform pipeline',
              style: TextStyle(
                fontFamily: kSfPro,
                fontFamilyFallback: kSfProFallback,
                fontSize: fs(12, theme.fontScale),
                color: theme.text.tertiary,
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: _TransformPipeline(steps: action.transformSteps),
        );
      case 'widgets':
        if (action.affectedWidgets.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No widgets affected',
                style: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(12, theme.fontScale),
                  color: theme.text.tertiary,
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            for (final w in action.affectedWidgets)
              _WidgetRow(widget: w, onTap: () => onPushWidget(w)),
          ],
        );
    }
    return const SizedBox.shrink();
  }
}

class _TransformPipeline extends StatelessWidget {
  final List<Map<String, dynamic>> steps;
  const _TransformPipeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepCard(index: i, step: steps[i], theme: theme),
          if (i < steps.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> step;
  final OrcaTheme theme;

  const _StepCard({
    required this.index,
    required this.step,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final op = step['op']?.toString() ?? '—';
    final inVal = (step['in'] ?? step['input'])?.toString() ?? '';
    final outVal = (step['out'] ?? step['output'])?.toString() ?? '';

    final labelStyle = TextStyle(
      fontFamily: kSfMono,
      fontFamilyFallback: kSfMonoFallback,
      fontSize: fs(11, theme.fontScale),
      color: theme.text.tertiary,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.accent.muted,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: kSfMono,
                fontFamilyFallback: kSfMonoFallback,
                fontSize: fs(10.5, theme.fontScale),
                fontWeight: FontWeight.w700,
                color: theme.accent.base,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: theme.surface.content,
              border: Border.all(color: theme.border.hairline, width: 1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op,
                  style: TextStyle(
                    fontFamily: kSfMono,
                    fontFamilyFallback: kSfMonoFallback,
                    fontSize: fs(11, theme.fontScale),
                    fontWeight: FontWeight.w600,
                    color: theme.accent.base,
                  ),
                ),
                const SizedBox(height: 3),
                if (inVal.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('in ', style: labelStyle),
                      Expanded(
                        child: Text(
                          inVal,
                          style: TextStyle(
                            fontFamily: kSfMono,
                            fontFamilyFallback: kSfMonoFallback,
                            fontSize: fs(11, theme.fontScale),
                            color: theme.text.secondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (outVal.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('out ', style: labelStyle),
                      Expanded(
                        child: Text(
                          outVal,
                          style: TextStyle(
                            fontFamily: kSfMono,
                            fontFamilyFallback: kSfMonoFallback,
                            fontSize: fs(11, theme.fontScale),
                            color: theme.text.primary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WidgetRow extends StatefulWidget {
  final Map<String, dynamic> widget;
  final VoidCallback onTap;

  const _WidgetRow({required this.widget, required this.onTap});

  @override
  State<_WidgetRow> createState() => _WidgetRowState();
}

class _WidgetRowState extends State<_WidgetRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    final label = (widget.widget['type'] ?? widget.widget['widgetType'])
            ?.toString() ??
        '(widget)';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? theme.surface.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              OrcaIcon('state', size: 12, color: theme.accent.base),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSfMono,
                    fontFamilyFallback: kSfMonoFallback,
                    fontSize: fs(12, theme.fontScale),
                    color: theme.text.primary,
                  ),
                ),
              ),
              OrcaIcon('chevron-right', size: 11, color: theme.text.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetDetail extends StatelessWidget {
  final String widgetId;
  final DeviceSession session;

  const _WidgetDetail({required this.widgetId, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);

    // Find the most recent widget_rebuild event for this widget id.
    Map<String, dynamic>? propTraces;
    final rebuilds = session.eventsByType('widget_rebuild');
    for (final DebugEvent e in rebuilds.reversed) {
      if (e.payload['widgetId'] == widgetId) {
        final pt = e.payload['propTraces'];
        if (pt is Map<String, dynamic>) propTraces = pt;
        break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Prop pipelines'),
          const SizedBox(height: 10),
          if (propTraces == null || propTraces.isEmpty)
            Text(
              'No prop traces recorded for this widget yet.',
              style: TextStyle(
                fontFamily: kSfPro,
                fontFamilyFallback: kSfProFallback,
                fontSize: fs(12, theme.fontScale),
                color: theme.text.tertiary,
              ),
            )
          else
            for (final entry in propTraces.entries) ...[
              _PropPipelineCard(
                propName: entry.key,
                steps: entry.value is List
                    ? List<Map<String, dynamic>>.from(
                        (entry.value as List).whereType<Map>().map(
                              (e) => Map<String, dynamic>.from(e),
                            ),
                      )
                    : const [],
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _PropPipelineCard extends StatelessWidget {
  final String propName;
  final List<Map<String, dynamic>> steps;

  const _PropPipelineCard({required this.propName, required this.steps});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface.content,
        border: Border.all(color: theme.border.hairline, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.surface.raised,
                border: Border(
                  bottom: BorderSide(color: theme.border.divider, width: 1),
                ),
              ),
              child: Text(
                propName,
                style: TextStyle(
                  fontFamily: kSfMono,
                  fontFamilyFallback: kSfMonoFallback,
                  fontSize: fs(11, theme.fontScale),
                  fontWeight: FontWeight.w600,
                  color: theme.text.primary,
                ),
              ),
            ),
            for (var i = 0; i < steps.length; i++)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: i == steps.length - 1
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: theme.border.divider,
                            width: 1,
                          ),
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (steps[i]['op'] ?? steps[i]['from'])?.toString() ?? '',
                      style: TextStyle(
                        fontFamily: kSfMono,
                        fontFamilyFallback: kSfMonoFallback,
                        fontSize: fs(10, theme.fontScale),
                        color: theme.text.tertiary,
                      ),
                    ),
                    Text(
                      (steps[i]['out'] ?? steps[i]['value'])?.toString() ?? '',
                      style: TextStyle(
                        fontFamily: kSfMono,
                        fontFamilyFallback: kSfMonoFallback,
                        fontSize: fs(11, theme.fontScale),
                        fontWeight: FontWeight.w500,
                        color: theme.text.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _fmtIso(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String p(int n) => n.toString().padLeft(2, '0');
  String pp(int n) => n.toString().padLeft(3, '0');
  return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}.${pp(d.millisecond)}';
}
