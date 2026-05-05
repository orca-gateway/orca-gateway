import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';
import 'orca_icon.dart';

/// 36px header bar with a search input and an optional right-aligned
/// count / hint text. Sits at the top of most list panes.
class ListFilterBar extends StatelessWidget {
  final String placeholder;
  final String? right;
  final ValueChanged<String>? onChanged;

  const ListFilterBar({
    super.key,
    required this.placeholder,
    this.right,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.surface.content,
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          OrcaIcon('search', size: 12, color: theme.text.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              cursorColor: theme.accent.base,
              style: TextStyle(
                fontFamily: kSfPro,
                fontFamilyFallback: kSfProFallback,
                fontSize: fs(12, theme.fontScale),
                color: theme.text.primary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: TextStyle(
                  fontFamily: kSfPro,
                  fontFamilyFallback: kSfProFallback,
                  fontSize: fs(12, theme.fontScale),
                  color: theme.text.tertiary,
                ),
              ),
            ),
          ),
          if (right != null) ...[
            const SizedBox(width: 8),
            Text(
              right!,
              style: TextStyle(
                fontFamily: kSfMono,
                fontFamilyFallback: kSfMonoFallback,
                fontSize: fs(10.5, theme.fontScale),
                color: theme.text.tertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
