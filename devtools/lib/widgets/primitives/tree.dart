import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';
import 'orca_icon.dart';

/// Collapsible group header for the state tree. Ported from `TreeGroup`.
class TreeGroup extends StatefulWidget {
  final String label;
  final bool defaultOpen;
  final List<Widget> children;

  const TreeGroup({
    super.key,
    required this.label,
    required this.children,
    this.defaultOpen = false,
  });

  @override
  State<TreeGroup> createState() => _TreeGroupState();
}

class _TreeGroupState extends State<TreeGroup> {
  late bool _open = widget.defaultOpen;

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _open = !_open),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    OrcaIcon(
                      _open ? 'chevron-down' : 'chevron-right',
                      size: 10,
                      color: theme.text.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: kSfPro,
                        fontFamilyFallback: kSfProFallback,
                        fontSize: fs(10, theme.fontScale),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: theme.text.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
        ],
      ),
    );
  }
}

/// A single key / value preview row. Ported from `TreeLeaf`.
class TreeLeaf extends StatefulWidget {
  final String keyName;
  final String valuePreview;
  final bool selected;
  final VoidCallback onTap;

  const TreeLeaf({
    super.key,
    required this.keyName,
    required this.valuePreview,
    required this.selected,
    required this.onTap,
  });

  @override
  State<TreeLeaf> createState() => _TreeLeafState();
}

class _TreeLeafState extends State<TreeLeaf> {
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
          color: bg,
          padding: const EdgeInsets.fromLTRB(26, 3, 10, 3),
          child: Row(
            children: [
              Text(
                widget.keyName,
                style: TextStyle(
                  fontFamily: kSfMono,
                  fontFamilyFallback: kSfMonoFallback,
                  fontSize: fs(11.5, theme.fontScale),
                  fontWeight: FontWeight.w500,
                  color: theme.text.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                ':',
                style: TextStyle(
                  fontFamily: kSfMono,
                  fontFamilyFallback: kSfMonoFallback,
                  fontSize: fs(11.5, theme.fontScale),
                  color: theme.text.tertiary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.valuePreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSfMono,
                    fontFamilyFallback: kSfMonoFallback,
                    fontSize: fs(11.5, theme.fontScale),
                    color: theme.text.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
