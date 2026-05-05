import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';
import '../../theme/typography.dart';

/// Uppercase tracked label used above detail sections (e.g. "WATERFALL",
/// "METADATA", "CHANGE HISTORY"). Ported from `SectionHeader`.
class SectionHeader extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry? margin;

  const SectionHeader(this.label, {super.key, this.margin});

  @override
  Widget build(BuildContext context) {
    final theme = OrcaThemeScope.of(context);
    return Container(
      margin: margin,
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.hairline, width: 1),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: kSfPro,
          fontFamilyFallback: kSfProFallback,
          fontSize: fs(10, theme.fontScale),
          fontWeight: FontWeight.w700,
          color: theme.text.tertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
