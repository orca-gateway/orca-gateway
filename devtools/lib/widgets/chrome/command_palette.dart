import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../primitives/kbd.dart';
import '../primitives/orca_icon.dart';

/// A single selectable row in the command palette.
class PaletteItem {
  final String label;
  final String icon;
  final String? hint;
  final VoidCallback onActivate;
  const PaletteItem({
    required this.label,
    required this.icon,
    this.hint,
    required this.onActivate,
  });
}

/// A titled group of items (e.g. "Jump to", "Devices", "Recent paths").
class PaletteGroup {
  final String label;
  final List<PaletteItem> items;
  const PaletteGroup({required this.label, required this.items});
}

/// Full-screen modal overlay with grouped, filterable, keyboard-navigable
/// actions. Ported from `components/palette-tweaks.jsx` in the design.
class CommandPalette extends StatefulWidget {
  final bool open;
  final VoidCallback onClose;
  final List<PaletteGroup> groups;

  const CommandPalette({
    super.key,
    required this.open,
    required this.onClose,
    required this.groups,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  int _selected = 0;

  @override
  void didUpdateWidget(CommandPalette old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      _queryCtrl.clear();
      _selected = 0;
      // Focus the input one frame after the palette mounts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _inputFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  /// Flatten groups into a display list of (section-header | item) entries.
  /// If the query is non-empty, hide group headers that have no matches and
  /// hide non-matching items.
  List<_Row> _visibleRows() {
    final q = _queryCtrl.text.trim().toLowerCase();
    final rows = <_Row>[];
    for (final group in widget.groups) {
      final matches = q.isEmpty
          ? group.items
          : group.items
              .where((i) => i.label.toLowerCase().contains(q))
              .toList();
      if (matches.isEmpty) continue;
      rows.add(_Row.header(group.label));
      for (final item in matches) {
        rows.add(_Row.item(item));
      }
    }
    return rows;
  }

  List<PaletteItem> _activatableItems(List<_Row> rows) =>
      rows.where((r) => r.item != null).map((r) => r.item!).toList();

  void _activateSelected() {
    final rows = _visibleRows();
    final items = _activatableItems(rows);
    if (items.isEmpty) return;
    final idx = _selected.clamp(0, items.length - 1);
    widget.onClose();
    // Fire *after* the close so the palette isn't mid-teardown when the
    // receiving screen rebuilds (e.g. a navigation change rebuilds the shell).
    Future.microtask(items[idx].onActivate);
  }

  void _move(int delta) {
    final items = _activatableItems(_visibleRows());
    if (items.isEmpty) return;
    setState(() {
      _selected = (_selected + delta) % items.length;
      if (_selected < 0) _selected += items.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();
    final theme = OrcaThemeScope.of(context);
    final rows = _visibleRows();
    final items = _activatableItems(rows);
    final boundedSel =
        items.isEmpty ? -1 : _selected.clamp(0, items.length - 1);

    // Backdrop captures taps outside the modal.
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: Container(color: const Color(0x47000000)),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 120),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight: MediaQuery.of(context).size.height * 0.70,
                  ),
                  child: Shortcuts(
                    shortcuts: const <ShortcutActivator, Intent>{
                      SingleActivator(LogicalKeyboardKey.escape):
                          _CloseIntent(),
                      SingleActivator(LogicalKeyboardKey.arrowDown):
                          _MoveIntent(1),
                      SingleActivator(LogicalKeyboardKey.arrowUp):
                          _MoveIntent(-1),
                      SingleActivator(LogicalKeyboardKey.enter):
                          _ActivateIntent(),
                      SingleActivator(LogicalKeyboardKey.numpadEnter):
                          _ActivateIntent(),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        _CloseIntent: CallbackAction<_CloseIntent>(
                          onInvoke: (_) {
                            widget.onClose();
                            return null;
                          },
                        ),
                        _MoveIntent: CallbackAction<_MoveIntent>(
                          onInvoke: (i) {
                            _move(i.delta);
                            return null;
                          },
                        ),
                        _ActivateIntent: CallbackAction<_ActivateIntent>(
                          onInvoke: (_) {
                            _activateSelected();
                            return null;
                          },
                        ),
                      },
                      child: _Modal(
                        theme: theme,
                        queryCtrl: _queryCtrl,
                        inputFocus: _inputFocus,
                        onQueryChanged: (_) => setState(() => _selected = 0),
                        rows: rows,
                        items: items,
                        selected: boundedSel,
                        onItemActivate: (i) {
                          setState(() => _selected = i);
                          _activateSelected();
                        },
                        onItemHover: (i) => setState(() => _selected = i),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Internals ──────────────────────────────────────────────────

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _MoveIntent extends Intent {
  final int delta;
  const _MoveIntent(this.delta);
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}

class _Row {
  final String? header;
  final PaletteItem? item;
  _Row.header(String h)
      : header = h,
        item = null;
  _Row.item(PaletteItem i)
      : header = null,
        item = i;
}

class _Modal extends StatelessWidget {
  final OrcaTheme theme;
  final TextEditingController queryCtrl;
  final FocusNode inputFocus;
  final ValueChanged<String> onQueryChanged;
  final List<_Row> rows;
  final List<PaletteItem> items;
  final int selected;
  final ValueChanged<int> onItemActivate;
  final ValueChanged<int> onItemHover;

  const _Modal({
    required this.theme,
    required this.queryCtrl,
    required this.inputFocus,
    required this.onQueryChanged,
    required this.rows,
    required this.items,
    required this.selected,
    required this.onItemActivate,
    required this.onItemHover,
  });

  @override
  Widget build(BuildContext context) {
    // Opaque modal background — no BackdropFilter until we opt into a
    // transparent native window.
    final modalBg =
        theme.isDark ? const Color(0xFF2C2C30) : const Color(0xFFFCFCFC);

    int itemIndex = -1;
    final children = <Widget>[];
    for (final row in rows) {
      if (row.header != null) {
        children.add(_GroupLabel(theme: theme, label: row.header!));
      } else {
        itemIndex++;
        final capturedIdx = itemIndex;
        final isSelected = capturedIdx == selected;
        children.add(_ItemRow(
          theme: theme,
          item: row.item!,
          selected: isSelected,
          onHover: () => onItemHover(capturedIdx),
          onTap: () => onItemActivate(capturedIdx),
        ));
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: modalBg,
        border: Border.all(color: theme.border.hairline, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          const BoxShadow(
            color: Color(0x80000000),
            offset: Offset(0, 20),
            blurRadius: 60,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SearchRow(
              theme: theme,
              controller: queryCtrl,
              focusNode: inputFocus,
              onChanged: onQueryChanged,
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No results',
                  style: TextStyle(
                    fontFamily: kSfPro,
                    fontFamilyFallback: kSfProFallback,
                    fontSize: fs(12.5, theme.fontScale),
                    color: theme.text.tertiary,
                  ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            _Footer(theme: theme),
          ],
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  final OrcaTheme theme;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchRow({
    required this.theme,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          OrcaIcon('search', size: 16, color: theme.text.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              onChanged: onChanged,
              cursorColor: theme.accent.base,
              style: TextStyle(
                fontFamily: kSfPro,
                fontFamilyFallback: kSfProFallback,
                fontSize: fs(14, theme.fontScale),
                color: theme.text.primary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search actions, network paths, state keys…',
                hintStyle: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(14, theme.fontScale),
                  color: theme.text.tertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Kbd('esc'),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final OrcaTheme theme;
  final String label;
  const _GroupLabel({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: kSfPro,
          fontFamilyFallback: kSfProFallback,
          fontSize: fs(10, theme.fontScale),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: theme.text.tertiary,
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrcaTheme theme;
  final PaletteItem item;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _ItemRow({
    required this.theme,
    required this.item,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? theme.accent.muted : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          color: bg,
          child: Row(
            children: [
              OrcaIcon(item.icon, size: 13, color: theme.text.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSfPro,
                    fontFamilyFallback: kSfProFallback,
                    fontSize: fs(12.5, theme.fontScale),
                    color: theme.text.primary,
                  ),
                ),
              ),
              if (item.hint != null)
                Text(
                  item.hint!,
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
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final OrcaTheme theme;
  const _Footer({required this.theme});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: kSfPro,
      fontFamilyFallback: kSfProFallback,
      fontSize: fs(10.5, theme.fontScale),
      color: theme.text.tertiary,
    );
    Widget hint(String kbd, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Kbd(kbd),
            const SizedBox(width: 6),
            Text(label, style: style),
          ],
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          hint('↑↓', 'navigate'),
          const SizedBox(width: 14),
          hint('↵', 'open'),
          const Spacer(),
          hint('⌘K', 'toggle'),
        ],
      ),
    );
  }
}
