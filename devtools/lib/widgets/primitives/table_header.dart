import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// One column in a [TableHeader].
class TableColumn {
  final String label;
  final double? width;
  final int flex;
  final TextAlign align;

  const TableColumn({
    required this.label,
    this.width,
    this.flex = 1,
    this.align = TextAlign.left,
  });
}

/// Uppercase tracked column headers — sits above data rows.
/// Ported from `TableHeader` in the prototype.
class TableHeader extends StatelessWidget {
  final List<TableColumn> columns;

  const TableHeader({super.key, required this.columns});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.isDark ? const Color(0xFF232327) : const Color(0xFFF4F4F6),
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (final col in columns)
            _labelCell(theme, col),
        ],
      ),
    );
  }

  Widget _labelCell(OrcaTheme theme, TableColumn col) {
    final text = Text(
      col.label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: col.align,
      style: TextStyle(
        fontFamily: kSfPro,
        fontFamilyFallback: kSfProFallback,
        fontSize: fs(10.5, theme.fontScale),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: theme.text.tertiary,
      ),
    );
    if (col.width != null) return SizedBox(width: col.width, child: text);
    return Expanded(flex: col.flex, child: text);
  }
}
